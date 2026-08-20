# Benchmark — Immediate mode, per-vertex gradient
#
# Draws 3,600 squares every frame via Square.render inside a render block,
# each with four distinct random per-vertex colors. Counterpart to
# immediate.rb (one uniform tuple per square) — the diff isolates the
# per-vertex color flattening from the uniform fast path.
#
# Why it matters: gradients are the one immediate-mode color form that can't
# resolve to a single shared color, so every square pays a per-vertex
# flatten. This is the floor for immediate-mode color handling; the uniform
# path in immediate.rb should stay well under it.

require 'ruby2d'
require 'ruby2d/benchmark'

COLS = 80  # 1280 / 16
ROWS = 45  # 720 / 16

Ruby2D::Benchmark.run('Immediate (Gradient)') do
  set title: 'Ruby 2D Benchmark — Immediate (Gradient)', width: 1280, height: 720

  render do
    COLS.times do |i|
      ROWS.times do |j|
        Square.render(x: i * 16, y: j * 16, size: 16,
                      color: [[rand, rand, rand, 1.0], [rand, rand, rand, 1.0],
                              [rand, rand, rand, 1.0], [rand, rand, rand, 1.0]])
      end
    end
  end
end
