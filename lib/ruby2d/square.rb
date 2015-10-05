# square.rb

module Ruby2D
  class Square < Ruby2D::Rectangle
    
    attr_reader :size
    
    def initialize(x=0, y=0, s=100, c='white')
      @type_id = 2
      @x, @y, @color = x, y, c
      @width = @height = @size = s
      update_coords(x, y, s, s)
      update_color(c)
      
      if defined? Ruby2D::DSL
        Ruby2D::Application.add(self)
      end
    end
    
    def size=(s)
      self.width = self.height = @size = s
    end
    
    private :width=, :height=
  end
end
