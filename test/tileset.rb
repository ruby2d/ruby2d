require 'ruby2d'

set background: 'white'

tileset = Tileset.new('test/media/texture_atlas.png', tile_width: 36, tile_height: 45, padding: 2, spacing: 0)

tileset.define_tile('num-1', 0, 0)
tileset.define_tile('num-2', 1, 1)

tileset.set_tile('num-1', [
  {x: 0,  y: 0},
  {x: 100,  y: 100},
  {x: 40, y: 320}
])

tileset.set_tile('num-2', [
  {x: 300,  y: 0},
  {x: 400,  y: 100},
  {x: 500, y: 320}
])

# image = Image.new('test/media/texture_atlas.png', x: 10, y: 20)

show