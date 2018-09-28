# Ruby2D::Renderable

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

    # Allow shortcuts for setting color values
    def r; self.color.r end
    def g; self.color.g end
    def b; self.color.b end
    def a; self.color.a end
    def r=(c); self.color.r = c end
    def g=(c); self.color.g = c end
    def b=(c); self.color.b = c end
    def a=(c); self.color.a = c end
    def opacity; self.color.opacity end
    def opacity=(val); self.color.opacity = val end

    # Allow British English spelling of color
    def colour; self.color end
    def colour=(c); self.color = c end

    # Add a contains method stub
    def contains?(x, y)
      raise Error, "\`#contains?\` not implemented for this class yet"
    end

  end
end
