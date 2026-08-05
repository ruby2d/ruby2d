# Benchmark — Static tileset
#
# Defines a fixed 14,400-tile map once during setup and lets the engine
# render it every frame. Counterpart to tiles.rb (which re-randomises every
# tile per frame) — the diff is the per-frame update cost, leaving just the
# steady-state batch render of a populated tileset.
#
# Why it matters: this is the realistic workload for tile-based games — a
# level is built once and rendered every frame as the camera scrolls over
# it. Performance here directly translates to how big a level a developer
# can ship without dropping frames. Regressions in the inner draw loop or
# tint/uniform application are visible without per-frame placement noise.

require 'ruby2d'
require 'ruby2d/benchmark'

COLS = 160  # 1280 / 8
ROWS = 90   # 720 / 8
TILE_TYPES = 12  # colors.png is 100x100 at 8px tiles → 12x12 valid grid

Ruby2D::Benchmark.run('Tileset (Static)') do
  set title: 'Ruby 2D Benchmark — Tileset (Static)', width: 1280, height: 720

  tileset = Tileset.new("#{Ruby2D.test_images}/colors.png", tile_width: 8, tile_height: 8)

  TILE_TYPES.times do |i|
    TILE_TYPES.times do |j|
      tileset.define("#{i}-#{j}", i, j)
    end
  end

  srand(42)

  COLS.times do |i|
    ROWS.times do |j|
      tileset[i * 8, j * 8] = "#{rand(TILE_TYPES)}-#{rand(TILE_TYPES)}"
    end
  end
end
