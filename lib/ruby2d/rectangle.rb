# rectangle.rb

module Ruby2D
  class Rectangle < Quad
    
    attr_reader :x, :y, :width, :height
    
    def initialize(x=0, y=0, w=200, h=100, c='white', z=0)
      @type_id = 2
      @x, @y, @z, @width, @height = x, y, z, w, h
      update_coords(x, y, w, h)

      self.color = c
      add
    end
    
    def x=(x)
      @x = @x1 = x
      @x2 = x + @width
      @x3 = x + @width
      @x4 = x
    end
    
    def y=(y)
      @y = @y1 = y
      @y2 = y
      @y3 = y + @height
      @y4 = y + @height
    end
    
    def width=(w)
      @width = w
      update_coords(@x, @y, w, @height)
    end
    
    def height=(h)
      @height = h
      update_coords(@x, @y, @width, h)
    end
    
    private
    
    def update_coords(x, y, w, h)
      @x1 = x
      @y1 = y
      @x2 = x + w
      @y2 = y
      @x4 = x
      @y4 = y + h
      @x3 = x + w
      @y3 = y + h
    end
    
  end
end
