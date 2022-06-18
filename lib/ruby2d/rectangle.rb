# frozen_string_literal: true

# Ruby2D::Rectangle

module Ruby2D
  # A rectangle
  class Rectangle < Quad
    # Create an rectangle
    # @param [Numeric] x
    # @param [Numeric] y
    # @param [Numeric] width
    # @param [Numeric] height
    # @param [Numeric] z
    # @param [String, Array] color A single colour or an array of exactly 4 colours
    # @param [Numeric] opacity Opacity of the image when rendering
    # @raise [ArgumentError] if an array of colours does not have 4 entries
    def initialize(x: 0, y: 0, width: 200, height: 100, z: 0, color: nil, colour: nil, opacity: nil)
      @width = width
      @height = height
      super(x1: @x = x, y1: @y = y,
            x2: x + width, y2: y,
            x3: x + width, y3: y + height,
            x4: x, y4: y + height, z: z, color: color, colour: colour, opacity: opacity)
    end

    def x=(x)
      @x = @x1 = x
      @x2 = x + @width
      @x3 = x + @width
      @x4 = x
    end

    def y=(y)
      @y = @y1 = y
      @y2 = y
      @y3 = y + @height
      @y4 = y + @height
    end

    def width=(width)
      @width = width
      @x2 = @x1 + width
      @x3 = @x1 + width
    end

    def height=(height)
      @height = height
      @y3 = @y1 + height
      @y4 = @y1 + height
    end

    def self.draw(x:, y:, width:, height:, color:)
      super(x1: x, y1: y,
            x2: x + width, y2: y,
            x3: x + width, y3: y + height,
            x4: x, y4: y + height, color: color)
    end
  end
end
