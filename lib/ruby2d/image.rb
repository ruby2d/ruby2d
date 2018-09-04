# image.rb

module Ruby2D
  class Image
    include Renderable

    attr_reader :path, :color
    attr_accessor :x, :y, :width, :height, :rotate, :data

    def initialize(opts = {})
      @path = opts[:path]

      unless RUBY_ENGINE == 'opal'
        unless File.exists? @path
          raise Error, "Cannot find image file `#{@path}`"
        end
      end

      @x = opts[:x] || 0
      @y = opts[:y] || 0
      @z = opts[:z] || 0
      @width  = opts[:width]  || nil
      @height = opts[:height] || nil
      @rotate = 0

      self.color = opts[:color] || 'white'

      ext_init(@path)
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
