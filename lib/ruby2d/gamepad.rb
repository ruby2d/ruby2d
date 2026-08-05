# Ruby2D::Gamepad

module Ruby2D
  # A connected gamepad. Lives from connect to disconnect; reconnects produce
  # a new object. Identity-based equality (default Ruby behavior) makes
  # `Gamepad` instances stable hash keys for per-pad state.
  #
  # Disconnected pads remain safe to poll: `held?` etc. return `false`,
  # `axis` returns `0.0`, and feedback methods return `false` silently.
  class Gamepad
    # SDL3 enum values for symbol → integer translation. These mirror the
    # `R2D_BUTTON_*` and `R2D_AXIS_*` constants in `ruby2d.h`. The C side
    # already speaks symbols for events; these are only needed for capability
    # queries that go from Ruby through to SDL.
    BUTTON_ENUM = {
      south:           0,
      east:            1,
      west:            2,
      north:           3,
      back:            4,
      guide:           5,
      start:           6,
      left_stick:      7,
      right_stick:     8,
      left_shoulder:   9,
      right_shoulder:  10,
      dpad_up:         11,
      dpad_down:       12,
      dpad_left:       13,
      dpad_right:      14,
      misc1:           15,
      paddle1:         16,
      paddle2:         17,
      paddle3:         18,
      paddle4:         19,
      touchpad:        20,
      misc2:           21,
      misc3:           22,
      misc4:           23,
      misc5:           24,
      misc6:           25
    }.freeze

    AXIS_ENUM = {
      left_x:        0,
      left_y:        1,
      right_x:       2,
      right_y:       3,
      left_trigger:  4,
      right_trigger: 5
    }.freeze

    # Sticks only — triggers (0.0..1.0) are exempt because they rest at zero
    # and rarely drift. 0.05 should cover typical worst-case stick drift.
    DEFAULT_DEAD_ZONE = 0.05

    TRIGGER_AXES = %i[left_trigger right_trigger].freeze

    # Ordered list of axis names. `axes` always returns the full hash so the
    # shape is stable.
    AXIS_NAMES = AXIS_ENUM.keys.freeze

    attr_reader :id, :name, :type
    attr_accessor :dead_zone

    def initialize(window, id, name)
      @window = window
      @id = id
      @name = name || ''
      @connected = true
      @dead_zone = DEFAULT_DEAD_ZONE

      # Cached per-connection metadata. `type` and capabilities don't change
      # while the pad is connected, so we read them once and avoid the SDL
      # round-trip on every call.
      @type = Ext.window_gamepad_type(window, id)
      caps = Ext.window_gamepad_caps(window, id)
      @cap_rumble          = caps & 0x1 != 0
      @cap_rumble_triggers = caps & 0x2 != 0
      @cap_led             = caps & 0x4 != 0

      # Per-button and per-axis presence is also cached at connect — one SDL
      # call per known enum, then `has?(:button, name)` / `has?(:axis, name)`
      # are pure hash reads. Cheap (~27 calls total) and matches the
      # "capability checks are cached at connect time" rule in USAGE.md.
      @btn_present  = BUTTON_ENUM.each_with_object({}) do |(sym, enum), h|
        h[sym] = Ext.window_gamepad_has_button(window, id, enum)
      end
      @axis_present = AXIS_ENUM.each_with_object({}) do |(sym, enum), h|
        h[sym] = Ext.window_gamepad_has_axis(window, id, enum)
      end

      # Frame-scoped event sets. Pressed/released/axes_moved are cleared by
      # `_clear_frame_state`; held is also cleared and refilled each frame
      # from the C-side held loop.
      @buttons_down  = []
      @buttons_up    = []
      @buttons_held  = []
      @axes_moved    = []

      # Sticky axis values populated by motion events.
      @axis_values = {}
      AXIS_NAMES.each { |a| @axis_values[a] = 0.0 }
      @raw_axis_values = @axis_values.dup
    end

    def connected? = @connected

    # Capability check. Forms:
    #   pad.has?(:rumble)
    #   pad.has?(:rumble_triggers)
    #   pad.has?(:led)
    #   pad.has?(:button, :paddle1)
    #   pad.has?(:axis, :left_trigger)
    def has?(capability, name = nil)
      return false unless @connected

      case capability
      when :rumble           then @cap_rumble
      when :rumble_triggers  then @cap_rumble_triggers
      when :led              then @cap_led
      when :button           then @btn_present[name]  || false
      when :axis             then @axis_present[name] || false
      else                        false
      end
    end

    # Battery — live query, since charge level changes during play. Returns
    # one of `:wired`, `:full`, `:medium`, `:low`, `:empty`, or `nil` when
    # SDL can't determine the state.
    def battery
      return nil unless @connected

      state, percent = Ext.window_gamepad_battery(@window, @id)
      case state
      when :wired then :wired
      when :on_battery
        case percent
        when -1 then :medium  # plugged into a battery slot but no level reported
        when 0..9 then :empty
        when 10..29 then :low
        when 30..74 then :medium
        else :full
        end
      end
    end

    # Polling — currently held / current axis position.
    def held?(button) = @buttons_held.include?(button)

    def axis(name, raw: false)
      return 0.0 unless AXIS_ENUM.key?(name)

      v = (raw ? @raw_axis_values : @axis_values)[name]
      v || 0.0
    end

    def buttons_held = @buttons_held.dup

    def axes
      AXIS_NAMES.each_with_object({}) { |a, h| h[a] = @axis_values[a] || 0.0 }
    end

    # Polling — frame-scoped transitions. Cleared each frame by
    # `_clear_frame_state`.
    def pressed?(button)  = @buttons_down.include?(button)
    def released?(button) = @buttons_up.include?(button)
    def axis_moved?(axis) = @axes_moved.include?(axis)
    def axes_moved        = @axes_moved.dup

    # Feedback. `rumble`, `rumble_triggers`, and `set_led` return `false` when
    # the pad is disconnected or the SDL call fails — never raise. `led=` is a
    # convenience alias of `set_led`; being a Ruby assignment it evaluates to the
    # assigned value, not the success Boolean, so use `set_led` when you need it.
    #
    # `rumble(strength:, duration:)` is the simple form; the low/high form
    # exposes the dual-motor pattern most pads expose.
    def rumble(strength: nil, low: nil, high: nil, duration: 0.2)
      return false unless @connected

      if strength
        low ||= strength
        high ||= strength
      end
      low  ||= 0.0
      high ||= 0.0
      Ext.window_gamepad_rumble(@window, @id, low.to_f, high.to_f, duration.to_f)
    end

    def rumble_triggers(left: 0.0, right: 0.0, duration: 0.2)
      return false unless @connected

      Ext.window_gamepad_rumble_triggers(@window, @id,
                   left.to_f, right.to_f, duration.to_f)
    end

    # Set the LED color from an `[r, g, b]` triple. Returns `false` on failure.
    def set_led(rgb)
      return false unless @connected
      r, g, b = rgb
      Ext.window_gamepad_set_led(@window, @id, r.to_i, g.to_i, b.to_i)
    end

    # Convenience setter form of `set_led`. As a Ruby assignment it returns the
    # assigned value, not the success Boolean — call `set_led` if you need that.
    def led=(rgb)
      set_led(rgb)
    end

    # Snapshot of the underlying joystick's raw input state — buttons,
    # axes (raw -32768..32767), and hats (SDL hat bitmask). Bypasses any
    # gamepad mapping. Intended for mapping-generation tools that need to
    # observe the physical hardware before SDL remaps it. Returns `nil`
    # when the pad is disconnected.
    def joystick_state
      return nil unless @connected

      arr = Ext.window_gamepad_joystick_state(@window, @id) or return nil
      { buttons: arr[0], axes: arr[1], hats: arr[2] }
    end

    # Read-only snapshot of low-level metadata SDL exposes about the pad —
    # useful when adding a custom mapping for an unrecognized device, or
    # diagnosing why a connected device behaves oddly. Returns `nil` when
    # the pad is disconnected.
    #
    # Keys:
    #   :guid           — 32-char SDL GUID hex string (the same string used
    #                     in `gamepads.txt` mapping entries)
    #   :vendor_id      — USB-style vendor ID (Integer; format as `%04x`)
    #   :product_id     — USB-style product ID (Integer; format as `%04x`)
    #   :version        — product version (Integer; format as `%04x`)
    #   :serial         — String, or nil if SDL has no serial for this pad
    #   :connection     — :wired, :wireless, or :unknown
    #   :real_type      — the underlying gamepad type before any user mapping
    #                     remaps it (:xbox / :playstation / :nintendo /
    #                     :generic / :unknown)
    #   :num_touchpads  — count of touchpad surfaces (PS4/PS5 = 1, most = 0)
    #   :mapping        — the resolved SDL gamepad mapping string, or nil
    def debug_info
      return nil unless @connected

      arr = Ext.window_gamepad_debug_info(@window, @id) or return nil
      {
        guid:          arr[0],
        vendor_id:     arr[1],
        product_id:    arr[2],
        version:       arr[3],
        serial:        arr[4],
        connection:    arr[5],
        real_type:     arr[6],
        num_touchpads: arr[7],
        mapping:       arr[8]
      }
    end

    # ----- Internal: dispatch hooks called from gamepad_callback -----

    def _apply_button_down(button)
      return unless @connected
      @buttons_down << button unless @buttons_down.include?(button)
      @buttons_held << button unless @buttons_held.include?(button)
    end

    def _apply_button_held(button)
      return unless @connected
      @buttons_held << button unless @buttons_held.include?(button)
    end

    def _apply_button_up(button)
      return unless @connected
      @buttons_up << button unless @buttons_up.include?(button)
      @buttons_held.delete(button)
    end

    # Returns the dead-zoned value (which is what handlers receive), or `nil`
    # if the value didn't move outside the dead-zoned region — letting the
    # caller suppress event emission for motion entirely inside the dead zone.
    def _apply_axis(axis, raw_value)
      return nil unless @connected
      return nil unless AXIS_ENUM.key?(axis)

      previous = @axis_values[axis] || 0.0
      dz = apply_dead_zone(axis, raw_value)

      @raw_axis_values[axis] = raw_value
      @axis_values[axis] = dz

      if dz != previous
        @axes_moved << axis unless @axes_moved.include?(axis)
        dz
      else
        nil
      end
    end

    def _clear_frame_state
      @buttons_down.clear
      @buttons_up.clear
      @buttons_held.clear
      @axes_moved.clear
    end

    def _disconnect
      @connected = false
      @buttons_down.clear
      @buttons_up.clear
      @buttons_held.clear
      @axes_moved.clear
      AXIS_NAMES.each do |a|
        @axis_values[a] = 0.0
        @raw_axis_values[a] = 0.0
      end
    end

    private

    def apply_dead_zone(axis, value)
      return value if @dead_zone <= 0.0 || TRIGGER_AXES.include?(axis)
      value.abs < @dead_zone ? 0.0 : value
    end
  end
end
