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

    def on(event, &proc)
      @@window.on(event, &proc)
    end

    def off(event_descriptor)
      @@window.off(event_descriptor)
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
