# Ruby2D::Tileset

module Ruby2D
  class Tileset
    include Renderable

    def initialize(path, opts = {})
      unless File.exist? path
        raise Error, "Cannot find tileset image file `#{path}`"
      end
      @path = path
      @tiles = []
      @defined_tiles = {}
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
      @defined_tiles[name] = { x: x, y: y }
    end

    def set_tile(name, coordinates)
      tile = @defined_tiles.fetch(name)

      coordinates.each do |coordinate|
        @tiles.push({
          tile_x: tile.fetch(:x), 
          tile_y: tile.fetch(:y), 
          x: coordinate.fetch(:x),
          y: coordinate.fetch(:y)
        })
      end
    end

    def clear_tiles
      @tiles = []
    end
  end

  def draw(opts = {})
    opts[:tile_width] = opts[:tile_width] || @tile_width
    opts[:tile_height] = opts[:tile_height] || @tile_height
    opts[:padding] = opts[:padding] || @padding
    opts[:spacing] = opts[:spacing] || @spacing

    @tiles.each do |tile|
      self.class.ext_draw(
        [
          self, opts[:tile_width], opts[:tile_height], opts[:padding], opts[:spacing],
          tile.fetch(:tile_x), tile.fetch(:tile_y), tile.fetch(:x),
          tile.fetch(:y)
        ])
    end
  end

  private

  def render
    @tiles.each do |tile|
      self.class.ext_draw(
        [
          self, @tile_width, @tile_height, @padding, @spacing,
          tile.fetch(:tile_x), tile.fetch(:tile_y), tile.fetch(:x),
          tile.fetch(:y)
        ])
    end
  end
end