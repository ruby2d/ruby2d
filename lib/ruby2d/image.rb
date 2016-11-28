# image.rb

module Ruby2D
  class Image
    
    attr_accessor :x, :y
    
    def initialize(x, y, path)
      
      # unless File.exists? path
      #   raise Error, "Cannot find image file `#{path}`"
      # end
      
      @type_id = 3
      @x, @y, @path = x, y, path
      
      if Module.const_defined? :DSL
        Application.add(self)
      end
    end
    
    def remove
      if Module.const_defined? :DSL
        Application.remove(self)
      end
    end
    
  end
end
