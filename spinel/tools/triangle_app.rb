# Compare fixture for the triangle entry points: a flat fill (10 floats), a
# per-vertex fill (18), and the two stroke forms, which go through the shared
# path stroker with three vertices closed. A transposed vertex or color slot in
# any of the four draws a plausible wrong triangle no quad fixture sees.
#
# `FRAMES` caps the run and `SHOT` writes a screenshot, so the built binary can
# be inspected without a human watching the window.

require 'ruby2d'

set title: 'Spinel triangle check', width: 320, height: 240, background: 'navy'

Triangle.new(x1: 20, y1: 110, x2: 80, y2: 20, x3: 140, y3: 110, color: 'lime')
Triangle.new(x1: 180, y1: 110, x2: 240, y2: 20, x3: 300, y3: 110, color: ['red', 'lime', 'blue'])
Triangle.new(x1: 20, y1: 230, x2: 80, y2: 140, x3: 140, y3: 230, color: [0.2, 0.4, 0.9, 0.5],
             stroke_width: 5, stroke_color: 'yellow')
Triangle.new(x1: 180, y1: 230, x2: 240, y2: 140, x3: 300, y3: 230, color: 'navy',
             stroke_width: 6, stroke_color: ['white', 'red', 'aqua'])

frames = (ENV['FRAMES'] || '30').to_i
shot = ENV['SHOT'] || ''

n = 0
update do
  n += 1
  Ruby2D::DSL.window.screenshot(shot) if !shot.empty? && n == frames
  close if n > frames
end

show
puts "ran #{n} frames"
