# Ruby2D::Renderable

module Ruby2D
  module Renderable

    attr_reader :z

    # Set the z position (depth) of the object
    def z=(z)
      remove
      @z = z
      add
    end

    # Add the object to the window
    def add
      if Module.const_defined? :DSL
        Window.add(self)
      end
    end

    # Remove the object from the window
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

    # Check if given point is within a rectangle, by default (unless overridden)
    def contains?(x, y)
      @x <= x and @x + @width >= x and @y <= y and @y + @height >= y
    end

  end
end
