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

    private

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
