# Ruby2D::Line

module Ruby2D
  class Line
    prepend Renderable

    attr_accessor :x1, :x2, :y1, :y2, :width

    def initialize(opts = {})
      @x1 = opts[:x1] || 0
      @y1 = opts[:y1] || 0
      @x2 = opts[:x2] || 100
      @y2 = opts[:y2] || 100
      @z = opts[:z] || 0
      @width = opts[:width] || 2
      self.color = opts[:color] || 'white'
      self.color.opacity = opts[:opacity] if opts[:opacity]
      add
    end

    def color=(c)
      @color = Color.set(c)
      update_color(@color)
    end

    # Return the length of the line
    def length
      points_distance(@x1, @y1, @x2, @y2)
    end

    # Line contains a point if the point is closer than the length of line from
    # both ends and if the distance from point to line is smaller than half of
    # the width. For reference:
    #   https://en.wikipedia.org/wiki/Distance_from_a_point_to_a_line
    def contains?(x, y)
      points_distance(x1, y1, x, y) <= length &&
      points_distance(x2, y2, x, y) <= length &&
      (((@y2 - @y1) * x - (@x2 - @x1) * y + @x2 * @y1 - @y2 * @x1).abs / length) <= 0.5 * @width
    end

    def self.draw(opts = {})
      Window.render_ready_check

      ext_draw([
        opts[:x1], opts[:y1], opts[:x2], opts[:y2], opts[:width],
        opts[:color][0][0], opts[:color][0][1], opts[:color][0][2], opts[:color][0][3],
        opts[:color][1][0], opts[:color][1][1], opts[:color][1][2], opts[:color][1][3],
        opts[:color][2][0], opts[:color][2][1], opts[:color][2][2], opts[:color][2][3],
        opts[:color][3][0], opts[:color][3][1], opts[:color][3][2], opts[:color][3][3]
      ])
    end

    private

    def render
      self.class.ext_draw([
        @x1, @y1, @x2, @y2, @width,
        @c1.r, @c1.g, @c1.b, @c1.a,
        @c2.r, @c2.g, @c2.b, @c2.a,
        @c3.r, @c3.g, @c3.b, @c3.a,
        @c4.r, @c4.g, @c4.b, @c4.a
      ])
    end

    # Calculate the distance between two points
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
          raise ArgumentError, "`#{self.class}` requires 4 colors, one for each vertex. #{c.length} were given."
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
