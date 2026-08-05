# Benchmark — Retained mode
#
# Adds 3,600 squares to the window once and lets the engine render them
# every frame with no Ruby work in the update loop. Isolates the C
# extension and GPU rendering throughput from Ruby overhead.
#
# Why it matters: retained mode is the gem's happy path — most apps add
# objects once and mutate them occasionally. Changes to scene-graph
# traversal, vertex packing, or draw-call batching show up here directly,
# without Ruby-side noise.

require 'ruby2d'
require 'ruby2d/benchmark'

COLS = 80  # 1280 / 16
ROWS = 45  # 720 / 16

Ruby2D::Benchmark.run('Retained (Squares)') do
  set title: 'Ruby 2D Benchmark — Retained (Squares)', width: 1280, height: 720

  colors = %w[red blue green yellow purple orange white aqua]

  COLS.times do |i|
    ROWS.times do |j|
      Square.new(x: i * 16, y: j * 16, size: 16, color: colors[(i + j) % colors.length])
    end
  end
end
