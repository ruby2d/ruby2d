# Fourth fixture for `rake compare`: the two line entry points, which no other
# fixture reaches. `draw_line` takes 21 floats and `draw_dashed_line` 23, and a
# transposed argument in either draws a plausible wrong line that a quad or
# circle fixture never sees — so each is drawn in the shape that would expose
# it: a dashed line, where the dash and gap lengths sit between the stroke
# width and the colors; a rotated line, which exercises the Ruby-side rotation
# before the call; and a gradient, whose start and end colors land on distinct
# corners.
#
# `FRAMES` caps the run and `SHOT` writes a screenshot, so the built binary can
# be inspected without a human watching the window.

require 'ruby2d'

set title: 'Spinel line check', width: 320, height: 240, background: 'navy'

Line.new(x1: 20, y1: 30, x2: 300, y2: 30, stroke_width: 6, color: 'lime')
Line.new(x1: 20, y1: 70, x2: 300, y2: 70, stroke_width: 4, dash: 12, gap: 8, color: 'yellow')
Line.new(x1: 60, y1: 150, x2: 260, y2: 150, stroke_width: 8, rotate: 20, color: 'red')
Line.new(x1: 20, y1: 210, x2: 300, y2: 210, stroke_width: 10, color: ['blue', 'white'])

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
