# Ruby2D::Tileset

module Ruby2D
  class Tileset
    include Renderable

    def initialize(path, opts = {})
      @path = path

      # Initialize the tileset texture
      @texture = Texture.new(*Image.load_image(@path))
      @width = opts[:width] || @texture.width
      @height = opts[:height] || @texture.height
      @z = opts[:z] || 0

      @tiles = []
      @defined_tiles = {}
      @padding = opts[:padding] || 0
      @spacing = opts[:spacing] || 0
      @tile_width = opts[:tile_width]
      @tile_height = opts[:tile_height]

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
  end

  def draw
    Window.render_ready_check

    render
  end

  private

  def render
    @tiles.each do |tile|
      crop = {
        x: @padding + (tile.fetch(:tile_x) + @spacing) * @tile_width,
        y: @padding + (tile.fetch(:tile_y) + @spacing) * @tile_height,
        width: @tile_width,
        height: @tile_height,
        image_width: @width,
        image_height: @height,
      }

      color = defined?(@color) ? @color : Color.new([1.0, 1.0, 1.0, 1.0])

      vertices = Vertices.new(tile.fetch(:x), tile.fetch(:y), @tile_width, @tile_height, tile.fetch(:tile_rotate), crop: crop, flip: tile.fetch(:tile_flip))

      @texture.draw(
        vertices.coordinates, vertices.texture_coordinates, color
      )
    end
  end
end
