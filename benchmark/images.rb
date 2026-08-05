# Benchmark — Images
#
# Tiles 3,600 copies of a test image across the window. Each object is a
# textured quad sampled from the same source image, exercising a GPU path
# distinct from solid-color shapes.
#
# Why it matters: any app with sprites, backgrounds, UI icons, or asset art
# lives on the textured-quad path — and Sprite, BitmapText, and Canvas's
# blit operations all share that foundation, so a regression here cascades.
# The single-source design isolates per-quad render cost from texture-
# binding/atlas overhead (which the tiles bench covers).

require 'ruby2d'
require 'ruby2d/benchmark'

SIZE = 16
COLS = 80  # 1280 / 16
ROWS = 45  # 720 / 16

Ruby2D::Benchmark.run('Retained (Images)') do
  set title: 'Ruby 2D Benchmark — Retained (Images)', width: 1280, height: 720

  path = "#{Ruby2D.test_images}/image.png"

  COLS.times do |i|
    ROWS.times do |j|
      Image.new(path, x: i * SIZE, y: j * SIZE, width: SIZE, height: SIZE)
    end
  end
end
