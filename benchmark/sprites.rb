# Benchmark — Sprite animation
#
# Adds 3,600 animated sprites to the window, each looping a 4-frame clip
# animation over a shared image. Counterpart to images.rb — the diff isolates
# the per-frame animation-update cost (frame timing, clip-rect updates) from
# the textured-quad render path.
#
# Note: uses the 100×100 `colors.png` clipped into four 25-px frames as a
# stand-in sprite sheet. Swap in a dedicated sheet (e.g. `coin.png`) with its
# real frame size if one is available in the test media.
#
# Why it matters: animated sprites are the centerpiece of game-style usage.
# Every Sprite#update call checks elapsed time, conditionally advances a
# frame index, and recomputes the clip rectangle. Multiplied by hundreds of
# sprites, a regression in that path is felt as visible stutter.

require 'ruby2d'
require 'ruby2d/benchmark'

COLS = 80  # 1280 / 16
ROWS = 45  # 720 / 16
SIZE = 16

Ruby2D::Benchmark.run('Sprites') do
  set title: 'Ruby 2D Benchmark — Sprites', width: 1280, height: 720

  path = "#{Ruby2D.test_images}/colors.png"

  COLS.times do |i|
    ROWS.times do |j|
      sprite = Sprite.new(path,
                          x: i * SIZE, y: j * SIZE,
                          width: SIZE, height: SIZE,
                          clip_width: 25, clip_height: 25,
                          time: 100)
      sprite.play(loop: true)
    end
  end
end
