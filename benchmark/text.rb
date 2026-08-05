# Benchmark — Text
#
# Fills the window with 1,440 static text objects, each rendered from the
# default TTF font. Tests the cached-glyph render path: each Text object
# rasterises its content to a texture at construction and reuses it every
# frame thereafter.
#
# Why it matters: most text in real apps is static — UI labels, button
# captions, tooltips, dialogue — and lives on this fast path. This bench
# measures per-text-object render overhead once rasterisation is out of
# the way. Pair with text_dynamic.rb to see what bypassing the cache costs.

require 'ruby2d'
require 'ruby2d/benchmark'

CELL_W = 40
CELL_H = 16
COLS = 32  # 1280 / 40
ROWS = 45  # 720 / 16

Ruby2D::Benchmark.run('Retained (Text)') do
  set title: 'Ruby 2D Benchmark — Retained (Text)', width: 1280, height: 720

  COLS.times do |i|
    ROWS.times do |j|
      Text.new('Hello', size: 10, x: i * CELL_W, y: j * CELL_H)
    end
  end
end
