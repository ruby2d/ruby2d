# Ruby2D::Text

module Ruby2D
  class Tileset
    include Renderable

    def initialize(path, opts = {})
      unless File.exist? path
        raise Error, "Cannot find tileset image file `#{path}`"
      end
      @path = path
      # FIXME: Need a better name (than to_draw) it's tiles to draw, rather than the tile definitions at @tiles
      @to_draw = []
      @tiles = {}
      @padding = opts[:padding] || 0
      @spacing = opts[:spacing] || 0
      @tile_width = opts[:tile_width]
      @tile_height = opts[:tile_height]

      unless ext_init(@path)
        raise Error, "Tileset `#{@path}` cannot be created"
      end

      unless opts[:show] == false then add end
    end

    def define_tile(name, x, y)
      @tiles[name] = { x: x, y: y }
    end

    def set_tile(name, coordinates)
      tile = @tiles.fetch(name)

      coordinates.each do |coordinate|
        @to_draw.push({
          tile_x: tile.fetch(:x), 
          tile_y: tile.fetch(:y), 
          x: coordinate.fetch(:x),
          y: coordinate.fetch(:y)
        })
      end
    end
  end

  private

  def render

    @to_draw.each do |tile|
      self.class.ext_draw(
        [
          self, @tile_width, @tile_height, @padding, @spacing,
          tile.fetch(:tile_x), tile.fetch(:tile_y), tile.fetch(:x),
          tile.fetch(:y)
        ])
    end
  end
end