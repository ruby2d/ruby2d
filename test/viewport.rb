# Viewport
#
# Press 1-6 to switch viewport modes at runtime. Resize the window to see how
# each mode behaves. Mouse coordinates are displayed to verify coordinate
# mapping works correctly in every mode.
#
# Every framing visual (borders, crosshair, corner markers, grid, help text) is
# laid out from the *current* viewport, so `:expand` — which grows the viewport
# to track the window — keeps them on the real edges, matching the readout.
#
# Keys:
#   1 = letterbox   2 = stretch    3 = integer
#   4 = overscan    5 = expand     6 = fixed

require 'ruby2d'

MODES = {
  '1' => :letterbox,
  '2' => :stretch,
  '3' => :integer,
  '4' => :overscan,
  '5' => :expand,
  '6' => :fixed
}.freeze

set title: 'Viewport Mode Test', width: 640, height: 480
set resizable: true, close_on_esc: true

BORDER = 4   # edge border thickness
MARKER = 16  # corner marker size

# Persistent framing visuals — created once, then (re)positioned by `relayout`
# from the live viewport whenever it changes.
top    = Rectangle.new(color: 'red')
bottom = Rectangle.new(color: 'green')
left   = Rectangle.new(color: 'blue')
right  = Rectangle.new(color: 'yellow')

cross_h = Line.new(stroke_width: 2, color: 'white')
cross_v = Line.new(stroke_width: 2, color: 'white')

marker_tl = Square.new(size: MARKER, color: [1.0, 0.0, 0.0, 0.7])
marker_tr = Square.new(size: MARKER, color: [0.0, 1.0, 0.0, 0.7])
marker_bl = Square.new(size: MARKER, color: [0.0, 0.0, 1.0, 0.7])
marker_br = Square.new(size: MARKER, color: [1.0, 1.0, 0.0, 0.7])

# Grid lines are rebuilt on resize because their count depends on viewport size.
grid_lines = []

# Info text
mode_label  = Text.new('Mode: letterbox', x: 20, y: 20, size: 20, color: 'white')
dims_label  = Text.new('', x: 20, y: 50, size: 16, color: [0.8, 0.8, 0.8, 1])
mouse_label = Text.new('Mouse: 0, 0', x: 20, y: 75, size: 16, color: [0.8, 0.8, 0.8, 1])
help_label  = Text.new(
  '1=letterbox  2=stretch  3=integer  4=overscan  5=expand  6=fixed',
  x: 20, size: 14, color: [0.6, 0.6, 0.6, 1]
)

# Mouse crosshair
mouse_h = Line.new(stroke_width: 1, color: [0.0, 1.0, 0.0, 0.6])
mouse_v = Line.new(stroke_width: 1, color: [0.0, 1.0, 0.0, 0.6])

# Position every framing visual for a viewport of vw x vh. Called whenever the
# viewport size changes so the borders always frame the live drawing area.
relayout = lambda do |vw, vh|
  top.x = 0;             top.y = 0;              top.width = vw;      top.height = BORDER
  bottom.x = 0;          bottom.y = vh - BORDER; bottom.width = vw;   bottom.height = BORDER
  left.x = 0;            left.y = 0;             left.width = BORDER; left.height = vh
  right.x = vw - BORDER; right.y = 0;            right.width = BORDER; right.height = vh

  cx = vw / 2
  cy = vh / 2
  cross_h.x1 = cx - 40; cross_h.y1 = cy; cross_h.x2 = cx + 40; cross_h.y2 = cy
  cross_v.x1 = cx; cross_v.y1 = cy - 40; cross_v.x2 = cx; cross_v.y2 = cy + 40

  marker_tl.x = 0;           marker_tl.y = 0
  marker_tr.x = vw - MARKER; marker_tr.y = 0
  marker_bl.x = 0;           marker_bl.y = vh - MARKER
  marker_br.x = vw - MARKER; marker_br.y = vh - MARKER

  help_label.y = vh - 30

  # Rebuild the grid for the new size. z: -1 keeps it behind the framing visuals
  # regardless of creation order.
  grid_lines.each(&:remove)
  grid_lines.clear
  80.step(vw - 1, 80) do |gx|
    grid_lines << Line.new(x1: gx, y1: 0, x2: gx, y2: vh, stroke_width: 1, z: -1, color: [0.3, 0.3, 0.3, 0.5])
  end
  80.step(vh - 1, 80) do |gy|
    grid_lines << Line.new(x1: 0, y1: gy, x2: vw, y2: gy, stroke_width: 1, z: -1, color: [0.3, 0.3, 0.3, 0.5])
  end
end

# Initial layout from the pre-show viewport (defaults to the window size).
last_vw = get(:viewport_width)
last_vh = get(:viewport_height)
relayout.call(last_vw, last_vh)

on :key_down do |event|
  mode_sym = MODES[event.key]
  if mode_sym
    set viewport: mode_sym
    mode_label.content = "Mode: #{mode_sym}"
  end
end

update do
  vw = get(:viewport_width)
  vh = get(:viewport_height)
  if vw != last_vw || vh != last_vh
    relayout.call(vw, vh)
    last_vw = vw
    last_vh = vh
  end
  dims_label.content = "Viewport: #{vw}x#{vh}"

  mx = get(:mouse_x)
  my = get(:mouse_y)
  mouse_label.content = "Mouse: #{mx}, #{my}"

  mouse_h.x1 = mx - 10
  mouse_h.y1 = my
  mouse_h.x2 = mx + 10
  mouse_h.y2 = my
  mouse_v.x1 = mx
  mouse_v.y1 = my - 10
  mouse_v.x2 = mx
  mouse_v.y2 = my + 10
end

show
