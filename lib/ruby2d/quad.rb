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
      
      if defined? Ruby2D::DSL
        Ruby2D::Application.add(self)
      end
    end
    
    def color=(c)
      @color = c
      update_color(c)
    end
    
    def remove
      if defined? Ruby2D::DSL
        Ruby2D::Application.remove(self)
      end
    end
    
    private
    
    def update_color(c)
      # If a 2D array
      if c.class == Array && c.all? { |el| el.class == Array }
        @c1 = Ruby2D::Color.new(c[0])
        @c2 = Ruby2D::Color.new(c[1])
        @c3 = Ruby2D::Color.new(c[2])
        @c4 = Ruby2D::Color.new(c[3])
      else
        @c1 = Ruby2D::Color.new(c)
        @c2 = Ruby2D::Color.new(c)
        @c3 = Ruby2D::Color.new(c)
        @c4 = Ruby2D::Color.new(c)
      end
    end
  end
end
