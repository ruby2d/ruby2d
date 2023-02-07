require 'ruby2d'

class GameWindow < Ruby2D::Window
  TILE_WIDTH = 36
  TILE_HEIGHT = 45
  SCALE = 4

  def initialize
    super
    set width: 108 * SCALE
    set height: 135 * SCALE
    set background: 'white'
    @tileset = Tileset.new("#{Ruby2D.test_media}/texture_atlas.png", tile_width: TILE_WIDTH, tile_height: TILE_HEIGHT, scale: SCALE)

    on :mouse_down do |action|
      x = (action.x / SCALE / TILE_WIDTH) * TILE_WIDTH * SCALE
      y = (action.y / SCALE / TILE_HEIGHT) * TILE_HEIGHT * SCALE

      tile = @tileset.get_tile(x, y)
      next_num = ['num-1', 'num-2', 'num-3'].cycle(2).to_a[tile.fetch(:name)[-1].to_i]
      @tileset.replace_tiles(next_num, [{x: x, y: y}])
    end

    @tileset.clear_tiles

    @tileset.define_tile('num-1', 0, 0, flip: :both)
    @tileset.define_tile('num-2', 1, 1, rotate: 20)
    @tileset.define_tile('num-3', 2, 0)

    @tileset.set_tile('num-1', [
      {x: TILE_WIDTH * SCALE * 0, y: TILE_HEIGHT * SCALE * 0},
      {x: TILE_WIDTH * SCALE * 1, y: TILE_HEIGHT * SCALE * 1},
      {x: TILE_WIDTH * SCALE * 2, y: TILE_HEIGHT * SCALE * 2}
    ])

    @tileset.set_tile('num-2', [
      {x: TILE_WIDTH * SCALE * 0, y: TILE_HEIGHT * SCALE * 1},
      {x: TILE_WIDTH * SCALE * 1, y: TILE_HEIGHT * SCALE * 2},
      {x: TILE_WIDTH * SCALE * 2, y: TILE_HEIGHT * SCALE * 0},
    ])

    @tileset.set_tile('num-3', [
      {x: TILE_WIDTH * SCALE * 0, y: TILE_HEIGHT * SCALE * 2},
      {x: TILE_WIDTH * SCALE * 1, y: TILE_HEIGHT * SCALE * 0},
      {x: TILE_WIDTH * SCALE * 2, y: TILE_HEIGHT * SCALE * 1},
    ])
  end

  def update
  end

  def render
    @tileset.draw
  end
end

GameWindow.new.show
