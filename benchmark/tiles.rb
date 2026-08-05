# Benchmark — Tilesets
#
# Fills the window with 14,400 randomly selected tiles every frame via
# Tileset#[]= inside a render block. Tests the tileset rendering path,
# which batches draws from a single texture atlas.
#
# Why it matters: tile-based games (platformers, top-down RPGs, roguelikes)
# can place tens of thousands of tiles in a level; the tileset path is the
# gem's answer to making that fast by sharing one bound texture across all
# draws. Optimisations to the batching loop, vertex packing, or atlas
# sampling are visible here because per-tile cost dominates everything else.
#
# Note: this is a stress workload (re-randomising every tile every frame).
# Real tile maps mutate only changed tiles between frames — see tiles_static.rb
# for the common-case counterpart.

require 'ruby2d'
require 'ruby2d/benchmark'

COLS = 160  # 1280 / 8
ROWS = 90   # 720 / 8
TILE_TYPES = 12  # colors.png is 100x100 at 8px tiles → 12x12 valid grid

Ruby2D::Benchmark.run('Tilesets') do
  set title: 'Ruby 2D Benchmark — Tilesets', width: 1280, height: 720

  tileset = Tileset.new("#{Ruby2D.test_images}/colors.png", tile_width: 8, tile_height: 8)

  TILE_TYPES.times do |i|
    TILE_TYPES.times do |j|
      tileset.define("#{i}-#{j}", i, j)
    end
  end

  render do
    tileset.clear

    COLS.times do |i|
      ROWS.times do |j|
        tileset[i * 8, j * 8] = "#{rand(TILE_TYPES)}-#{rand(TILE_TYPES)}"
      end
    end
  end
end
