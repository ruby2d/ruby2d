# Pixel Scale
#
# With `pixel_scale: true` and `highdpi: true`, the drawable coordinate space
# maps 1:1 with physical pixels. On a 2x Retina display, a 640x480 window
# exposes a 1280x960 coordinate space where each unit is one physical pixel.
#
# Key APIs:
#   Window.width / Window.height                   - OS window size in logical pixels (640x480)
#   Window.viewport_width / viewport_height        - drawable pixel space (1280x960 on 2x display);
#                                                    use these to size objects that fill the window,
#                                                    e.g. a Canvas — only available after `show` starts
#   Window.display_width / display_height          - display size in logical pixels; pass to `set`
#   Window.display_pixel_width / display_pixel_height - display size in physical pixels; use for
#                                                    querying raw pixel counts, not for `set`

require 'ruby2d'

set title: 'Ruby 2D — Pixel Scale', width: 640, height: 480,
    highdpi: true, pixel_scale: true
set close_on_esc: true

# Display window, viewport, and display dimensions
window_label = Text.new(
  "Window: #{Window.width}x#{Window.height}",
  x: 50, y: 10, size: 14
)

viewport_label = Text.new(
  "Viewport: #{Window.viewport_width}x#{Window.viewport_height}",
  x: 50, y: 30, size: 14, color: 'lime'
)

display_label = Text.new(
  "Display: #{Window.display_width}x#{Window.display_height} logical  |  #{Window.display_pixel_width}x#{Window.display_pixel_height} physical",
  x: 50, y: 50, size: 14, color: 'aqua'
)

mouse_label = Text.new(
  'Mouse: 0, 0',
  x: 50, y: 70, size: 14
)

# Draw a grid of 1x1 squares to verify single-pixel addressing.
# Each square should fill exactly one physical pixel.
10.times do |i|
  10.times do |j|
    next if (i + j).even?
    Square.new(x: 50 + i, y: 110 + j, size: 1, color: 'white')
  end
end

# Checkerboard label
Text.new('1px checkerboard', x: 50, y: 125, size: 12)

# A small 10x10 square for visual reference
Square.new(x: 50, y: 150, size: 10, color: 'red')
Text.new('10x10', x: 65, y: 150, size: 12)

# A larger reference square
Square.new(x: 50, y: 180, size: 50, color: 'green')
Text.new('50x50', x: 105, y: 180, size: 12)

# Canvas pixel alignment: Canvas#draw_line and Canvas#fill_rectangle must
# share pixel edges for non-integer coordinates. In each row below, the
# white 1px line should sit flush against the red rectangle — left and
# right edges aligned, no 1-pixel shift on either side. `pixel_scale`
# amplifies any mismatch since logical coordinates map to physical pixels.
Text.new('canvas fill_rectangle / draw_line alignment', x: 50, y: 240, size: 12)

alignment_canvas = Canvas.new(x: 50, y: 260, width: 400, height: 330, fill: 'black')

[
  [10.0,  10,  200.0],
  [10.5,  70,  200.0],
  [10.25, 130, 200.0],
  [10.75, 190, 200.0],
  [10.5,  250, 100.0]
].each do |x, y, w|
  alignment_canvas.fill_rectangle(x: x, y: y, width: w, height: 20, color: 'red')
  alignment_canvas.draw_line(x1: x, y1: y + 20, x2: x + w, y2: y + 20, color: 'white')
end

# Crosshair at the center of the drawable pixel space.
# viewport_width/viewport_height are only scaled after `show` starts, so we
# create the crosshair on the first frame of the update loop.
crosshair_h = crosshair_v = center_label = nil

update do
  window_label.content = "Window: #{Window.width}x#{Window.height}"
  viewport_label.content = "Viewport: #{Window.viewport_width}x#{Window.viewport_height}"
  display_label.content = "Display: #{Window.display_width}x#{Window.display_height} logical  |  #{Window.display_pixel_width}x#{Window.display_pixel_height} physical"
  mouse_label.content = "Mouse: #{Window.mouse_x}, #{Window.mouse_y}"

  if crosshair_h.nil?
    vw = Window.viewport_width
    vh = Window.viewport_height

    cx = vw / 2
    cy = vh / 2
    crosshair_h = Line.new(x1: cx - 20, y1: cy, x2: cx + 20, y2: cy, stroke_width: 1, color: 'yellow')
    crosshair_v = Line.new(x1: cx, y1: cy - 20, x2: cx, y2: cy + 20, stroke_width: 1, color: 'yellow')
    center_label = Text.new("center: #{cx}, #{cy}", x: cx + 25, y: cy - 8, size: 12, color: 'yellow')

    # Corner squares to verify all four edges are visible
    Square.new(x: 0,       y: 0,       size: 20, color: 'red')
    Square.new(x: vw - 20, y: 0,       size: 20, color: 'green')
    Square.new(x: 0,       y: vh - 20, size: 20, color: 'blue')
    Square.new(x: vw - 20, y: vh - 20, size: 20, color: 'yellow')
  end
end

show
