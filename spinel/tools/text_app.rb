# Fifth fixture for `rake compare`: the text entry points. `text_create` and
# `text_draw` are pass-self calls on the other engines, so on Spinel they are
# the first adapter seam that holds a native handle per object and copies a
# measured size back — a wrong width or height draws the glyphs stretched,
# which no shape fixture would notice. Bold exercises the style flags, the
# alpha the tint, the rotation the pivot, and the size change on a later frame
# the re-rasterize path.
#
# `FRAMES` caps the run and `SHOT` writes a screenshot, so the built binary can
# be inspected without a human watching the window.

require 'ruby2d'

set title: 'Spinel text check', width: 320, height: 240, background: 'navy'

Text.new('Ruby 2D', x: 20, y: 20, size: 28, color: 'lime')
Text.new('bold', x: 20, y: 70, size: 24, style: :bold, color: [1.0, 0.8, 0.2, 0.7])
Text.new('tilt', x: 180, y: 70, size: 24, rotate: 20, color: 'red')
grow = Text.new('grow', x: 20, y: 140, size: 16, color: 'white')

frames = (ENV['FRAMES'] || '30').to_i
shot = ENV['SHOT'] || ''

n = 0
update do
  n += 1
  grow.size = 36 if n == 5
  Ruby2D::DSL.window.screenshot(shot) if !shot.empty? && n == frames
  close if n > frames
end

show
puts "ran #{n} frames"
