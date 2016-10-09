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
    
    def on(mouse: nil, key: nil, key_up: nil, key_down: nil, controller: nil, &proc)
      @@window.on(mouse: mouse, key: key, key_up: key_up, key_down: key_down, controller: controller, &proc)
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
