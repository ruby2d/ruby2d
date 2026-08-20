# Benchmark — Dynamic bitmap text
#
# Adds 360 BitmapText objects to the window and changes each content every
# frame to a new string. Counterpart to text_dynamic.rb for the built-in
# bitmap font — the per-frame cost is glyph-grid rasterisation plus the
# texture refresh in `BitmapText#content=`.
#
# Why it matters: BitmapText is the zero-dependency choice for counters and
# debug overlays, exactly the text that changes every frame. Native recreates
# the texture per change (Metal's fast path); the web build is meant to upload
# into one persistent grow-only texture, so this is the benchmark that shows
# whether that reuse actually happens.

require 'ruby2d'
require 'ruby2d/benchmark'

CELL_W = 64
CELL_H = 40
COLS = 20  # 1280 / 64
ROWS = 18  # 720 / 40

Ruby2D::Benchmark.run('Bitmap Text (Dynamic)') do
  set title: 'Ruby 2D Benchmark — Bitmap Text (Dynamic)', width: 1280, height: 720

  texts = []

  COLS.times do |i|
    ROWS.times do |j|
      texts << BitmapText.new('0', scale: 2, x: i * CELL_W, y: j * CELL_H)
    end
  end

  frame = 0

  update do
    frame += 1
    texts.each_with_index { |t, idx| t.content = "#{idx}-#{frame}" }
  end
end
