# triangle.rb

module Ruby2D
  class Triangle
    include Renderable
    
    attr_accessor :x1, :y1, :c1,
                  :x2, :y2, :c2,
                  :x3, :y3, :c3
    attr_reader :color, :type_id, :z
    
    def initialize(x1=50, y1=0, x2=100, y2=100, x3=0, y3=100, c='white', z=0)
      @type_id = 1
      @x1, @y1 = x1, y1
      @x2, @y2 = x2, y2
      @x3, @y3 = x3, y3
      @z = z

      self.color = c
      add
    end
    
    def color=(c)
      @color = Color.from(c)
      update_color(@color)
    end

    def z=(z)
      @z = z
      Application.z_sort
    end
    
    private
    
    def update_color(c)
      if c.is_a? Color::Set
        if c.length == 3
          @c1 = c[0]
          @c2 = c[1]
          @c3 = c[2]
        else
          raise ArgumentError, "Triangles require 3 colors, one for each vertex. #{c.length} were given."
        end
      else
        @c1 = c
        @c2 = c
        @c3 = c
      end
    end
  end
end
