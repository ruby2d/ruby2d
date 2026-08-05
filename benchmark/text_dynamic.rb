# Benchmark — Dynamic text
#
# Adds 360 Text objects to the window and changes each Text#content every
# frame to a new string. Counterpart to text.rb — the diff is the per-frame
# glyph rasterisation triggered by Text#content=.
#
# Why it matters: any text whose value changes (FPS counters, score, timer,
# health labels, chat messages) lands here, and this is one of the most
# allocation-heavy paths in the gem — every set re-rasterises glyphs and
# allocates a new texture. Reducing per-set allocations or caching
# rasterised glyphs are the obvious wins.

require 'ruby2d'
require 'ruby2d/benchmark'

CELL_W = 64
CELL_H = 40
COLS = 20  # 1280 / 64
ROWS = 18  # 720 / 40

Ruby2D::Benchmark.run('Text (Dynamic)') do
  set title: 'Ruby 2D Benchmark — Text (Dynamic)', width: 1280, height: 720

  texts = []

  COLS.times do |i|
    ROWS.times do |j|
      texts << Text.new('0', size: 14, x: i * CELL_W, y: j * CELL_H)
    end
  end

  frame = 0

  update do
    frame += 1
    texts.each_with_index { |t, idx| t.content = "#{idx}-#{frame}" }
  end
end
