# Benchmark — Incremental canvas drawing
#
# Stamps 50 small filled circles onto a Canvas every frame without clearing,
# letting the surface accumulate draws over time. Counterpart to canvas.rb
# (which clears and repaints the whole surface every frame) — the diff is
# the per-frame full-clear and bulk repaint, leaving just the steady-state
# cost of incremental stamps and the GPU upload.
#
# Why it matters: this is how Canvas is actually used. Brush strokes,
# generative drawing, particle trails, and any persistent-surface workflow
# follow this pattern: a few new draws per frame committed to a long-lived
# canvas. Regressions in the stamp path or canvas-to-GPU upload are visible here
# without the full-canvas software rasteriser drowning everything else out.

require 'ruby2d'
require 'ruby2d/benchmark'

W = 1280
H = 720
STAMPS_PER_FRAME = 50

Ruby2D::Benchmark.run('Canvas (Incremental)') do
  set title: 'Ruby 2D Benchmark — Canvas (Incremental)', width: W, height: H

  canvas = Canvas.new(width: W, height: H)
  canvas.clear

  colors = %w[red blue green yellow purple orange white aqua]

  srand(42)

  update do
    STAMPS_PER_FRAME.times do
      canvas.fill_circle(
        x: rand(W),
        y: rand(H),
        radius: rand(2..8),
        color: colors.sample
      )
    end
  end
end
