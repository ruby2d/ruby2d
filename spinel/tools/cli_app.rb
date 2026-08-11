# Fixture for the `cli` check: the smallest real Ruby 2D app the Spinel target
# supports, written the way a user would write it. `ruby2d build --spinel` has
# to accept this unmodified — that is the whole point of the check.
#
# `FRAMES` caps the run and `SHOT` writes a screenshot, so the built binary can
# be inspected without a human watching the window.

require 'ruby2d'

set title: 'Spinel CLI check', width: 320, height: 240, background: 'navy'

Square.new(x: 120, y: 80, size: 80, color: 'red')

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
