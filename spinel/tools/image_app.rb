# Tenth fixture for `rake compare`: the image entry points. `image_create`,
# `image_draw` and `image_resize` are pass-self calls on the other engines, so
# on Spinel the adapter holds a native handle per Image and copies the decoded
# size back — a wrong size draws the file stretched, which no shape fixture
# would notice. The raster and SVG decoders, tint, opacity, the two rotation
# pivots, `resize!` with a sampling mode, and a canvas blit each get a cell.
#
# The media ships with the gem; the directive bundles it next to the binary as
# `ruby2d build` does for any app, so the same source runs on both engines.
#
# `FRAMES` caps the run and `SHOT` writes a screenshot, so the built binary can
# be inspected without a human watching the window.

# ruby2d:assets assets/test_media/images

require 'ruby2d'

set title: 'Spinel image check', width: 320, height: 240, background: 'navy'

DIR = 'assets/test_media/images'

Image.new("#{DIR}/image.png", x: 10, y: 10, width: 60, height: 60)
Image.new("#{DIR}/colors.png", x: 80, y: 10, width: 50, height: 50, tint: 'red')
Image.new("#{DIR}/colors.png", x: 140, y: 10, width: 50, height: 50, opacity: 0.5)
Image.new("#{DIR}/bee.svg", x: 200, y: 10, width: 64, height: 64)

Image.new("#{DIR}/image.png", x: 40, y: 100, width: 60, height: 60, rotate: 30)
Image.new("#{DIR}/image.png", x: 140, y: 100, width: 60, height: 60, rotate: 45, rx: 140, ry: 100)

magnified = Image.new("#{DIR}/colors.png", x: 230, y: 100)
magnified.resize!(8, 8)
magnified.scale_mode = :nearest
magnified.width = 64
magnified.height = 64

canvas = Canvas.new(x: 10, y: 180, width: 300, height: 50, fill: [0.0, 0.0, 0.0, 0.0])
stamp = Image.new("#{DIR}/image.png", add: false)
canvas.draw_image(stamp, x: 5, y: 5, width: 40, height: 40)
canvas.draw_image(stamp, x: 60, y: 5, width: 80, height: 40)

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
