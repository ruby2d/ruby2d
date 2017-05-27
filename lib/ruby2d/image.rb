# image.rb

module Ruby2D
  class Image
    include Renderable

    attr_accessor :x, :y, :width, :height, :data
    attr_reader :path, :color

    def initialize(opts = {})
      @path = opts[:path]

      unless RUBY_ENGINE == 'opal'
        unless File.exists? @path
          raise Error, "Cannot find image file `#{@path}`"
        end
      end

      @x = opts[:x] || 0
      @y = opts[:y] || 0
      @z = opts[:x] || 0

      @type_id = 4

      self.color = opts[:color] || 'white'

      ext_image_init(@path)
      add
    end

    def color=(c)
      @color = Color.new(c)
    end

    def contains?(x, y)
      @x < x and @x + @width > x and @y < y and @y + @height > y
    end
  end
end
