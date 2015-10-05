# triangle.rb

module Ruby2D
  class Triangle
    
    attr_accessor :x1, :y1, :c1,
                  :x2, :y2, :c2,
                  :x3, :y3, :c3
    attr_reader :color
    
    def initialize(x1, y1, x2, y2, x3, y3, c='white')
      @type_id = 1
      @x1, @y1 = x1, y1
      @x2, @y2 = x2, y2
      @x3, @y3 = x3, y3
      @color = c
      update_color(c)
      
      if defined? Ruby2D::DSL
        Ruby2D::Application.add(self)
      end
    end
    
    def color=(c)
      update_color(c)
      @color = c
    end
    
    private
    
    def update_color(c)
      # If a 2D array
      if c.class == Array && c.all? { |el| el.class == Array }
        @c1 = Ruby2D::Color.new(c[0])
        @c2 = Ruby2D::Color.new(c[1])
        @c3 = Ruby2D::Color.new(c[2])
      else
        @c1 = Ruby2D::Color.new(c)
        @c2 = Ruby2D::Color.new(c)
        @c3 = Ruby2D::Color.new(c)
      end
    end
    
  end
end
