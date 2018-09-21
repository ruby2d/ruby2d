module Ruby2D
  module Renderable
    attr_reader :z

    def z=(z)
      remove
      @z = z
      add
    end

    def add
      if Module.const_defined? :DSL
        Window.add(self)
      end
    end

    def remove
      if Module.const_defined? :DSL
        Window.remove(self)
      end
    end

    def opacity
      self.color.opacity
    end

    def opacity=(val)
      self.color.opacity = val
    end

    def contains?(x, y)
      raise "Not implemented yet"
    end
  end
end
