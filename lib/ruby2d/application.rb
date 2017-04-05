# application.rb

module Ruby2D::Application
  class << self
    @@window = Ruby2D::Window.new
    
    def get(sym)
      @@window.get(sym)
    end
    
    def set(opts)
      @@window.set(opts)
    end
    
    def on(args = {}, &proc)
      @@window.on(args, &proc)
    end
    
    def on_key(&proc)
      @@window.on_key(&proc)
    end
    
    def on_controller(&proc)
      @@window.on_controller(&proc)
    end
    
    def add(o)
      @@window.add(o)
    end
    
    def remove(o)
      @@window.remove(o)
    end
    
    def clear
      @@window.clear
    end

    def z_sort
      @@window.dirty = true
    end
    
    def update(&proc)
      @@window.update(&proc)
    end
    
    def show
      @@window.show
    end
    
    def close
      @@window.close
    end
  end
end
