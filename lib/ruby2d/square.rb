# square.rb

module Ruby2D
  class Square < Rectangle
    
    attr_reader :size
    
    def initialize(x=0, y=0, s=100, c='white')
      @type_id = 2
      @x, @y = x, y
      @width = @height = @size = s
      update_coords(x, y, s, s)

      self.color = c
      add
    end
    
    def size=(s)
      self.width = self.height = @size = s
    end
    
    private :width=, :height=
  end
end
