# image.rb

module Ruby2D
  class Image
    
    attr_accessor :x, :y, :width, :height, :data
    attr_reader :path, :color
    
    def initialize(x, y, path)
      
      # unless File.exists? path
      #   raise Error, "Cannot find image file `#{path}`"
      # end
      
      @type_id = 3
      @x, @y, @path = x, y, path
      @color = Color.new([1, 1, 1, 1])
      add
    end
    
    def color=(c)
      @color = Color.new(c)
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
    
  end
end
