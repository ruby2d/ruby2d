# Benchmark — Canvas drawing
#
# Draws a dense grid of filled shapes onto a Canvas every frame using a mix
# of primitives (rectangles, triangles, circles). Clears and redraws the
# entire canvas each frame to stress the software-rendering pipeline.
#
# Why it matters: Canvas is the only fully software-rendered path in the
# gem — everything else goes to the GPU. It's the right tool for pixel-
# perfect generative work, paint apps, and anything that needs per-pixel
# CPU control. Performance here is bound by CPU fill rate and the per-
# primitive software rasteriser, an entirely different cost surface from
# GPU paths.
#
# Note: this is a stress workload (full clear + repaint every frame). See
# canvas_incremental.rb for the common-case counterpart, which mirrors the
# brush-stamp pattern of a persistent-surface drawing workflow.

require 'ruby2d'
require 'ruby2d/benchmark'

COLS = 80  # 1280 / 16
ROWS = 45  # 720 / 16

Ruby2D::Benchmark.run('Canvas') do
  set title: 'Ruby 2D Benchmark — Canvas', width: 1280, height: 720

  colors = %w[red blue green yellow purple orange white aqua]
  canvas = Canvas.new(width: 1280, height: 720)

  render do
    canvas.clear

    COLS.times do |i|
      ROWS.times do |j|
        c = colors[(i + j) % colors.length]
        x = i * 16
        y = j * 16

        case (i + j) % 3
        when 0
          canvas.fill_rectangle(x: x, y: y, width: 16, height: 16, color: c)
        when 1
          canvas.fill_triangle(
            x1: x, y1: y + 16,
            x2: x + 8, y2: y,
            x3: x + 16, y3: y + 16,
            color: c
          )
        when 2
          canvas.fill_circle(x: x + 8, y: y + 8, radius: 8, color: c)
        end
      end
    end
  end
end
