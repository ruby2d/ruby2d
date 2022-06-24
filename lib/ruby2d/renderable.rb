# frozen_string_literal: true

# Ruby2D::Renderable

module Ruby2D
  # Base class for all renderable shapes
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
      Window.add(self)
    end

    # Remove the object from the window
    def remove
      Window.remove(self)
    end

    # Set the color value
    def color=(color)
      @color = Color.new(color)
    end

    # Allow British English spelling of color
    alias colour color
    alias colour= color=

    # Add a contains method stub
    def contains?(x, y)
      x >= @x && x <= (@x + @width) && y >= @y && y <= (@y + @height)
    end
  end
end
