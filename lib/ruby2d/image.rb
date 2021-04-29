# Ruby2D::Image

module Ruby2D
  class Image
    include Renderable

    attr_reader :path
    attr_accessor :x, :y, :width, :height, :rotate, :data

    def initialize(path, opts = {})
      unless File.exist? path
        raise Error, "Cannot find image file `#{path}`"
      end
      @path = path
      @x = opts[:x] || 0
      @y = opts[:y] || 0
      @z = opts[:z] || 0
      @width = opts[:width] || nil
      @height = opts[:height] || nil
      @rotate = opts[:rotate] || 0
      self.color = opts[:color] || 'white'
      self.opacity = opts[:opacity] if opts[:opacity]
      unless ext_init(@path)
        raise Error, "Image `#{@path}` cannot be created"
      end
      unless opts[:show] == false then add end
    end

    def draw(opts = {})
      opts[:width] = opts[:width] || @width
      opts[:height] = opts[:height] || @height
      opts[:rotate] = opts[:rotate] || @rotate
      unless opts[:color]
        opts[:color] = [1.0, 1.0, 1.0, 1.0]
      end

      self.class.ext_draw([
        self, opts[:x], opts[:y], opts[:width], opts[:height], opts[:rotate],
        opts[:color][0], opts[:color][1], opts[:color][2], opts[:color][3]
      ])
    end

    private

    def render
      self.class.ext_draw([
        self, @x, @y, @width, @height, @rotate,
        @color.r, @color.g, @color.b, @color.a
      ])
    end

  end
end
