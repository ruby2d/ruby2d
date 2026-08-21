# Sixth fixture for `rake compare`: the canvas entry points. Every draw lands
# on a CPU surface through a packed payload, and on Spinel each payload crosses
# as a Float array with its length — so a miscounted stride, a dropped count,
# or an integer that should have been floated draws a plausible wrong picture
# rather than failing. One of each kind of call, including the per-vertex
# (lerp) forms and a Text blitted onto the canvas.
#
# `FRAMES` caps the run and `SHOT` writes a screenshot, so the built binary can
# be inspected without a human watching the window.

require 'ruby2d'

set title: 'Spinel canvas check', width: 320, height: 240, background: 'navy'

canvas = Canvas.new(width: 320, height: 240, fill: [0.1, 0.1, 0.15, 1.0])
canvas.fill_rectangle(x: 10, y: 10, width: 60, height: 40, color: 'lime')
canvas.fill_rectangle(x: 80, y: 10, width: 60, height: 40, color: [1.0, 0.5, 0.0, 0.6])
canvas.fill_rectangles(rectangles: [[150, 10, 20, 20], [180, 10, 20, 20]], color: 'yellow')
canvas.draw_line(x1: 10, y1: 70, x2: 310, y2: 70, stroke_width: 4, color: 'red')
canvas.draw_line(x1: 10, y1: 85, x2: 310, y2: 85, stroke_width: 3, color: ['blue', 'white'])
canvas.draw_line(x1: 10, y1: 100, x2: 310, y2: 100, stroke_width: 2, dash: 8, gap: 6, color: 'white')
canvas.fill_triangle(x1: 10, y1: 200, x2: 60, y2: 120, x3: 110, y3: 200, color: 'teal')
canvas.fill_triangle(x1: 120, y1: 200, x2: 170, y2: 120, x3: 220, y3: 200, color: ['red', 'lime', 'blue'])
canvas.fill_ellipse(x: 270, y: 160, xradius: 40, yradius: 25, color: 'purple')
canvas.stroke_rectangle(x: 230, y: 120, width: 80, height: 80, stroke_width: 3, color: 'orange')
canvas.fill_polygon(points: [[20, 230], [60, 210], [100, 230], [60, 238]], color: 'silver')
canvas.draw_polyline(points: [[120, 225], [160, 210], [200, 235], [240, 215]], stroke_width: 3, color: 'aqua')
canvas.fill_circle(x: 280, y: 225, radius: 12, color: 'fuchsia')
canvas.draw_text(Text.new('canvas', size: 20), x: 200, y: 90, color: 'white')
canvas.fill_pixel_grid(cols: 4, rows: 2, cell_w: 6, cell_h: 6, x: 250, y: 20,
                       colors: [1, 0, 0, 1, 0, 1, 0, 1, 0, 0, 1, 1, 1, 1, 0, 1,
                                0, 1, 1, 1, 1, 0, 1, 1, 1, 1, 1, 1, 0.5, 0.5, 0.5, 0.5])
canvas.clear(x: 290, y: 40, width: 20, height: 20)

frames = (ENV['FRAMES'] || '30').to_i
shot = ENV['SHOT'] || ''

n = 0
update do
  n += 1
  canvas.fill_rectangle(x: 10, y: 50, width: 130, height: 10, color: 'white') if n == 3
  Ruby2D::DSL.window.screenshot(shot) if !shot.empty? && n == frames
  close if n > frames
end

show
puts "ran #{n} frames"
