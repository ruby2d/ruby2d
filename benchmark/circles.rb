# Benchmark — Circles
#
# Adds 14,400 circles at 30 sectors each — ~432,000 triangles and ~1.3M
# vertices per frame.
#
# Why it matters: particle systems — smoke, sparks, projectiles, magic
# effects — are the real workload. At this scale the bottleneck has moved
# past per-object Ruby overhead into vertex submission bandwidth and
# vertex-shader throughput, the regime no other bench in the suite reaches.
# Circles are also the only primitive that tessellates per draw (every one
# builds a fan of sin/cos-derived vertices), so optimisations like unit-
# circle template caching, instanced rendering, or default-sector changes
# show up here and not in the squares benches.

require 'ruby2d'
require 'ruby2d/benchmark'

COLS = 160  # 1280 / 8
ROWS = 90   # 720 / 8

Ruby2D::Benchmark.run('Retained (Circles)') do
  set title: 'Ruby 2D Benchmark — Retained (Circles)', width: 1280, height: 720

  colors = %w[red blue green yellow purple orange white aqua]

  COLS.times do |i|
    ROWS.times do |j|
      Circle.new(x: i * 8 + 4, y: j * 8 + 4, radius: 4,
                 color: colors[(i + j) % colors.length])
    end
  end
end
