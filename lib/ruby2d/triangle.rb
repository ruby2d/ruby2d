# Ruby2D::Triangle

module Ruby2D
  class Triangle
    include Renderable

    attr_accessor :x1, :y1, :c1,
                  :x2, :y2, :c2,
                  :x3, :y3, :c3

    def initialize(opts= {})
      @x1 = opts[:x1] || 50
      @y1 = opts[:y1] || 0
      @x2 = opts[:x2] || 100
      @y2 = opts[:y2] || 100
      @x3 = opts[:x3] || 0
      @y3 = opts[:y3] || 100
      @z  = opts[:z]  || 0
      self.color = opts[:color] || 'white'
      self.opacity = opts[:opacity] if opts[:opacity]
      add
    end

    def color=(c)
      @color = Color.set(c)
      update_color(@color)
    end

    # A point is inside a triangle if the area of 3 triangles, constructed from
    # triangle sides and the given point, is equal to the area of triangle.
    def contains?(x, y)
      self_area = triangle_area(@x1, @y1, @x2, @y2, @x3, @y3)
      questioned_area =
        triangle_area(@x1, @y1, @x2, @y2, x, y) +
        triangle_area(@x2, @y2, @x3, @y3, x, y) +
        triangle_area(@x3, @y3, @x1, @y1, x, y)

      questioned_area <= self_area
    end

    def self.draw(opts = {})
      ext_draw([
        opts[:x1], opts[:y1], opts[:color][0][0], opts[:color][0][1], opts[:color][0][2], opts[:color][0][3],
        opts[:x2], opts[:y2], opts[:color][1][0], opts[:color][1][1], opts[:color][1][2], opts[:color][1][3],
        opts[:x3], opts[:y3], opts[:color][2][0], opts[:color][2][1], opts[:color][2][2], opts[:color][2][3]
      ])
    end

    private

    def render
      self.class.ext_draw([
        @x1, @y1, @c1.r, @c1.g, @c1.b, @c1.a,
        @x2, @y2, @c2.r, @c2.g, @c2.b, @c2.a,
        @x3, @y3, @c3.r, @c3.g, @c3.b, @c3.a
      ])
    end

    def triangle_area(x1, y1, x2, y2, x3, y3)
      (x1*y2 + x2*y3 + x3*y1 - x3*y2 - x1*y3 - x2*y1).abs / 2
    end

    def update_color(c)
      if c.is_a? Color::Set
        if c.length == 3
          @c1 = c[0]
          @c2 = c[1]
          @c3 = c[2]
        else
          raise ArgumentError, "`#{self.class}` requires 3 colors, one for each vertex. #{c.length} were given."
        end
      else
        @c1 = c
        @c2 = c
        @c3 = c
      end
    end

  end
end
