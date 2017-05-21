# line.rb

module Ruby2D
  class Line
    include Renderable
    attr_accessor :x1, :x2, :y1, :y2, :color, :width

    def initialize(x1, y1, x2, y2, width=2, c='white', z=0)
      @type_id = 3
      @x1, @y1, @x2, @y2 = x1, y1, x2, y2
      @width = width
      @z = z
      self.color = c
      add
    end

    def color=(c)
      @color = Color.from(c)
      update_color(@color)
    end

    def length
      points_distance(@x1, @y1, @x2, @y2)
    end

    # Line contains a point if the point is closer than the length of line from both ends
    # and if the distance from point to line is smaller than half of the width.
    # Check https://en.wikipedia.org/wiki/Distance_from_a_point_to_a_line for reference
    def contains?(x, y)
      points_distance(x1, y1, x, y) < length and
      points_distance(x2, y2, x, y) < length and
      (((@y2 - @y1) * x - (@x2 - @x1) * y + @x2 * @y1 - @y2 * @x1).abs / length) < 0.5 * @width
    end

    private

    def points_distance(x1, y1, x2, y2)
      Math.sqrt((x1 - x2) ** 2 + (y1 - y2) ** 2)
    end

    def update_color(c)
      if c.is_a? Color::Set
        if c.length == 4
          @c1 = c[0]
          @c2 = c[1]
          @c3 = c[2]
          @c4 = c[3]
        else
          raise ArgumentError, "Lines require 4 colors, one for each vertex. #{c.length} were given."
        end
      else
        @c1 = c
        @c2 = c
        @c3 = c
        @c4 = c
      end
    end
  end
end
