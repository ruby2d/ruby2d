# window.rb

module Ruby2D
  class Window
    attr_reader :title, :width, :height,
                :objects, :diagnostics
    
    attr_accessor :mouse_x, :mouse_y, :frames, :fps
    
    def initialize(args = {})
      @title      = args[:title]  || "Ruby 2D"
      @background = Color.new([0.0, 0.0, 0.0, 1.0])
      @width      = args[:width]  || 640
      @height     = args[:height] || 480
      @viewport_width, @viewport_height = nil, nil
      @resizable  = false
      @borderless = false
      @fullscreen = false
      @highdpi    = false
      @frames     = 0
      @fps_cap    = args[:fps] || 60
      @fps        = @fps_cap
      @vsync      = args[:vsync] || true
      @mouse_x = 0; @mouse_y = 0
      @objects    = []
      @keys_down, @keys, @keys_up, @mouse, @controller = {}, {}, {}, {}, {}
      @on_key_proc        = Proc.new {}
      @on_controller_proc = Proc.new {}
      @update_proc        = Proc.new {}
      @diagnostics        = false
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
        @objects.slice!(i)
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
    
    # def on(mouse: nil, key: nil, key_up: nil, key_down: nil, controller: nil, &proc)
    def on(args = {}, &proc)
      mouse      = args[:mouse]
      key        = args[:key]
      key_up     = args[:key_up]
      key_down   = args[:key_down]
      controller = args[:controller]
      
      unless mouse.nil?
        reg_mouse(mouse, &proc)
      end
      
      unless key_down.nil?
        reg_key_down(key_down, &proc)
      end
      
      unless key.nil?
        reg_key(key, &proc)
      end
      
      unless key_up.nil?
        reg_key_up(key_up, &proc)
      end
      
      unless controller.nil?
        reg_controller(controller, &proc)
      end
    end
    
    def mouse_callback(btn, x, y)
      if @mouse.has_key? 'any'
        @mouse[btn].call(x, y)
      end
    end
    
    def on_key(&proc)
      @on_key_proc = proc
      true
    end
    
    def key_down_callback(key)
      key = key.downcase
      if @keys_down.has_key? 'any'
        @keys_down['any'].call
      end
      if @keys_down.has_key? key
        @keys_down[key].call
      end
    end
    
    def key_callback(key)
      key = key.downcase
      @on_key_proc.call(key)
      if @keys.has_key? 'any'
        @keys['any'].call
      end
      if @keys.has_key? key
        @keys[key].call
      end
    end
    
    def key_up_callback(key)
      key = key.downcase
      if @keys_up.has_key? 'any'
        @keys_up['any'].call
      end
      if @keys_up.has_key? key
        @keys_up[key].call
      end
    end
    
    def on_controller(&proc)
      @on_controller_proc = proc
      true
    end
    
    def controller_callback(which, is_axis, axis, val, is_btn, btn)
      @on_controller_proc.call(which, is_axis, axis, val, is_btn, btn)
      
      if is_axis
        if axis == 0 && val == -32768
          event = 'left'
        elsif axis == 0 && val == 32767
          event = 'right'
        elsif axis == 1 && val == -32768
          event = 'up'
        elsif axis == 1 && val == 32767
          event = 'down'
        end
      elsif is_btn
        event = btn
      end
      
      if @controller.has_key? event
        @controller[event].call
      end
    end
    
    def update_callback
      @update_proc.call
    end
    
    private
    
    def add_object(o)
      if !@objects.include?(o)
        @objects.push(o)
        true
      else
        false
      end
    end
    
    # Register key string with proc
    def reg_key_down(key, &proc)
      @keys_down[key] = proc
      true
    end
    
    # Register key string with proc
    def reg_key(key, &proc)
      @keys[key] = proc
      true
    end
    
    # Register key string with proc
    def reg_key_up(key, &proc)
      @keys_up[key] = proc
      true
    end
    
    # Register mouse button string with proc
    def reg_mouse(btn, &proc)
      @mouse[btn] = proc
      true
    end
    
    # Register controller string with proc
    def reg_controller(event, &proc)
      @controller[event] = proc
      true
    end
    
  end
end
