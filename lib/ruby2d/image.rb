# image.rb

module Ruby2D
  class Image
    
    attr_accessor :x, :y
    
    def initialize(x, y, path)
      
      unless File.exists? path
        raise Ruby2D::Error, "Cannot find image file!"
      end
      
      @type_id = 3
      @x, @y, @path = x, y, path
      
      if defined? Ruby2D::DSL
        Ruby2D::Application.add(self)
      end
    end
    
    def remove
      if defined? Ruby2D::DSL
        Ruby2D::Application.remove(self)
      end
    end
    
  end
end
