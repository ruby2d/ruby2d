# Ruby2D::Renderable

module Ruby2D
  module Renderable

    attr_reader :x, :y, :z, :width, :height, :color

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

    # Set the color value
    def color=(c)
      @color = Color.new(c)
    end

    # Allow British English spelling of color
    def colour; self.color end
    def colour=(c); self.color = c end

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

    # Add a contains method stub
    def contains?(x, y)
      x >= @x && x <= (@x + @width) && y >= @y && y <= (@y + @height)
    end

  end
end
