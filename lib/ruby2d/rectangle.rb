# rectangle.rb

module Ruby2D
  class Rectangle < Quad

    attr_reader :x, :y, :width, :height

    def initialize(opts = {})
      @x      = opts[:x]      || 0
      @y      = opts[:y]      || 0
      @z      = opts[:z]      || 0
      @width  = opts[:width]  || 200
      @height = opts[:height] || 100

      update_coords(@x, @y, @width, @height)

      self.color = opts[:color] || 'white'
      add
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

    def width=(w)
      @width = w
      update_coords(@x, @y, w, @height)
    end

    def height=(h)
      @height = h
      update_coords(@x, @y, @width, h)
    end

    def contains?(x, y)
      @x < x and @x + @width > x and @y < y and @y + @height > y
    end

    def collided_with?(rect)
      !(@y1 > rect.y3 || @y3 < rect.y1 || @x1 > rect.x2 || @x2 < rect.x1)
    end

    private

    def update_coords(x, y, w, h)
      @x1 = x
      @y1 = y
      @x2 = x + w
      @y2 = y
      @x4 = x
      @y4 = y + h
      @x3 = x + w
      @y3 = y + h
    end

  end
end
