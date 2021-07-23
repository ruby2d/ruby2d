# Ruby2D::Window
# Represents a window on screen, responsible for storing renderable graphics,
# event handlers, the update loop, showing and closing the window.

module Ruby2D
  class Window

    # Event structures
    EventDescriptor       = Struct.new(:type, :id)
    MouseEvent            = Struct.new(:type, :button, :direction, :x, :y, :delta_x, :delta_y)
    KeyEvent              = Struct.new(:type, :key)
    ControllerEvent       = Struct.new(:which, :type, :axis, :value, :button)
    ControllerAxisEvent   = Struct.new(:which, :axis, :value)
    ControllerButtonEvent = Struct.new(:which, :button)

    def initialize(args = {})

      # Title of the window
      @title = args[:title] || "Ruby 2D"

      # Window background color
      @background = Color.new([0.0, 0.0, 0.0, 1.0])

      # Window icon
      @icon = nil

      # Window size and characteristics
      @width  = args[:width]  || 640
      @height = args[:height] || 480
      @resizable = false
      @borderless = false
      @fullscreen = false
      @highdpi = false

      # Size of the window's viewport (the drawable area)
      @viewport_width, @viewport_height = nil, nil

      # Size of the computer's display
      @display_width, @display_height = nil, nil

      # Total number of frames that have been rendered
      @frames = 0

      # Frames per second upper limit, and the actual FPS
      @fps_cap = args[:fps_cap] || 60
      @fps = @fps_cap

      # Vertical synchronization, set to prevent screen tearing (recommended)
      @vsync = args[:vsync] || true

      # Renderable objects currently in the window, like a linear scene graph
      @objects = []

      # Entities currently in the window
      @entities = []

      # Mouse X and Y position in the window
      @mouse_x, @mouse_y = 0, 0

      # Controller axis and button mappings file
      @controller_mappings = File.expand_path('~') + "/.ruby2d/controllers.txt"

      # Event stores for class pattern
      @keys_down = []
      @keys_held = []
      @keys_up   = []
      @mouse_buttons_down = []
      @mouse_buttons_up   = []
      @mouse_scroll_event     = false
      @mouse_scroll_direction = nil
      @mouse_scroll_delta_x   = 0
      @mouse_scroll_delta_y   = 0
      @mouse_move_event   = false
      @mouse_move_delta_x = 0
      @mouse_move_delta_y = 0
      @controller_id = nil
      @controller_axes_moved   = []
      @controller_axis_left_x  = 0
      @controller_axis_left_y  = 0
      @controller_axis_right_x = 0
      @controller_axis_right_y = 0
      @controller_buttons_down = []
      @controller_buttons_up   = []

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
        mouse_scroll: {},
        mouse_move: {},
        controller: {},
        controller_axis: {},
        controller_button_down: {},
        controller_button_up: {}
      }

      # The window update block
      @update_proc = Proc.new {}

      # The window render block
      @render_proc = Proc.new {}

      # Detect if window is being used through the DSL or as a class instance
      unless method(:update).parameters.empty? || method(:render).parameters.empty?
        @using_dsl = true
      end

      # Whether diagnostic messages should be printed
      @diagnostics = false

      # Console mode, enabled at command line
      if RUBY_ENGINE == 'ruby'
        @console = defined?($ruby2d_console_mode) ? true : false
      else
        @console = false
      end
    end

    # Class methods for convenient access to properties
    class << self
      def current;         get(:window)          end
      def title;           get(:title)           end
      def background;      get(:background)      end
      def width;           get(:width)           end
      def height;          get(:height)          end
      def viewport_width;  get(:viewport_width)  end
      def viewport_height; get(:viewport_height) end
      def display_width;   get(:display_width)   end
      def display_height;  get(:display_height)  end
      def resizable;       get(:resizable)       end
      def borderless;      get(:borderless)      end
      def fullscreen;      get(:fullscreen)      end
      def highdpi;         get(:highdpi)         end
      def frames;          get(:frames)          end
      def fps;             get(:fps)             end
      def fps_cap;         get(:fps_cap)         end
      def mouse_x;         get(:mouse_x)         end
      def mouse_y;         get(:mouse_y)         end
      def diagnostics;     get(:diagnostics)     end
      def screenshot(opts = nil); get(:screenshot, opts) end

      def get(sym, opts = nil)
        DSL.window.get(sym, opts)
      end

      def set(opts)
        DSL.window.set(opts)
      end

      def on(event, &proc)
        DSL.window.on(event, &proc)
      end

      def off(event_descriptor)
        DSL.window.off(event_descriptor)
      end

      def add(o)
        DSL.window.add(o)
      end

      def remove(o)
        DSL.window.remove(o)
      end

      def clear
        DSL.window.clear
      end

      def update(&proc)
        DSL.window.update(&proc)
      end

      def render(&proc)
        DSL.window.render(&proc)
      end

      def show
        DSL.window.show
      end

      def close
        DSL.window.close
      end
    end

    # Public instance methods

    # Retrieve an attribute of the window
    def get(sym, opts = nil)
      case sym
      when :window;          self
      when :title;           @title
      when :background;      @background
      when :width;           @width
      when :height;          @height
      when :viewport_width;  @viewport_width
      when :viewport_height; @viewport_height
      when :display_width, :display_height
        ext_get_display_dimensions
        if sym == :display_width
          @display_width
        else
          @display_height
        end
      when :resizable;       @resizable
      when :borderless;      @borderless
      when :fullscreen;      @fullscreen
      when :highdpi;         @highdpi
      when :frames;          @frames
      when :fps;             @fps
      when :fps_cap;         @fps_cap
      when :mouse_x;         @mouse_x
      when :mouse_y;         @mouse_y
      when :diagnostics;     @diagnostics
      when :screenshot;      screenshot(opts)
      end
    end

    # Set a window attribute
    def set(opts)
      # Store new window attributes, or ignore if nil
      @title           = opts[:title]           || @title
      if Color.is_valid? opts[:background]
        @background    = Color.new(opts[:background])
      end
      @icon            = opts[:icon]            || @icon
      @width           = opts[:width]           || @width
      @height          = opts[:height]          || @height
      @fps_cap         = opts[:fps_cap]         || @fps_cap
      @viewport_width  = opts[:viewport_width]  || @viewport_width
      @viewport_height = opts[:viewport_height] || @viewport_height
      @resizable       = opts[:resizable]       || @resizable
      @borderless      = opts[:borderless]      || @borderless
      @fullscreen      = opts[:fullscreen]      || @fullscreen
      @highdpi         = opts[:highdpi]         || @highdpi
      unless opts[:diagnostics].nil?
        @diagnostics = opts[:diagnostics]
        ext_diagnostics(@diagnostics)
      end
    end

    # Add an object to the window
    def add(o)
      case o
      when nil
        raise Error, "Cannot add '#{o.class}' to window!"
      when Entity
        @entities.push(o)
      when Array
        o.each { |x| add_object(x) }
      else
        add_object(o)
      end
    end

    # Remove an object from the window
    def remove(o)
      if o == nil
        raise Error, "Cannot remove '#{o.class}' from window!"
      end

      collection = o.class.ancestors.include?(Ruby2D::Entity) ? @entities : @objects
      if i = collection.index(o)
        collection.delete_at(i)
        true
      else
        false
      end
    end

    # Clear all objects from the window
    def clear
      @objects.clear
      @entities.clear
    end

    # Set the update callback
    def update(&proc)
      @update_proc = proc
      true
    end

    # Set the render callback
    def render(&proc)
      @render_proc = proc
      true
    end

    # Generate a new event key (ID)
    def new_event_key
      @event_key = @event_key.next
    end

    # Set an event handler
    def on(event, &proc)
      unless @events.has_key? event
        raise Error, "`#{event}` is not a valid event type"
      end
      event_id = new_event_key
      @events[event][event_id] = proc
      EventDescriptor.new(event, event_id)
    end

    # Remove an event handler
    def off(event_descriptor)
      @events[event_descriptor.type].delete(event_descriptor.id)
    end

    # Key down event method for class pattern
    def key_down(key)
      @keys_down.include?(key) ? true : false
    end

    # Key held event method for class pattern
    def key_held(key)
      @keys_held.include?(key) ? true : false
    end

    # Key up event method for class pattern
    def key_up(key)
      @keys_up.include?(key) ? true : false
    end

    # Key callback method, called by the native and web extentions
    def key_callback(type, key)
      key = key.downcase

      # All key events
      @events[:key].each do |id, e|
        e.call(KeyEvent.new(type, key))
      end

      case type
      # When key is pressed, fired once
      when :down
        # For class pattern
        unless @keys_down.include? key
          @keys_down << key
        end

        # Call event handler
        @events[:key_down].each do |id, e|
          e.call(KeyEvent.new(type, key))
        end
      # When key is being held down, fired every frame
      when :held
        # For class pattern
        unless @keys_held.include? key
          @keys_held << key
        end

        # Call event handler
        @events[:key_held].each do |id, e|
          e.call(KeyEvent.new(type, key))
        end
      # When key released, fired once
      when :up
        # For class pattern
        unless @keys_up.include? key
          @keys_up << key
        end

        # Call event handler
        @events[:key_up].each do |id, e|
          e.call(KeyEvent.new(type, key))
        end
      end
    end

    # Mouse down event method for class pattern
    def mouse_down(btn)
      @mouse_buttons_down.include?(btn) ? true : false
    end

    # Mouse up event method for class pattern
    def mouse_up(btn)
      @mouse_buttons_up.include?(btn) ? true : false
    end

    # Mouse scroll event method for class pattern
    def mouse_scroll
      @mouse_scroll_event
    end

    # Mouse move event method for class pattern
    def mouse_move
      @mouse_move_event
    end

    # Mouse callback method, called by the native and web extentions
    def mouse_callback(type, button, direction, x, y, delta_x, delta_y)
      # All mouse events
      @events[:mouse].each do |id, e|
        e.call(MouseEvent.new(type, button, direction, x, y, delta_x, delta_y))
      end

      case type
      # When mouse button pressed
      when :down
        # For class pattern
        unless @mouse_buttons_down.include? button
          @mouse_buttons_down << button
        end

        # Call event handler
        @events[:mouse_down].each do |id, e|
          e.call(MouseEvent.new(type, button, nil, x, y, nil, nil))
        end
      # When mouse button released
      when :up
        # For class pattern
        unless @mouse_buttons_up.include? button
          @mouse_buttons_up << button
        end

        # Call event handler
        @events[:mouse_up].each do |id, e|
          e.call(MouseEvent.new(type, button, nil, x, y, nil, nil))
        end
      # When mouse motion / movement
      when :scroll
        # For class pattern
        @mouse_scroll_event     = true
        @mouse_scroll_direction = direction
        @mouse_scroll_delta_x   = delta_x
        @mouse_scroll_delta_y   = delta_y

        # Call event handler
        @events[:mouse_scroll].each do |id, e|
          e.call(MouseEvent.new(type, nil, direction, nil, nil, delta_x, delta_y))
        end
      # When mouse scrolling, wheel or trackpad
      when :move
        # For class pattern
        @mouse_move_event    = true
        @mouse_move_delta_x  = delta_x
        @mouse_move_delta_y  = delta_y

        # Call event handler
        @events[:mouse_move].each do |id, e|
          e.call(MouseEvent.new(type, nil, nil, x, y, delta_x, delta_y))
        end
      end
    end

    # Add controller mappings from file
    def add_controller_mappings
      if File.exist? @controller_mappings
        ext_add_controller_mappings(@controller_mappings)
      end
    end

    # Controller axis event method for class pattern
    def controller_axis(axis)
      @controller_axes_moved.include?(axis) ? true : false
    end

    # Controller button down event method for class pattern
    def controller_button_down(btn)
      @controller_buttons_down.include?(btn) ? true : false
    end

    # Controller button up event method for class pattern
    def controller_button_up(btn)
      @controller_buttons_up.include?(btn) ? true : false
    end

    # Controller callback method, called by the native and web extentions
    def controller_callback(which, type, axis, value, button)
      # All controller events
      @events[:controller].each do |id, e|
        e.call(ControllerEvent.new(which, type, axis, value, button))
      end

      case type
      # When controller axis motion, like analog sticks
      when :axis

        # For class pattern

        @controller_id = which

        unless @controller_axes_moved.include? axis
          @controller_axes_moved << axis
        end

        case axis
        when :left_x
          @controller_axis_left_x = value
        when :left_y
          @controller_axis_left_y = value
        when :right_x
          @controller_axis_right_x = value
        when :right_y
          @controller_axis_right_y = value
        end

        # Call event handler
        @events[:controller_axis].each do |id, e|
          e.call(ControllerAxisEvent.new(which, axis, value))
        end
      # When controller button is pressed
      when :button_down
        # For class pattern
        @controller_id = which
        unless @controller_buttons_down.include? button
          @controller_buttons_down << button
        end

        # Call event handler
        @events[:controller_button_down].each do |id, e|
          e.call(ControllerButtonEvent.new(which, button))
        end
      # When controller button is released
      when :button_up
        # For class pattern
        @controller_id = which
        unless @controller_buttons_up.include? button
          @controller_buttons_up << button
        end

        # Call event handler
        @events[:controller_button_up].each do |id, e|
          e.call(ControllerButtonEvent.new(which, button))
        end
      end
    end

    # Update callback method, called by the native and web extentions
    def update_callback
      unless @using_dsl
        update
      end

      @update_proc.call

      # Run update method on all entities
      @entities.each do |e|
        e.update
      end

      # Accept and eval commands if in console mode
      if @console
        if STDIN.ready?
          cmd = STDIN.gets
          begin
            res = eval(cmd, TOPLEVEL_BINDING)
            STDOUT.puts "=> #{res.inspect}"
            STDOUT.flush
          rescue SyntaxError => se
            STDOUT.puts se
            STDOUT.flush
          rescue Exception => e
            STDOUT.puts e
            STDOUT.flush
          end
        end
      end

      # Clear inputs
      @keys_down.clear
      @keys_held.clear
      @keys_up.clear
      @mouse_buttons_down.clear
      @mouse_buttons_up.clear
      @mouse_scroll_event = false
      @mouse_move_event = false
      @controller_axes_moved.clear
      @controller_buttons_down.clear
      @controller_buttons_up.clear
    end

    # Render callback method, called by the native and web extentions
    def render_callback
      unless @using_dsl
        render
      end

      @render_proc.call

      # Run render method on all entities
      @entities.each do |e|
        e.render
      end
    end

    # Show the window
    def show
      ext_show
    end

    # Take screenshot
    def screenshot(path)
      if path
        ext_screenshot(path)
      else
        if RUBY_ENGINE == 'ruby'
          time = Time.now.utc.strftime '%Y-%m-%d--%H-%M-%S'
        else
          time = Time.now.utc.to_i
        end
        ext_screenshot("./screenshot-#{time}.png")
      end
    end

    # Close the window
    def close
      ext_close
    end

    # Private instance methods

    private

    # An an object to the window, used by the public `add` method
    def add_object(o)
      if !@objects.include?(o)
        index = @objects.index do |object|
          object.z > o.z
        end
        if index
          @objects.insert(index, o)
        else
          @objects.push(o)
        end
        true
      else
        false
      end
    end

  end
end
