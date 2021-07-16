require 'ruby2d'

tileset = Tileset.new('test/media/texture_atlas.png', tile_width: 32, tile_height: 32, padding: 0, spacing: 0)

tileset.define_tile('water-1', 1, 1)

tileset.set_tile('water-1', [
  {x: 40,  y: 100},
  {x: 80,  y: 100},
  {x: 120, y: 100}
])

# image = Image.new('test/media/texture_atlas.png', x: 10, y: 20)

show