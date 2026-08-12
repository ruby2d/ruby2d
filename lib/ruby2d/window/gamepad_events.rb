# Ruby2D::Window::GamepadEvents

module Ruby2D
  class Window
    # Multi-gamepad input handling. Owns the `gamepads` collection and the
    # callback the C extension calls for every SDL gamepad event. Holds no
    # ambient single-pad state — every event carries the `Gamepad` it came
    # from, and polling lives on each `Gamepad` instance.
    module GamepadEvents
      # Default location for the user's gamepad mappings file. Loaded
      # automatically from `show` if it exists.
      DEFAULT_GAMEPAD_MAPPINGS_PATH = "#{File.expand_path('~')}/.ruby2d/gamepads.txt".freeze

      # Internal dispatch structs for filter matching. Never exposed to user
      # code — handlers receive unpacked args (gamepad / button / axis / value),
      # not the struct.
      GamepadConnectData = Struct.new(:gamepad) do
        def gamepad?(other) = gamepad.equal?(other)

        # Answer a filter for one matchable field. See `Window#matches?`.
        def matches?(field, value)
          field == :gamepad && gamepad?(value)
        end
      end

      GamepadButtonData = Struct.new(:gamepad, :button) do
        def gamepad?(other) = gamepad.equal?(other)
        def button?(name)   = button == Gamepad::BUTTONS.validate!(name)

        # Answer a filter for one matchable field. See `Window#matches?`.
        def matches?(field, value)
          case field
          when :gamepad then gamepad?(value)
          when :button  then button?(value)
          else false
          end
        end
      end

      GamepadAxisData = Struct.new(:gamepad, :axis, :value) do
        def gamepad?(other) = gamepad.equal?(other)
        def axis?(name)     = axis == Gamepad::AXES.validate!(name)

        # Answer a filter for one matchable field. See `Window#matches?`.
        def matches?(field, value)
          case field
          when :gamepad then gamepad?(value)
          when :axis    then axis?(value)
          else false
          end
        end
      end

      # Connected gamepads in connect order. Stable: index 0 is the
      # first-connected pad still present.
      def gamepads
        @gamepads
      end

      # Load gamepad mappings from a file or string. Smart-parses the
      # argument: if it points at an existing file, loads it via
      # `SDL_AddGamepadMappingsFromFile`; otherwise treats it as a single
      # mapping string and forwards to `SDL_AddGamepadMapping`.
      def add_gamepad_mapping(path_or_string)
        if File.file?(path_or_string)
          Ext.window_load_gamepad_mappings_file(self, path_or_string)
        else
          Ext.window_add_gamepad_mapping(self, path_or_string)
        end
      end

      # Auto-load mappings from the default user file. Called from `show`.
      def load_default_gamepad_mappings
        return unless File.exist?(DEFAULT_GAMEPAD_MAPPINGS_PATH)

        Ext.window_load_gamepad_mappings_file(self, DEFAULT_GAMEPAD_MAPPINGS_PATH)
      end

      # Called from C for every gamepad event. Type is one of:
      # :connect, :disconnect, :button_down, :button_held, :button_up, :axis.
      # `data` is the button name (button events), axis name (axis events),
      # or nil (connect/disconnect). `value` is the dead-zone-applied axis
      # value, or nil. `name` is the gamepad's display name on connect/
      # disconnect, otherwise nil.
      def gamepad_callback(which, type, data, value, name = nil)
        case type
        when :connect
          handle_gamepad_connect(which, name)
        when :disconnect
          handle_gamepad_disconnect(which)
        when :button_down
          handle_gamepad_button_down(which, data)
        when :button_held
          handle_gamepad_button_held(which, data)
        when :button_up
          handle_gamepad_button_up(which, data)
        when :axis
          handle_gamepad_axis(which, data, value)
        end
      end

      def init_gamepad_event_stores
        @gamepads = []
        @gamepads_by_id = {}
      end

      def clear_gamepad_frame_state
        @gamepads.each(&:_clear_frame_state)
      end

      private

      def handle_gamepad_connect(id, name)
        return if @gamepads_by_id.key?(id)

        pad = Gamepad.new(self, id, name)
        @gamepads << pad
        @gamepads_by_id[id] = pad

        fire_event_handlers(:gamepad_connect) { GamepadConnectData.new(pad) }
      end

      def handle_gamepad_disconnect(id)
        pad = @gamepads_by_id.delete(id)
        return unless pad

        @gamepads.delete(pad)
        pad._disconnect

        fire_event_handlers(:gamepad_disconnect) { GamepadConnectData.new(pad) }
      end

      def handle_gamepad_button_down(id, button)
        pad = @gamepads_by_id[id] or return
        pad._apply_button_down(button)
        fire_event_handlers(:gamepad_button_down) { GamepadButtonData.new(pad, button) }
      end

      def handle_gamepad_button_held(id, button)
        pad = @gamepads_by_id[id] or return
        pad._apply_button_held(button)
        fire_event_handlers(:gamepad_button_held) { GamepadButtonData.new(pad, button) }
      end

      def handle_gamepad_button_up(id, button)
        pad = @gamepads_by_id[id] or return
        pad._apply_button_up(button)
        fire_event_handlers(:gamepad_button_up) { GamepadButtonData.new(pad, button) }
      end

      # Suppress the event when the dead-zoned value didn't change since the
      # last event for that axis — avoids spamming handlers with motion
      # entirely inside the dead zone. `_apply_axis` returns the new value
      # when it changed, or nil otherwise.
      def handle_gamepad_axis(id, axis, raw_value)
        pad = @gamepads_by_id[id] or return
        new_value = pad._apply_axis(axis, raw_value)
        return if new_value.nil?

        fire_event_handlers(:gamepad_axis) { GamepadAxisData.new(pad, axis, new_value) }
      end
    end
  end
end
