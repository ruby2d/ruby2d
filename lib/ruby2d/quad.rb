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
      @color = c
      update_color(c)
      
      if Module.const_defined? :DSL
        Application.add(self)
      end
    end
    
    def color=(c)
      @color = c
      update_color(c)
    end
    
    def remove
      if Module.const_defined? :DSL
        Application.remove(self)
      end
    end
    
    private
    
    def update_color(c)
      
      # If a valid color, use it for each vertex
      if Color.is_valid? c
        @c1 = Color.new(c)
        @c2 = Color.new(c)
        @c3 = Color.new(c)
        @c4 = Color.new(c)
        
      # If a valid array of colors, assign them to each vertex, respectively
      elsif c.all? { |el| Color.is_valid? el }
        @c1 = Color.new(c[0])
        @c2 = Color.new(c[1])
        @c3 = Color.new(c[2])
        @c4 = Color.new(c[3])
      else
        raise Error, "Not a valid color for #{self.class}"
      end
      
    end
  end
end
