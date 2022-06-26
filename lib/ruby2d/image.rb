# frozen_string_literal: true

# Ruby2D::Image

module Ruby2D
  # Images in many popular formats can be drawn in the window.
  # To draw an image in the window, use the following, providing the image file path:
  # +Image.new('star.png')+
  class Image
    include Renderable

    attr_reader :path
    attr_accessor :x, :y, :width, :height, :rotate, :data

    # Load an image +path+ and return a Texture, using a pixmap atlas if provided
    # @param path [#to_s] The location of the file to load as an image.
    # @param atlas [PixmapAtlas] Pixmap atlas to use to manage the image file
    # @return [Texture] loaded
    def self.load_image_as_texture(path, atlas:)
      pixmap = if atlas
                 atlas.load_and_keep_image(path, as: path)
               else
                 Pixmap.new path
               end
      pixmap.texture
    end

    # Create an Image
    # @param path [#to_s] The location of the file to load as an image.
    # @param width [Numeric] The +width+ of image, or default is width from image file
    # @param height [Numeric] The +height+ of image, or default is height from image file
    # @param x [Numeric]
    # @param y [Numeric]
    # @param z [Numeric]
    # @param rotate [Numeric] Angle, default is 0
    # @param color [Numeric] (or +colour+) Tint the image when rendering
    # @param opacity [Numeric] Opacity of the image when rendering
    # @param show [Boolean] If +true+ the image is added to +Window+ automatically.
    def initialize(path, atlas: nil,
                   width: nil, height: nil, x: 0, y: 0, z: 0,
                   rotate: 0, color: nil, colour: nil,
                   opacity: nil, show: true)
      @path = path.to_s

      # Consider input pixmap atlas if supplied to load image file
      @texture = Image.load_image_as_texture @path, atlas: atlas
      @width = width || @texture.width
      @height = height || @texture.height

      @x = x
      @y = y
      @z = z
      @rotate = rotate
      self.color = color || colour || 'white'
      self.color.opacity = opacity unless opacity.nil?

      add if show
    end

    def draw(x: 0, y: 0, width: nil, height: nil, rotate: 0, color: nil, colour: nil)
      Window.render_ready_check

      render(x: x, y: y, width:
        width || @width, height: height || @height,
             color: Color.new(color || colour || 'white'),
             rotate: rotate || @rotate)
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
