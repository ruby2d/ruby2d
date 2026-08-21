# Ruby2D::Window

module Ruby2D
  # Whether Ruby drives the frame loop, which decides what `Window#show` does
  # after the window exists. On CRuby and Spinel, `Ext.window_show` creates the
  # window and returns, so `show` runs `tick until @close` itself. On mruby
  # native and on the web, `Ext.window_show` blocks and calls `tick` from C —
  # the web through emscripten's main-loop trampoline.
  #
  # Asked as a question rather than tested against an engine name at the call
  # site: a new target only has to answer it, and Spinel (where the binding
  # layer is compiled out entirely) answers it without a special case.
  def self.ruby_owned_loop?
    !web? && RUBY_ENGINE != 'mruby'
  end

  # The application window
  class Window
    # Event structures
    EventDescriptor       = Struct.new(:type, :id)
    ObjectEventDescriptor = Struct.new(:object, :type, :id)
    MouseEvent            = Struct.new(:type, :button, :direction, :x, :y, :delta_x, :delta_y) do
      def button?(name) = button == Mouse.validate!(name)
      def position      = [x, y]
      def delta         = [delta_x, delta_y]

      # Answer a filter for one matchable field. See `Window#matches?`.
      def matches?(field, value)
        field == :button && button?(value)
      end
    end
    KeyEvent              = Struct.new(:type, :key) do
      def key?(name) = key == Keyboard.validate!(name)

      # Answer a filter for one matchable field. See `Window#matches?`.
      def matches?(field, value)
        field == :key && key?(value)
      end
    end

    include KeyEvents
    include MouseEvents
    include GamepadEvents
    include ObjectEventDispatch
    extend ClassMethods

    attr_reader :title, :width, :height, :fps_cap, :fps, :frames, :delta_time,
                :background, :icon, :resizable,
                :highdpi, :pixel_scale,
                :viewport_width, :viewport_height, :viewport_mode,
                :render_mode, :scale_mode,
                :mouse_x, :mouse_y, :diagnostics, :show_fps, :close_on_esc

    # Accepted `fps_cap` values, shared by the strict constructor check and the
    # lenient runtime setter so the two messages can't drift apart.
    FPS_CAP_VALUES = 'nil, a positive number, :infinity, or Float::INFINITY'

    # Recognized `viewport:` modes. The native parser silently falls back to
    # letterbox for anything else, so validate here to surface typos rather than
    # let `viewport_mode` report a value the renderer never applied. Must match
    # R2D_ParseViewportMode in ext/ruby2d/window.c.
    VIEWPORT_MODES = %i[letterbox stretch integer overscan expand fixed].freeze

    # Create a window
    def initialize(title: 'Ruby 2D', width: 640, height: 480, fps_cap: nil)
      # Ruby 2D is single-window by design: per-object events and the top-level
      # DSL all route through one shared `DSL.window`. A second window would
      # silently steal that pointer and strand the first window's objects and
      # event handlers, so refuse to create one.
      if Ruby2D::DSL.window?
        raise Error,
              'A window already exists. Ruby 2D supports a single window per ' \
              'process (it may have been created automatically on first use of ' \
              'a Window class method or the top-level DSL).'
      end

      # Title of the window
      @title = title

      # Window size
      @width  = width
      @height = height

      # Frames per second upper limit, and the actual FPS. Valid: nil (no cap),
      # a positive number, or Float::INFINITY (uncapped). The constructor is
      # strict; the runtime setter (#set) warns and falls back instead.
      fps_cap = normalize_fps_cap(fps_cap)
      unless fps_cap_valid?(fps_cap)
        raise Error, "fps_cap must be #{FPS_CAP_VALUES}, got #{fps_cap.inspect}"
      end
      @fps_cap = fps_cap
      @fps = 0

      # Total number of frames that have been rendered
      @frames = 0

      # Whether the frame loop is running, i.e. between `show` and the window
      # closing. Frame-scoped work like `screenshot` needs an end-of-frame to
      # land on, so it consults this rather than doing nothing at all.
      @running = false

      # Renderable objects currently in the window, like a linear scene graph
      @objects = []
      @object_set = {}

      init_window_defaults
      init_event_stores
      init_event_registrations
      init_procs_and_dsl

      Ext.window_create(self)

      Ruby2D::DSL.window = self
    end

    # Track window shown state in a class instance variable
    @shown = false

    class << self
      # A method rather than an alias of an `attr_reader`: called implicitly
      # from `ClassMethods`, the alias answers stale state under Spinel (see
      # spinel/issues/52), and nothing reads the bare `shown`.
      def shown? = @shown

      attr_writer :shown
    end

    def display_width
      Ext.window_get_display_dimensions(self)
      @display_width
    end

    def display_height
      Ext.window_get_display_dimensions(self)
      @display_height
    end

    def display_pixel_width
      Ext.window_get_display_dimensions(self)
      @display_pixel_width
    end

    def display_pixel_height
      Ext.window_get_display_dimensions(self)
      @display_pixel_height
    end

    # Get a window attribute by name. `:window` returns the Window itself (the
    # DSL escape hatch to the full API); any other symbol reads that attribute.
    def get(sym)
      case sym
      when :window then self
      else public_send(sym)
      end
    end

    # Set window attributes
    def set(opts)
      # Store new window attributes, or ignore if nil
      set_any_window_properties opts
      set_any_window_dimensions opts

      Ext.window_set_size(self) if Window.shown? && (opts[:width] || opts[:height])

      if Window.shown? && (opts[:viewport] || opts[:viewport_width] || opts[:viewport_height] || !opts[:pixel_scale].nil?)
        Ext.window_set_viewport_mode(self)
      end

      if opts.key?(:fps_cap)
        cap = normalize_fps_cap(opts[:fps_cap])
        if fps_cap_valid?(cap)
          @fps_cap = cap
        else
          Ruby2D.warn "fps_cap must be #{FPS_CAP_VALUES}, got #{opts[:fps_cap].inspect}; ignoring (no cap)."
          @fps_cap = nil
        end
        Ext.window_set_fps_cap(self, @fps_cap) if Window.shown?
      end

      unless opts[:render_mode].nil?
        unless %i[continuous on_demand].include?(opts[:render_mode])
          raise Error, "`render_mode` must be :continuous or :on_demand, got #{opts[:render_mode].inspect}"
        end
        @render_mode = opts[:render_mode]
        Ext.window_set_render_mode(self) if Window.shown?
      end

      unless opts[:scale_mode].nil?
        @scale_mode = TextureScaling.validate(opts[:scale_mode])
        Ext.window_set_scale_mode(self) if Window.shown?
      end

      @close_on_esc = opts[:close_on_esc] unless opts[:close_on_esc].nil?

      self.cursor = opts[:cursor] unless opts[:cursor].nil?

      unless opts[:show_fps].nil?
        @show_fps = opts[:show_fps]
        Ext.window_show_fps(self, @show_fps)
      end

      unless opts[:diagnostics].nil?
        @diagnostics = opts[:diagnostics]
        Ext.window_diagnostics(self, @diagnostics)
      end
    end

    # Add an object to the window
    def add(object)
      case object
      when nil
        raise Error, "Cannot add `#{object.class}` to window!"
      when Array
        object.each { |x| add_object(x) }
      else
        add_object(object)
      end
    end

    # Remove an object from the window
    def remove(object)
      raise Error, "Cannot remove `#{object.class}` from window!" if object.nil?
      return false unless @objects.delete(object)

      @object_set.delete(object)
      unregister_interactive(object)
      true
    end

    # Clear all objects from the window
    def clear
      @objects.clear
      @object_set.clear
      init_object_event_stores
    end

    # Set the update callback
    def update(&proc)
      raise Error, '`update` requires a block' unless proc
      @update_proc = proc
      # Cache whether the block takes a delta-time arg; the arity never changes
      # after assignment, so the per-frame loop reads this instead of recomputing.
      @update_wants_dt = !proc.arity.zero?
      true
    end

    # Set the render callback. `z:` places the block in the scene's z-order:
    # `:foreground` (default) draws it on top of every object, `:background`
    # behind them, or a number interleaves it at that depth on the same scale
    # as object `z` (objects with `z` at or below it draw first, then the
    # block, then the rest).
    def render(z: :foreground, &proc)
      raise Error, '`render` requires a block' unless proc
      @render_proc = proc
      @render_z = render_z_for(z)
      true
    end

    # Monotonic seconds since engine start — a cross-platform, overflow-safe
    # clock for cooldowns, scheduling, and "time since" math. Unlike `Time.now`
    # it never jumps or jitters, and reads the same on CRuby and mruby/web.
    # For per-frame motion, prefer the `dt` argument to `update`.
    def elapsed
      Ext.now
    end

    # Maps event types to the matchable field used in the kwarg form of `on` —
    # e.g. `on key_down: :escape` filters via `event.matches?(:key, :escape)`.
    # For gamepad events the entries name the *primary* field (the one a bare
    # scalar matcher targets); hash matchers like
    # `{ gamepad: pad1, button: :south }` take the field from each key.
    #
    # Fields rather than predicate method names because every event answers
    # `matches?`, while `key?` / `button?` / `axis?` each exist on only some of
    # them — one shared entry point keeps the dispatch a plain method call
    # instead of a `send` with a name computed at runtime, which whole-program
    # AOT compilation cannot resolve. See spinel/README.md.
    EVENT_FILTER_FIELDS = {
      key_down: :key, key_held: :key, key_up: :key,
      mouse_down: :button, mouse_held: :button, mouse_up: :button,
      gamepad_button_down: :button, gamepad_button_held: :button,
      gamepad_button_up:   :button, gamepad_axis: :axis
    }.freeze

    # The name vocabulary a filter value for `type` is checked against, so
    # `on(key_down: 'space')` fails when the handler is registered rather than
    # at the first keypress. Nil for an event whose values are not names. A
    # method rather than a constant map so every answer is a `Vocabulary` and
    # the key set can be built on first use (see `Keyboard.keys`).
    def filter_vocabulary(type)
      case type
      when :key_down, :key_held, :key_up       then Keyboard.keys
      when :mouse_down, :mouse_held, :mouse_up then Mouse::BUTTONS
      when :gamepad_button_down, :gamepad_button_held, :gamepad_button_up
        Gamepad::BUTTONS
      when :gamepad_axis then Gamepad::AXES
      end
    end
    private :filter_vocabulary

    # Gamepad events dispatch an internal data struct, but user blocks
    # receive the unpacked args (gamepad / button / axis / value). This map
    # describes the unpack for each gamepad event type.
    GAMEPAD_EVENT_UNPACK = {
      gamepad_connect:     ->(d) { [d.gamepad] },
      gamepad_disconnect:  ->(d) { [d.gamepad] },
      gamepad_button_down: ->(d) { [d.gamepad, d.button] },
      gamepad_button_held: ->(d) { [d.gamepad, d.button] },
      gamepad_button_up:   ->(d) { [d.gamepad, d.button] },
      gamepad_axis:        ->(d) { [d.gamepad, d.axis, d.value] }
    }.freeze

    # Set an event handler. Forms:
    #
    #   on(:key_down) { |event| ... }                              # all events of type
    #   on(key_down: :escape) { ... }                              # filtered by value
    #   on(key_down: [:left, :a]) { ... }                          # array → match any
    #   on(key_down: :left, gamepad_button_down: :dpad_left) { }   # multi-event
    #   on(gamepad_button_down: { gamepad: pad1, button: :south }) # hash → AND match
    def on(event = nil, **filters, &proc)
      raise Error, '`on` requires a block' unless proc
      if event.is_a?(Symbol) && filters.empty?
        register_event_handler(event, wrap_for_event(event, proc))
      elsif event.nil? && !filters.empty?
        descriptors = filters.map do |type, matcher|
          register_event_handler(type, build_filter_wrapper(type, matcher, proc))
        end
        descriptors.size == 1 ? descriptors.first : descriptors
      else
        raise Error, '`on` requires either an event symbol or event filters'
      end
    end

    private def register_event_handler(event, proc)
      raise Error, "`#{event}` is not a valid event type" unless @events.key? event

      # Only one close handler is allowed; registering a new one replaces the old
      @events[:close].clear if event == :close

      event_id = new_event_key
      @events[event][event_id] = proc
      EventDescriptor.new(event, event_id)
    end

    # Wrap a user proc for direct (no-filter) registration. Gamepad events
    # unpack the dispatch struct into multi-arg form; everything else passes
    # the event struct straight through.
    private def wrap_for_event(type, proc)
      unpack = GAMEPAD_EVENT_UNPACK[type]
      return proc unless unpack

      ->(d) { proc.call(*unpack.call(d)) }
    end

    # Wrap a user proc with a filter matcher. Hash matchers AND every
    # `key?(value)` predicate; scalar/array matchers fall through to the
    # event type's primary predicate. Gamepad event handlers also unpack
    # the dispatch struct into multi-arg form.
    private def build_filter_wrapper(type, matcher, proc)
      unpack = GAMEPAD_EVENT_UNPACK[type]
      # Two lambdas are never the arms of one conditional here — neither
      # `a ? ->{} : ->{}` nor an `if`/`else` whose value is the lambda — because
      # Spinel types the chosen lambda's parameter as Integer in that shape (see
      # spinel/issues/49). Assigning in each arm, and returning early, read the
      # same and compile correctly.
      if unpack
        args = ->(e) { unpack.call(e) }
      else
        args = ->(e) { [e] }
      end

      if matcher.is_a?(Hash)
        unless unpack
          raise Error, "`#{type}` does not support hash filters with `on event: { ... }`"
        end
        # `gamepad:` matches an object, so only the name-valued keys are checked.
        matcher.each do |key, value|
          case key
          when :button then Gamepad::BUTTONS.validate!(value)
          when :axis   then Gamepad::AXES.validate!(value)
          end
        end
        return ->(e) {
          if matcher.all? { |k, v| e.matches?(k, v) }
            proc.call(*args.call(e))
          end
        }
      end

      field = EVENT_FILTER_FIELDS[type] or
        raise Error, "`#{type}` does not support filtering with `on event: value`"
      values = Array(matcher)
      if (vocabulary = filter_vocabulary(type))
        values.each { |v| vocabulary.validate!(v) }
      end
      ->(e) {
        if values.any? { |v| e.matches?(field, v) }
          proc.call(*args.call(e))
        end
      }
    end

    # Remove an event handler (or several). Accepts a descriptor returned by
    # `on`, or an array of them (as `on` returns when given multiple filters).
    def off(event_descriptor)
      return event_descriptor.each { |d| off(d) } if event_descriptor.is_a?(Array)

      case event_descriptor
      when ObjectEventDescriptor
        event_descriptor.object.off(event_descriptor)
      when EventDescriptor
        @events[event_descriptor.type].delete(event_descriptor.id)
      else
        raise Error,
              "Cannot remove event handler: expected a descriptor returned by `on`, got #{event_descriptor.inspect}"
      end
    end

    # Update callback method, called by the native and web extentions
    def update_callback
      # Monotonic seconds since the previous update. Clamped to 0.1s so a paused
      # window or stalled frame doesn't teleport the simulation when updates
      # resume; zero on the first frame. `Ext.now` (SDL_GetTicksNS, and
      # performance.now on web) is the single clock used on every runtime — the
      # same source as the public `elapsed`. A wall clock like Time.now would
      # jitter and stutter dt-scaled motion.
      now = Ext.now
      if @last_update_time
        dt = now - @last_update_time
        @delta_time = dt > 0.1 ? 0.1 : dt
      else
        @delta_time = 0.0
      end
      @last_update_time = now

      update if @overrides_update

      if @update_wants_dt
        @update_proc.call(@delta_time)
      else
        @update_proc.call
      end

      # Frame-scoped polling state (pressed/released, axes_moved, scroll/move
      # flags) lives one frame and is cleared here every tick — independent of
      # whether the user is on the DSL or class pattern, so both can poll.
      clear_event_stores
    end

    # Iterate the z-sorted scene graph and render each visible object, splicing
    # the user's render block into the same z-order at `@render_z`: objects with
    # `z` at or below it draw first, then the block, then the rest. The default
    # `:foreground` (+∞) draws the block last, on top of everything; `:background`
    # (-∞) draws it first. Called from the native extension once per frame via
    # `tick`. Each object draws via its zero-arg `_render_scene` hook, not the
    # public keyword `render`: on wasm mruby a zero-arg call into a
    # keyword-heavy method still pays ~5µs of keyword setup, so 100 sprites
    # would burn half a millisecond per frame on pure dispatch.
    def render_objects
      # Fast paths for the symbolic block positions: with the block pinned at
      # +∞ (`:foreground`, the default) or -∞ (`:background`) no object can
      # ever sort after (resp. before) it, so the per-object `z` read and
      # compare in the interleaving loop below could never fire — skip them.
      if @render_z == Float::INFINITY
        @objects.each { |obj| obj._render_scene if obj.visible? }
        render_callback
      elsif @render_z == -Float::INFINITY
        render_callback
        @objects.each { |obj| obj._render_scene if obj.visible? }
      else
        block_drawn = false
        @objects.each do |obj|
          if !block_drawn && obj.z > @render_z
            render_callback
            block_drawn = true
          end
          obj._render_scene if obj.visible?
        end
        render_callback unless block_drawn
      end
    end

    # Run the user's render block (and the overridden `render` method under the
    # class pattern). Spliced into the scene by `render_objects`.
    def render_callback
      render if @overrides_render

      @render_proc.call
    end

    # Close callback method, called by the native extension
    def close_callback
      @events[:close].each_value(&:call)
    end

    # One frame: poll events, update, render.
    def tick
      Ext.poll_events(self)
      # drain_events returns nil (not an empty array) on event-less frames
      raw = Ext.drain_events(self)
      dispatch_events(raw) if raw

      update_callback

      if Ext.begin_frame(self)
        render_objects
      end

      Ext.end_frame(self)
    end

    # Show the window
    def show
      raise Error, 'Window#show called multiple times; Ruby 2D supports a single window per process' if Window.shown?

      @close = false
      load_default_gamepad_mappings

      if Ruby2D.ruby_owned_loop?
        # CRuby and Spinel: window_show creates the window and returns.
        # Mark shown only after it succeeds; on failure it raises, so shown? stays
        # false and no frame dereferences a NULL renderer.
        Ext.window_show(self)
        Window.shown = true
        @running = true
        tick until @close
      else
        # mruby/WASM: window_show creates the window AND runs the loop, blocking
        # until close. Mark shown first so live updates (request_render, set title,
        # etc.) work during the run; a creation failure raises before the loop.
        Window.shown = true
        @running = true
        Ext.window_show(self)
      end

      @running = false
    end

    # Take a screenshot, saving to `path` (or a timestamped file if omitted).
    #
    # The write is deferred to the end of the current frame, after the scene is
    # drawn but before it is presented, so the capture is this frame rather than
    # the last one. `path` therefore comes back before the file exists; it lands
    # by the time the next `update` runs. Requesting one also forces the frame to
    # render, so a capture in `:on_demand` mode never grabs a parked frame, and
    # capturing and closing in the same tick still writes the file.
    #
    # A closed window has no end-of-frame left to write on, so that raises rather
    # than returning a path to a file that will never appear.
    #
    # A no-op on the web, returning nil: the only filesystem there is Emscripten's
    # in-memory one, so a capture would cost a framebuffer read and a PNG encode
    # to produce a file nobody can open, and that vanishes on reload.
    def screenshot(path = nil)
      return if Ruby2D.web?

      if Window.shown? && !@running
        raise Error, '`screenshot` called after the window closed; the file is ' \
                     'written at the end of a frame, so nothing would be saved'
      end

      path ||= "./screenshot-#{Time.now.utc.strftime('%Y-%m-%d--%H-%M-%S')}.png"
      Ext.window_screenshot(self, path)
    end

    # Get the current cursor state
    def cursor
      return :hidden unless Ext.window_cursor_visible(self)

      @cursor_style || :default
    end

    # Set the cursor: `:visible`, `:hidden`, or a system cursor name
    def cursor=(name)
      case name
      when :visible
        @cursor_style = :default
        Ext.window_show_cursor(self)
      when :hidden
        @cursor_style = nil
        Ext.window_hide_cursor(self)
      else
        name = name.to_sym
        @cursor_style = name
        Ext.window_set_system_cursor(self, name.to_s)
      end
    end

    # Close the window. A no-op on the web, where a page can't close itself —
    # only the person viewing it can — so there's nothing to shut down: the
    # `:close` handler doesn't fire, the window isn't marked closed, and the
    # loop keeps running. The user's own quit still arrives as a `:close`
    # event, which is handled in the event loop rather than here.
    def close
      return if Ruby2D.web?

      close_callback
      Ext.window_close(self)
      @close = true
    end

    # Request that the next tick render a frame. No-op in :continuous mode.
    # Safe to call from any thread.
    def request_render
      Ext.window_request_render(self) if Window.shown?
    end

    # Private instance methods

    private

    # Resolve a render-block `z:` to a numeric depth. `:foreground` puts the
    # block on top of every object, `:background` behind them; a number places
    # it at that depth on the same scale as object `z`.
    def render_z_for(z)
      case z
      when :foreground then Float::INFINITY
      when :background then -Float::INFINITY
      when Numeric then z
      else
        raise Error, "render `z:` must be a number, :foreground, or :background, got #{z.inspect}"
      end
    end

    # Event buffer stride and category/type constants (match C-side defines)
    EVT_STRIDE  = 12
    EVT_KEY     = 1
    EVT_MOUSE   = 2
    EVT_GAMEPAD = 3
    EVT_CLOSE   = 4

    KEY_TYPE_MAP   = { 1 => :down, 2 => :held, 3 => :up }.freeze
    MOUSE_TYPE_MAP = { 1 => :down, 2 => :up, 3 => :scroll, 4 => :move,
                       5 => :held, 6 => :enter, 7 => :leave }.freeze
    MOUSE_BTN_MAP  = { 1 => :left, 2 => :middle, 3 => :right, 4 => :x1, 5 => :x2 }.freeze
    SCROLL_DIR_MAP = { 0 => :normal, 1 => :inverted }.freeze
    GP_AXIS_MAP    = { 0 => :left_x, 1 => :left_y, 2 => :right_x, 3 => :right_y,
                       4 => :left_trigger, 5 => :right_trigger }.freeze
    GP_BUTTON_MAP  = { 0 => :south, 1 => :east, 2 => :west, 3 => :north,
                       4 => :back, 5 => :guide, 6 => :start,
                       7 => :left_stick, 8 => :right_stick,
                       9 => :left_shoulder, 10 => :right_shoulder,
                       11 => :dpad_up, 12 => :dpad_down,
                       13 => :dpad_left, 14 => :dpad_right,
                       15 => :misc1, 16 => :paddle1, 17 => :paddle2,
                       18 => :paddle3, 19 => :paddle4, 20 => :touchpad,
                       21 => :misc2, 22 => :misc3, 23 => :misc4,
                       24 => :misc5, 25 => :misc6 }.freeze

    def dispatch_events(raw)
      i = 0
      while i < raw.size
        cat = raw[i]
        case cat
        when EVT_KEY
          # Key events carry their name symbol, not a code — see `R2D_KeyName`.
          key_callback(KEY_TYPE_MAP[raw[i + 1]], raw[i + 2])
        when EVT_MOUSE
          mouse_callback(
            MOUSE_TYPE_MAP[raw[i + 1]], MOUSE_BTN_MAP[raw[i + 3]],
            SCROLL_DIR_MAP[raw[i + 4]],
            raw[i + 6], raw[i + 7], raw[i + 8], raw[i + 9]
          )
        when EVT_GAMEPAD
          gp_type = raw[i + 1]
          gp_id   = raw[i + 2]
          case gp_type
          when 1 then gamepad_callback(gp_id, :connect, nil, nil, raw[i + 11])
          when 2 then gamepad_callback(gp_id, :disconnect, nil, nil, nil)
          when 3
            axis_sym = GP_AXIS_MAP[raw[i + 5]]
            raw_val  = raw[i + 10]
            value    = raw_val > 0 ? raw_val / 32767.0 : raw_val / 32768.0
            gamepad_callback(gp_id, :axis, axis_sym, value, nil)
          when 4 then gamepad_callback(gp_id, :button_down, GP_BUTTON_MAP[raw[i + 3]], nil, nil)
          when 5 then gamepad_callback(gp_id, :button_up, GP_BUTTON_MAP[raw[i + 3]], nil, nil)
          when 6 then gamepad_callback(gp_id, :button_held, GP_BUTTON_MAP[raw[i + 3]], nil, nil)
          end
        when EVT_CLOSE
          close_callback
          Ext.window_close(self)
          @close = true
        end
        i += EVT_STRIDE
      end
    end

    # Fire every handler registered for `type`, building a fresh event object
    # per handler via the block (a handler may mutate the event it receives, so
    # handlers don't share one). Skips the values-array allocation when no
    # handlers are registered — the common case on per-event hot paths, where
    # it costs ~1µs per empty event type on wasm mruby.
    def fire_event_handlers(type)
      handlers = @events[type]
      return if handlers.empty?

      handlers.values.each { |e| e.call(yield) }
    end

    # Generate a new event key (ID)
    def new_event_key
      @event_key += 1
    end

    # Add an object to the window, used by the public `add` method
    def add_object(object)
      return false if @object_set.key?(object)

      index = @objects.bsearch_index { |obj| obj.z > object.z }
      @objects.insert(index || @objects.size, object)
      @object_set[object] = true

      # Re-register for correct z-order if the object is interactive
      if object.respond_to?(:interactive?) && object.interactive?
        @interactive_objects.delete(object)
        register_interactive(object)
      end

      true
    end

    def set_any_window_properties(opts)
      @background = Color.new(opts[:background]) if Color.valid? opts[:background]
      if opts[:title]
        @title = opts[:title]
        Ext.window_set_title(self) if Window.shown?
      end
      if opts[:icon]
        @icon = opts[:icon]
        Ext.window_set_icon(self) if Window.shown?
      end
      unless opts[:resizable].nil?
        @resizable = opts[:resizable]
        Ext.window_set_resizable(self) if Window.shown?
      end
    end

    def set_any_window_dimensions(opts)
      # Before `show`, the viewport auto-follows width/height (its documented
      # default of "same as width/height"). After `show`, a bare `set width:` is
      # a live resize: leave the fixed logical viewport alone so it letterboxes
      # into the new window size instead of being silently overwritten. Only
      # `:expand` tracks the window on resize, and that is handled C-side.
      if opts[:width]
        @width = opts[:width]
        @viewport_width = @width unless opts[:viewport_width] || Window.shown?
      end
      if opts[:height]
        @height = opts[:height]
        @viewport_height = @height unless opts[:viewport_height] || Window.shown?
      end
      @viewport_width  = opts[:viewport_width]  if opts[:viewport_width]
      @viewport_height = opts[:viewport_height] if opts[:viewport_height]
      if opts[:viewport]
        unless VIEWPORT_MODES.include?(opts[:viewport])
          raise Error, "Invalid viewport mode #{opts[:viewport].inspect}; expected one of #{VIEWPORT_MODES.inspect}"
        end
        @viewport_mode = opts[:viewport]
      end
      # highdpi is baked into the native window at creation and re-read once at
      # `show`; it cannot change afterward. Keep the reader honest — never mutate
      # @highdpi post-show — and warn only when the call would actually differ.
      unless opts[:highdpi].nil?
        if Window.shown?
          if opts[:highdpi] != @highdpi
            Ruby2D.warn 'highdpi is fixed when the window is created and cannot change after `show`; ignoring.'
          end
        else
          @highdpi = opts[:highdpi]
        end
      end
      @pixel_scale     = opts[:pixel_scale] unless opts[:pixel_scale].nil?
    end

    # The symbol :infinity is an ergonomic alias for Float::INFINITY (uncapped);
    # normalize it so the rest of the pipeline only sees nil / number / INFINITY.
    def normalize_fps_cap(value)
      value == :infinity ? Float::INFINITY : value
    end

    # A valid (normalized) fps_cap is nil (no cap) or a positive number —
    # including Float::INFINITY, which is positive. 0, negatives, NaN, and other
    # types are rejected.
    def fps_cap_valid?(value)
      value.nil? || (value.is_a?(Numeric) && value > 0)
    end

    def clear_event_stores
      @keys_down.clear
      @keys_held.clear
      @keys_up.clear
      @mouse_buttons_down.clear
      @mouse_buttons_up.clear
      @mouse_buttons_held.clear
      @mouse_scroll_event     = false
      @mouse_scroll_direction = nil
      @mouse_scroll_delta_x   = 0
      @mouse_scroll_delta_y   = 0
      @mouse_move_event   = false
      @mouse_move_delta_x = 0
      @mouse_move_delta_y = 0
      clear_gamepad_frame_state
    end

    def init_window_defaults
      # Window background color
      @background = Color.new([0.0, 0.0, 0.0, 1.0])

      # Window icon
      @icon = nil

      # Window characteristics
      @resizable = false
      @highdpi = true
      @pixel_scale = false

      # Size of the window's viewport (the drawable area)
      @viewport_width = @width
      @viewport_height = @height

      # Viewport scaling mode for resizable windows
      @viewport_mode = :letterbox

      # Render mode: :continuous renders every tick up to fps_cap; :on_demand
      # only renders when request_render is called or the OS signals a redraw.
      @render_mode = :continuous

      # Default texture sampling for objects that don't set their own.
      @scale_mode = :linear

      # Size of the computer's display
      @display_width = nil
      @display_height = nil
      @display_pixel_width = nil
      @display_pixel_height = nil
    end

    def init_event_stores
      init_key_event_stores
      init_mouse_event_stores
      init_gamepad_event_stores
      init_object_event_stores
    end

    def init_event_registrations
      # Mouse X and Y position in the window
      @mouse_x = 0
      @mouse_y = 0

      # Unique ID for the input event being registered
      @event_key = 0

      # Registered input events
      @events = {
        key: {},
        key_down: {},
        key_held: {},
        key_up: {},
        mouse: {},
        mouse_up: {},
        mouse_down: {},
        mouse_held: {},
        mouse_scroll: {},
        mouse_move: {},
        mouse_enter: {},
        mouse_leave: {},
        gamepad_connect: {},
        gamepad_disconnect: {},
        gamepad_button_down: {},
        gamepad_button_held: {},
        gamepad_button_up: {},
        gamepad_axis: {},
        close: {}
      }
    end

    def init_procs_and_dsl
      # The window update block
      @update_proc = proc {}
      @update_wants_dt = false

      # The window render block, and where it sits in the z-order (see `render`)
      @render_proc = proc {}
      @render_z = Float::INFINITY

      # Per-frame delta-time state, populated each `update_callback`.
      @last_update_time = nil
      @delta_time = 0.0

      # Detect the "class pattern": a Window subclass overriding `update` and/or
      # `render`. Each is detected independently so overriding only one still
      # works — an overridden `update` runs even when `render` is left alone, and
      # vice versa. The base `update`/`render` are the DSL setters defined on
      # Ruby2D::Window, so an un-overridden method finds that owner and is
      # skipped in the frame loop (its DSL proc still runs).
      @overrides_update = overrides?(:update)
      @overrides_render = overrides?(:render)

      # Whether diagnostic messages should be printed
      @diagnostics = false
      @show_fps = false
      @close_on_esc = false
    end

    # Whether `name` (`:update` or `:render`) is a class-pattern override rather
    # than Ruby 2D's own DSL setter.
    #
    # This asks which *class* in the ancestry defines the method, skipping any
    # module Window itself drags along. A module prepended to Window fronts the
    # setter the same way a subclass override does, so reading the immediate
    # owner would mistake instrumentation — wrapping `update` to count frames or
    # hook a screenshot into someone else's app — for the class pattern, and
    # call the setter with no block every frame, which raises. A module mixed
    # into a subclass still counts: that side of the chain is the user's own
    # code, so an `update` there is an override like any other.
    def overrides?(name)
      wrappers = Window.ancestors - [Window]
      owner = self.class.ancestors.find do |mod|
        !wrappers.include?(mod) && mod.instance_methods(false).include?(name)
      end
      owner != Window
    end
  end
end
