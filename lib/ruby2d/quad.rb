# quad.rb

module Ruby2D
  class Quad
    # Coordinates in clockwise order, starting at top left:
    # x1,y1 == top left
    # x2,y2 == top right
    # x3,y3 == bottom right
    # x4,y4 == bottom left
    attr_accessor :x1, :y1, :c1,
                  :x2, :y2, :c2,
                  :x3, :y3, :c3,
                  :x4, :y4, :c4
    
    attr_reader :color
    
    def initialize(x1=0, y1=0, x2=100, y2=0, x3=100, y3=100, x4=100, y4=100, c='white')
      @type_id = 2
      @x1, @y1, @x2, @y2, @x3, @y3, @x4, @y4 = x1, y1, x2, y2, x3, y3, x4, y4
      
      self.color = c
      add
    end
    
    def color=(c)
      @color = Color.from(c)
      update_color(@color)
    end
    
    def add
      if Module.const_defined? :DSL
        Application.add(self)
      end
    end
    
    def remove
      if Module.const_defined? :DSL
        Application.remove(self)
      end
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
          raise ArgumentError, "Quads require 4 colors, one for each vertex. #{c.length} were given."
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
