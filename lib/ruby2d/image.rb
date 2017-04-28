# image.rb

module Ruby2D
  class Image
    include Renderable

    attr_accessor :x, :y, :width, :height, :data
    attr_reader :path, :color
    
    def initialize(x, y, path)
      
      unless RUBY_ENGINE == 'opal'
        unless File.exists? path
          raise Error, "Cannot find image file `#{path}`"
        end
      end
      
      @type_id = 3
      @x, @y, @path = x, y, path
      @color = Color.new([1, 1, 1, 1])
      init(path)
      add
    end
    
    def color=(c)
      @color = Color.new(c)
    end
  end
end
