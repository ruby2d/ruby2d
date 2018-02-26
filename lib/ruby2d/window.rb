# window.rb

module Ruby2D
  class Window

    attr_reader :objects
    attr_accessor :mouse_x, :mouse_y, :frames, :fps

    EventDescriptor = Struct.new(:type, :id)
    MouseEvent = Struct.new(:type, :button, :direction, :x, :y, :delta_x, :delta_y)
    KeyEvent   = Struct.new(:type, :key)
    ControllerEvent = Struct.new(:which, :type, :axis, :value, :button)
    ControllerAxisEvent   = Struct.new(:which, :axis, :value)
    ControllerButtonEvent = Struct.new(:which, :button)

    def initialize(args = {})
      @title      = args[:title]  || "Ruby 2D"
      @background = Color.new([0.0, 0.0, 0.0, 1.0])
      @width      = args[:width]  || 640
      @height     = args[:height] || 480
      @viewport_width, @viewport_height = nil, nil
      @display_width, @display_height = nil, nil
      @resizable  = false
      @borderless = false
      @fullscreen = false
      @highdpi    = false
      @frames     = 0
      @fps_cap    = args[:fps]    || 60
      @fps        = @fps_cap
      @vsync      = args[:vsync]  || true
      @mouse_x, @mouse_y = 0, 0
      @objects    = []
      @event_key  = 0
      @events     = {
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
      @update_proc = Proc.new {}
      @diagnostics = false
    end

    def new_event_key
      @event_key = @event_key.next
    end

    def get(sym)
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
      when :mouse_x;         @mouse_x
      when :mouse_y;         @mouse_y
      when :diagnostics;     @diagnostics
      end
    end

    def set(opts)
      # Store new window attributes, or ignore if nil
      @title           = opts[:title]           || @title
      if Color.is_valid? opts[:background]
        @background    = Color.new(opts[:background])
      end
      @width           = opts[:width]           || @width
      @height          = opts[:height]          || @height
      @viewport_width  = opts[:viewport_width]  || @viewport_width
      @viewport_height = opts[:viewport_height] || @viewport_height
      @resizable       = opts[:resizable]       || @resizable
      @borderless      = opts[:borderless]      || @borderless
      @fullscreen      = opts[:fullscreen]      || @fullscreen
      @highdpi         = opts[:highdpi]         || @highdpi
      @diagnostics     = opts[:diagnostics]     || @diagnostics
    end

    def add(o)
      case o
      when nil
        raise Error, "Cannot add '#{o.class}' to window!"
      when Array
        o.each { |x| add_object(x) }
      else
        add_object(o)
      end
    end

    def remove(o)
      if o == nil
        raise Error, "Cannot remove '#{o.class}' from window!"
      end

      if i = @objects.index(o)
        @objects.delete_at(i)
        true
      else
        false
      end
    end

    def clear
      @objects.clear
    end

    def update(&proc)
      @update_proc = proc
      true
    end

    def on(event, &proc)
      unless @events.has_key? event
        raise Error, "`#{event}` is not a valid event type"
      end
      event_id = new_event_key
      @events[event][event_id] = proc
      EventDescriptor.new(event, event_id)
    end

    def off(event_descriptor)
      @events[event_descriptor.type].delete(event_descriptor.id)
    end

    def key_callback(type, key)
      # puts "===", "type: #{type}", "key: #{key}"

      key = key.downcase

      # All key events
      @events[:key].each do |id, e|
        e.call(KeyEvent.new(type, key))
      end

      case type
      # When key is pressed, fired once
      when :down
        @events[:key_down].each do |id, e|
          e.call(KeyEvent.new(type, key))
        end
      # When key is being held down, fired every frame
      when :held
        @events[:key_held].each do |id, e|
          e.call(KeyEvent.new(type, key))
        end
      # When key released, fired once
      when :up
        @events[:key_up].each do |id, e|
          e.call(KeyEvent.new(type, key))
        end
      end
    end

    def mouse_callback(type, button, direction, x, y, delta_x, delta_y)
      # All mouse events
      @events[:mouse].each do |id, e|
        e.call(MouseEvent.new(type, button, direction, x, y, delta_x, delta_y))
      end

      case type
      # When mouse button pressed
      when :down
        @events[:mouse_down].each do |id, e|
          e.call(MouseEvent.new(type, button, nil, x, y, nil, nil))
        end
      # When mouse button released
      when :up
        @events[:mouse_up].each do |id, e|
          e.call(MouseEvent.new(type, button, nil, x, y, nil, nil))
        end
      # When mouse motion / movement
      when :scroll
        @events[:mouse_scroll].each do |id, e|
          e.call(MouseEvent.new(type, nil, direction, nil, nil, delta_x, delta_y))
        end
      # When mouse scrolling, wheel or trackpad
      when :move
        @events[:mouse_move].each do |id, e|
          e.call(MouseEvent.new(type, nil, nil, x, y, delta_x, delta_y))
        end
      end
    end

    def controller_callback(which, type, axis, value, button)
      # All controller events
      @events[:controller].each do |id, e|
        e.call(ControllerEvent.new(which, type, axis, value, button))
      end

      case type
      # When controller axis motion, like analog sticks
      when :axis
        @events[:controller_axis].each do |id, e|
          e.call(ControllerAxisEvent.new(which, axis, value))
        end
      # When controller button is pressed
      when :button_down
        @events[:controller_button_down].each do |id, e|
          e.call(ControllerButtonEvent.new(which, button))
        end
      # When controller button is released
      when :button_up
        @events[:controller_button_up].each do |id, e|
          e.call(ControllerButtonEvent.new(which, button))
        end
      end
    end

    def update_callback
      @update_proc.call
    end

    def show
      ext_show
    end

    def close
      ext_close
    end

    private

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
