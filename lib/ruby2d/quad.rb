# Ruby2D::Quad

module Ruby2D
  class Quad
    include Renderable

    # Coordinates in clockwise order, starting at top left:
    # x1,y1 == top left
    # x2,y2 == top right
    # x3,y3 == bottom right
    # x4,y4 == bottom left
    attr_accessor :x1, :y1, :c1,
                  :x2, :y2, :c2,
                  :x3, :y3, :c3,
                  :x4, :y4, :c4

    def initialize(opts = {})
      @x1 = opts[:x1] || 0
      @y1 = opts[:y1] || 0
      @x2 = opts[:x2] || 100
      @y2 = opts[:y2] || 0
      @x3 = opts[:x3] || 100
      @y3 = opts[:y3] || 100
      @x4 = opts[:x4] || 0
      @y4 = opts[:y4] || 100
      @z  = opts[:z]  || 0
      self.color = opts[:color] || 'white'
      self.opacity = opts[:opacity] if opts[:opacity]
      add
    end

    def color=(c)
      @color = Color.set(c)
      update_color(@color)
    end

    # The logic is the same as for a triangle
    # See triangle.rb for reference
    def contains?(x, y)
      self_area = triangle_area(@x1, @y1, @x2, @y2, @x3, @y3) +
                  triangle_area(@x1, @y1, @x3, @y3, @x4, @y4)

      questioned_area = triangle_area(@x1, @y1, @x2, @y2, x, y) +
                        triangle_area(@x2, @y2, @x3, @y3, x, y) +
                        triangle_area(@x3, @y3, @x4, @y4, x, y) +
                        triangle_area(@x4, @y4, @x1, @y1, x, y)

      questioned_area <= self_area
    end

    def self.draw(opts = {})
      ext_draw([
        opts[:x1], opts[:y1], opts[:color][0][0], opts[:color][0][1], opts[:color][0][2], opts[:color][0][3],
        opts[:x2], opts[:y2], opts[:color][1][0], opts[:color][1][1], opts[:color][1][2], opts[:color][1][3],
        opts[:x3], opts[:y3], opts[:color][2][0], opts[:color][2][1], opts[:color][2][2], opts[:color][2][3],
        opts[:x4], opts[:y4], opts[:color][3][0], opts[:color][3][1], opts[:color][3][2], opts[:color][3][3]
      ])
    end

    private

    def render
      self.class.ext_draw([
        @x1, @y1, @c1.r, @c1.g, @c1.b, @c1.a,
        @x2, @y2, @c2.r, @c2.g, @c2.b, @c2.a,
        @x3, @y3, @c3.r, @c3.g, @c3.b, @c3.a,
        @x4, @y4, @c4.r, @c4.g, @c4.b, @c4.a
      ])
    end

    def triangle_area(x1, y1, x2, y2, x3, y3)
      (x1*y2 + x2*y3 + x3*y1 - x3*y2 - x1*y3 - x2*y1).abs / 2
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
