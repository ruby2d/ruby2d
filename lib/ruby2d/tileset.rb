# Ruby2D::Tileset

module Ruby2D
  class Tileset
    DEFAULT_COLOR = Color.new([1.0, 1.0, 1.0, 1.0])

    include Renderable

    def initialize(path, opts = {})
      @path = path

      # Initialize the tileset texture
      # Consider input pixmap atlas if supplied to load image file
      @texture = Image.load_image_as_texture path, atlas: opts[:atlas]
      @width = opts[:width] || @texture.width
      @height = opts[:height] || @texture.height
      @z = opts[:z] || 0

      @tiles = []
      @defined_tiles = {}
      @padding = opts[:padding] || 0
      @spacing = opts[:spacing] || 0
      @tile_width = opts[:tile_width]
      @tile_height = opts[:tile_height]
      @scale = opts[:scale] || 1

      unless opts[:show] == false then add end
    end

    def define_tile(name, x, y, rotate: 0, flip: nil)
      @defined_tiles[name] = { x: x, y: y , rotate: rotate, flip: flip }
    end

    def set_tile(name, coordinates)
      tile = @defined_tiles.fetch(name)

      coordinates.each do |coordinate|
        @tiles.push({
          tile_x: tile.fetch(:x), 
          tile_y: tile.fetch(:y), 
          tile_rotate: tile.fetch(:rotate),
          tile_flip: tile.fetch(:flip),
          x: coordinate.fetch(:x),
          y: coordinate.fetch(:y)
        })
      end
    end

    def clear_tiles
      @tiles = []
    end

    def draw
      Window.render_ready_check

      render
    end

    private

    def render
      scaled_padding = @padding * @scale
      scaled_spacing = @spacing * @scale
      scaled_tile_width = @tile_width * @scale
      scaled_tile_height = @tile_height * @scale
      scaled_width = @width * @scale
      scaled_height = @height * @scale

      @tiles.each do |tile|
        crop = {
          x: scaled_padding + (tile.fetch(:tile_x) * (scaled_spacing + scaled_tile_width)),
          y: scaled_padding + (tile.fetch(:tile_y) * (scaled_spacing + scaled_tile_height)),
          width: scaled_tile_width,
          height: scaled_tile_height,
          image_width: scaled_width,
          image_height: scaled_height,
        }

        color = defined?(@color) ? @color : DEFAULT_COLOR

        vertices = Vertices.new(tile.fetch(:x), tile.fetch(:y), scaled_tile_width, scaled_tile_height, tile.fetch(:tile_rotate), crop: crop, flip: tile.fetch(:tile_flip))

        @texture.draw(
          vertices.coordinates, vertices.texture_coordinates, color
        )
      end
    end
  end
end
