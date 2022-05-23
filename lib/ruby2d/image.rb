# Ruby2D::Image

module Ruby2D
  class Image
    include Renderable

    attr_reader :path
    attr_accessor :x, :y, :width, :height, :rotate, :data

    # Load an image +path+ and return a Texture, using a pixmap atlas if provided
    # @param [PixmapAtlas] Optional pixmap atlas to use to manage the image file
    # @return [Texture] loaded
    def self.load_image_as_texture(path, atlas:)
      pixmap = if atlas
                 atlas.load_and_keep_image(path, as: path)
               else
                 Pixmap.new path
               end
      pixmap.texture
    end

    def initialize(path, opts = {})
      @path = path

      # Consider input pixmap atlas if supplied to load image file
      @texture = Image.load_image_as_texture path, atlas: opts[:atlas]
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
