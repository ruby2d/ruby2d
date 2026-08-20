# Benchmark — Immediate mode
#
# Draws 3,600 randomly colored squares every frame via Square.render inside
# a render block, each with a fresh uniform `[r, g, b, a]` tuple. Measures
# Ruby method-call and object-allocation overhead on top of the rendering
# cost. Counterpart to immediate_gradient.rb, which passes four distinct
# per-vertex colors instead.
#
# Why it matters: immediate mode is the right choice for procedural content
# — effects, particles, debug overlays, charts — where the scene changes
# too much for retained mode to pay off. Every shape per frame is a fresh
# Ruby-to-C call with fresh argument allocations, so call dispatch and
# per-call packing dominate the cost. The harness's GC counters here
# surface those allocations directly — the primary lever for cutting GC
# pauses in immediate-heavy apps.

require 'ruby2d'
require 'ruby2d/benchmark'

COLS = 80  # 1280 / 16
ROWS = 45  # 720 / 16

Ruby2D::Benchmark.run('Immediate (Squares)') do
  set title: 'Ruby 2D Benchmark — Immediate (Squares)', width: 1280, height: 720

  render do
    COLS.times do |i|
      ROWS.times do |j|
        Square.render(x: i * 16, y: j * 16, size: 16, color: [rand, rand, rand, 1.0])
      end
    end
  end
end
