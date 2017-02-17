# triangle.rb

module Ruby2D
  class Triangle
    
    attr_accessor :x1, :y1, :c1,
                  :x2, :y2, :c2,
                  :x3, :y3, :c3
    attr_reader :color, :type_id
    
    def initialize(x1=50, y1=0, x2=100, y2=100, x3=0, y3=100, c='white')
      @type_id = 1
      @x1, @y1 = x1, y1
      @x2, @y2 = x2, y2
      @x3, @y3 = x3, y3
      @color = c
      update_color(c)
      
      if Module.const_defined? :DSL
        Application.add(self)
      end
    end
    
    def color=(c)
      update_color(c)
      @color = c
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
        
      elsif c.class == Array && c.length < 3
        raise Error, "Triangles require 3 colors, one for each vertex. Only " <<
                     "#{c.length} were given."
        
      # If a valid array of colors, assign them to each vertex, respectively
      elsif c.all? { |el| Color.is_valid? el }
        @c1 = Color.new(c[0])
        @c2 = Color.new(c[1])
        @c3 = Color.new(c[2])
        
      else
        raise Error, "Not a valid color for #{self.class}"
      end
      
    end
    
  end
end
