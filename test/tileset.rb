require 'ruby2d'

class GameWindow < Ruby2D::Window
  TILE_WIDTH = 36
  TILE_HEIGHT = 45

  def initialize
    super
    set width: 108
    set height: 135
    set background: 'white'
    @tileset = Tileset.new('test/media/texture_atlas.png', tile_width: TILE_WIDTH, tile_height: TILE_HEIGHT)
  end

  def update
    @tileset.clear_tiles

    @tileset.define_tile('num-1', 0, 0)
    @tileset.define_tile('num-2', 1, 1)
    @tileset.define_tile('num-3', 2, 0)

    @tileset.set_tile('num-1', [
      {x: TILE_WIDTH * 0, y: TILE_HEIGHT * 0},
      {x: TILE_WIDTH * 1, y: TILE_HEIGHT * 1},
      {x: TILE_WIDTH * 2, y: TILE_HEIGHT * 2}
    ])

    @tileset.set_tile('num-2', [
      {x: TILE_WIDTH * 0, y: TILE_HEIGHT * 1},
      {x: TILE_WIDTH * 1, y: TILE_HEIGHT * 2},
      {x: TILE_WIDTH * 2, y: TILE_HEIGHT * 0},
    ])

    @tileset.set_tile('num-3', [
      {x: TILE_WIDTH * 0, y: TILE_HEIGHT * 2},
      {x: TILE_WIDTH * 1, y: TILE_HEIGHT * 0},
      {x: TILE_WIDTH * 2, y: TILE_HEIGHT * 1},
    ])
  end

  def render
    @tileset.draw
  end
end

GameWindow.new.show