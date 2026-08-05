# Benchmark — Multi-texture images
#
# Tiles 3,600 image instances across the window, cycling through 4 distinct
# source images so adjacent draws force texture rebinds. Counterpart to
# images.rb (which uses one source) — the diff isolates GPU texture-binding
# and state-change overhead from per-quad render cost.
#
# Why it matters: real games use multiple textures — distinct sprite sheets,
# UI icons, backgrounds, particles — and the engine renders them in scene-
# graph order without grouping by texture. Each rebind is a GPU state
# change with non-trivial driver overhead, and on hardware where binds are
# slow it can dominate frame time. Optimisations like texture-bind caching,
# render sorting by texture, or atlas packing only show up here; images.rb
# always hits the same-texture fast path.

require 'ruby2d'
require 'ruby2d/benchmark'

SIZE = 16
COLS = 80  # 1280 / 16
ROWS = 45  # 720 / 16

Ruby2D::Benchmark.run('Images (Multi-texture)') do
  set title: 'Ruby 2D Benchmark — Images (Multi-texture)', width: 1280, height: 720

  paths = %w[image.png boom.png hero.png coin.png].map { |f| "#{Ruby2D.test_images}/#{f}" }

  COLS.times do |i|
    ROWS.times do |j|
      Image.new(paths[(i + j) % paths.length],
                x: i * SIZE, y: j * SIZE,
                width: SIZE, height: SIZE)
    end
  end
end
