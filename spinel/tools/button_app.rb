# Compare fixture for `Button`: a filled rectangle, its label, and the hover
# and pressed states the button repaints itself into. Buttons compose
# `Rectangle` and `Text`, so this checks the composition and the per-object
# event registration rather than a new entry point — and it is the first
# fixture whose scene exists only because an `Interactive` object was created.
#
# `FRAMES` caps the run and `SHOT` writes a screenshot, so the built binary can
# be inspected without a human watching the window.

require 'ruby2d'

set title: 'Spinel button check', width: 320, height: 240, background: 'navy'

Button.new(x: 20, y: 20, width: 130, height: 50, label: 'Play', color: 'lime', label_color: 'navy')
Button.new(x: 170, y: 20, width: 130, height: 50, label: 'Quit', color: [0.8, 0.2, 0.2, 1.0])
b = Button.new(x: 20, y: 100, width: 280, height: 60, label: 'Hover me', color: 'gray', hover_color: 'yellow')
Button.new(x: 20, y: 180, width: 280, height: 40, label: 'Outlined', color: [0, 0, 0, 0],
           stroke_width: 3, stroke_color: 'white')

frames = (ENV['FRAMES'] || '30').to_i
shot = ENV['SHOT'] || ''

n = 0
update do
  n += 1
  Ruby2D::DSL.window.mouse_callback(:move, nil, nil, 100, 130, 1, 1) if n == 2
  Ruby2D::DSL.window.screenshot(shot) if !shot.empty? && n == frames
  close if n > frames
end

show
puts "ran #{n} frames"
