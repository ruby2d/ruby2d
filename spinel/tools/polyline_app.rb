# Compare fixture for the path stroker as `Polyline` reaches it: an open path
# with butt caps, a closed one with mitered corners, a per-vertex gradient, and
# a sharp corner that hits the miter limit. The vertex and color arrays cross
# separately with their counts, so a dropped or off-by-one count draws a
# truncated or shifted path.
#
# `FRAMES` caps the run and `SHOT` writes a screenshot, so the built binary can
# be inspected without a human watching the window.

require 'ruby2d'

set title: 'Spinel polyline check', width: 320, height: 240, background: 'navy'

Polyline.new(points: [[20, 40], [80, 20], [140, 60], [200, 20], [300, 50]], stroke_width: 6, color: 'lime')
Polyline.new(points: [[30, 100], [120, 90], [150, 140], [60, 160]], stroke_width: 5, color: 'yellow', closed: true)
Polyline.new(points: [[180, 100], [300, 100], [180, 160], [300, 160]], stroke_width: 8,
             color: ['red', 'white', 'blue', 'aqua'])
Polyline.new(points: [[20, 220], [160, 180], [24, 200]], stroke_width: 10, color: 'orange')

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
