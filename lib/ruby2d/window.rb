# window.rb

module Ruby2D
  class Window
    attr_reader :title, :width, :height, :mouse_x, :mouse_y
    
    def initialize(width: 640, height: 480, title: "Ruby 2D", fps: 60, vsync: true)
      @width, @height, @title = width, height, title
      @mouse_x = @mouse_y = 0
      @fps_cap = fps
      @vsync = vsync
      
      @objects = []
      @keys = {}
      @keys_down = {}
      @controller = {}
      @update_proc = Proc.new {}
    end
    
    def get(sym)
      case sym
      when :window
        return self
      when :title
        return @title
      when :width
        return @width
      when :height
        return @height
      when :mouse_x
        return @mouse_x
      when :mouse_y
        return @mouse_y
      end
    end
    
    def set(opts)
      if opts.include? :title
        @title = opts[:title]
      end
      
      if opts.include? :width
        @width = opts[:width]
      end
      
      if opts.include? :height
        @height = opts[:height]
      end
    end
    
    def on(mouse: nil, key: nil, &proc)
      puts "mouse: #{mouse}"
      puts "key: #{key}"
      # proc.call
      key(key, &proc)
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
    
    # Register key string with proc
    def key(key, &proc)
      @keys[key] = proc
      true
    end
    
      unless controller.nil?
        reg_controller(controller, &proc)
      end
    end
    
    def key_callback(key)
      key.downcase!
      if @keys.has_key? key
        @keys[key].call
      end
    end
    
    # Register key string with proc
    def key_down(key, &proc)
      @keys_down[key] = proc
      true
    end
    
    def key_down_callback(key)
      key.downcase!
      if @keys_down.has_key? key
        @keys_down[key].call
      end
    end
    
    def update(&proc)
      @update_proc = proc
      true
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
    
    # Register controller string with proc
    def reg_controller(event, &proc)
      @controller[event] = proc
      true
    end
    
  end
end
