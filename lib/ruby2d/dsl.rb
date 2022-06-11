# frozen_string_literal: true

module Ruby2D
  # Ruby2D::DSL
  module DSL
    @window = Ruby2D::Window.new

    def self.window
      @window
    end

    def self.window=(window)
      @window = window
    end

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

    def update(&proc)
      DSL.window.update(&proc)
    end

    def render(&proc)
      DSL.window.render(&proc)
    end

    def clear
      DSL.window.clear
    end

    def show
      DSL.window.show
    end

    def close
      DSL.window.close
    end
  end
end
