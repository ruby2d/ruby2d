# Eleventh fixture for `rake compare`: the ellipse entry points. `draw_ellipse`
# and `stroke_ellipse` take two radii and a tilt in radians between the center
# and the sector count, so a transposed argument draws a plausible shape the
# circle fixture never sees. The tilted one exercises the rotation math in
# `ellipse.rb` (the rim tilts and the center orbits the pivot) on both engines,
# and the stroke-only one the `fill: false` branch.
#
# `FRAMES` caps the run and `SHOT` writes a screenshot, so the built binary can
# be inspected without a human watching the window.

require 'ruby2d'

set title: 'Spinel ellipse check', width: 320, height: 240, background: 'navy'

Ellipse.new(x: 90, y: 70, xradius: 70, yradius: 40, sectors: 24,
            color: [0.9, 0.5, 0.2, 0.85], stroke_width: 5, stroke_color: 'aqua')
Ellipse.new(x: 230, y: 80, xradius: 60, yradius: 25, rotate: 30, color: 'lime')
Ellipse.new(x: 120, y: 170, xradius: 50, yradius: 50, rotate: 45, rx: 160, ry: 170,
            color: 'fuchsia', opacity: 0.6)
Ellipse.new(x: 250, y: 180, xradius: 40, yradius: 30, fill: false,
            stroke_width: 3, stroke_color: 'yellow')

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
