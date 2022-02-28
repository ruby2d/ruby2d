# Ruby2D::Image

module Ruby2D
  class Image
    include Renderable

    attr_reader :path
    attr_accessor :x, :y, :width, :height, :rotate, :data

    @@cached_images = {} # Hash[Path, Image]
    @@cached_textures = {} # Hash[Path, Texture]
    # Caching is disabled by default because
    # a user might expect different behavior.
    @@cache = false

    def self.load_image(path)
      unless File.exist? path
        raise Error, "Cannot find image file `#{path}`"
      end

      return ext_load_image(path) unless @cache

      if image = @@cached_images[path]
        image
      else
        @@cached_images[path] = ext_load_image(path)
      end
    end

    def initialize(path, opts = {})
      @path = path

      if @@cache = opts[:cache] and texture = @@cached_textures[path]
        @texture = texture
      else
        @texture = Texture.new(*Image.load_image(@path))
        @@cached_textures[path] = @texture
      end

      @width = opts[:width] || @texture.width
      @height = opts[:height] || @texture.height

      @x = opts[:x] || 0
      @y = opts[:y] || 0
      @z = opts[:z] || 0
      @rotate = opts[:rotate] || 0
      self.color = opts[:color] || 'white'
      self.color.opacity = opts[:opacity] if opts[:opacity]

      unless opts[:show] == false then add end
    end

    def draw(opts = {})
      Window.render_ready_check

      opts[:width] = opts[:width] || @width
      opts[:height] = opts[:height] || @height
      opts[:rotate] = opts[:rotate] || @rotate
      unless opts[:color]
        opts[:color] = [1.0, 1.0, 1.0, 1.0]
      end

      render(x: opts[:x], y: opts[:y], width: opts[:width], height: opts[:height], color: Color.new(opts[:color]), rotate: opts[:rotate])
    end

    private

    def render(x: @x, y: @y, width: @width, height: @height, color: @color, rotate: @rotate)
      vertices = Vertices.new(x, y, width, height, rotate)

      @texture.draw(
        vertices.coordinates, vertices.texture_coordinates, color
      )
    end
  end
end
