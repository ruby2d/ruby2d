# Pixel paint
# An interactive painting app built with Canvas, with a full tool palette.
#
# Toolbar offers color swatches, shape selectors (square, circle,
# triangle), brush sizes, an eraser, and a clear button. Click and drag
# on the canvas area to paint. Tests Canvas drawing primitives, partial
# clears, and mouse interaction.

require 'ruby2d'

# === Tunables ===

WINDOW_W  = 640              # window width in pixels
WINDOW_H  = 580              # window height in pixels
TOOLBAR_H = 90               # toolbar strip height in pixels
CANVAS_Y  = TOOLBAR_H        # derived: canvas starts below the toolbar
CANVAS_W  = WINDOW_W         # derived: canvas spans the full width
CANVAS_H  = WINDOW_H - TOOLBAR_H  # derived: canvas fills remaining height

# === Window ===

set title: 'Ruby 2D ▸ Examples ▸ Pixel paint', width: WINDOW_W, height: WINDOW_H, background: [0.1, 0.1, 0.15, 1]
set close_on_esc: true
set render_mode: :on_demand

# === Canvases ===
#
# Toolbar is drawn with its own Canvas so every icon is pixel-art consistent
# with the painting surface below it.

tb = Canvas.new(x: 0, y: 0, width: WINDOW_W, height: TOOLBAR_H, fill: [0.12, 0.12, 0.18, 1], z: 10)
tb.clear

canvas = Canvas.new(x: 0, y: CANVAS_Y, width: CANVAS_W, height: CANVAS_H, fill: [0.95, 0.93, 0.88, 1])
canvas.clear

# === State ===

COLORS = [
  [0.07, 0.07, 0.07, 1],  # black
  [1.0,  0.25, 0.2,  1],  # red
  [1.0,  0.52, 0.1,  1],  # orange
  [1.0,  0.86, 0.0,  1],  # yellow
  [0.18, 0.8,  0.25, 1],  # green
  [0.0,  0.45, 0.85, 1],  # blue
  [0.69, 0.05, 0.79, 1],  # purple
  [0.94, 0.07, 0.75, 1],  # fuchsia
  [0.95, 0.93, 0.88, 1]   # cream (canvas bg)
]
SHAPES = %i[square circle triangle]
SIZES  = [4, 10, 20, 40]

current_color_idx = 0
current_shape_idx = 0
current_size_idx  = 1
eraser_on = false
drawing = false

# === Toolbar icon drawing helpers ===
#
# All draw onto the `tb` canvas.

def px_rect(tb, x, y, w, h, color)
  tb.fill_rectangle(x: x, y: y, width: w, height: h, color: color)
end

# --- Color swatches (row 1) ---
SWATCH_X0  = 12
SWATCH_Y   = 10
SWATCH_SZ  = 26
SWATCH_GAP = 6

def draw_color_swatches(tb, selected)
  COLORS.each_with_index do |c, i|
    sx = SWATCH_X0 + i * (SWATCH_SZ + SWATCH_GAP)
    border = i == selected ? [1.0, 1.0, 1.0, 1.0] : [0.3, 0.3, 0.4, 1]
    px_rect(tb, sx - 3, SWATCH_Y - 3, SWATCH_SZ + 6, SWATCH_SZ + 6, border)
    px_rect(tb, sx, SWATCH_Y, SWATCH_SZ, SWATCH_SZ, c)
  end
end

# --- Shape icons (row 2) ---
SHAPE_X0    = 12
SHAPE_Y     = 50
SHAPE_BTN_W = 36
SHAPE_BTN_H = 30
SHAPE_GAP   = 8

def draw_shape_icons(tb, selected)
  SHAPES.each_with_index do |s, i|
    bx = SHAPE_X0 + i * (SHAPE_BTN_W + SHAPE_GAP)
    bg = i == selected ? [0.3, 0.3, 0.5, 1] : [0.18, 0.18, 0.25, 1]
    px_rect(tb, bx, SHAPE_Y, SHAPE_BTN_W, SHAPE_BTN_H, bg)

    ic = [0.8, 0.85, 0.9, 1]
    cx = bx + SHAPE_BTN_W / 2
    cy = SHAPE_Y + SHAPE_BTN_H / 2
    case s
    when :square
      px_rect(tb, cx - 8, cy - 8, 16, 16, ic)
    when :circle
      tb.fill_circle(x: cx, y: cy, radius: 10, color: ic)
    when :triangle
      tb.fill_triangle(x1: cx, y1: cy - 10, x2: cx - 10, y2: cy + 9, x3: cx + 10, y3: cy + 9, color: ic)
    end
  end
end

# --- Size icons (row 2, after shapes) ---
SIZE_X0    = 148
SIZE_Y     = 50
SIZE_BTN_W = 36
SIZE_BTN_H = 30
SIZE_GAP   = 6

def draw_size_icons(tb, selected)
  SIZES.each_with_index do |sz, i|
    bx = SIZE_X0 + i * (SIZE_BTN_W + SIZE_GAP)
    bg = i == selected ? [0.3, 0.3, 0.5, 1] : [0.18, 0.18, 0.25, 1]
    px_rect(tb, bx, SIZE_Y, SIZE_BTN_W, SIZE_BTN_H, bg)

    cx = bx + SIZE_BTN_W / 2
    cy = SIZE_Y + SIZE_BTN_H / 2
    r = [2 + sz / 5, 11].min
    tb.fill_circle(x: cx, y: cy, radius: r, color: [0.8, 0.85, 0.9, 1])
  end
end

# --- Eraser icon (row 2) ---
ERASER_X = 324
ERASER_Y = 50
ERASER_W = 40
ERASER_H = 30

def draw_eraser_icon(tb, active)
  bg = active ? [0.2, 0.75, 0.3, 1] : [0.18, 0.18, 0.25, 1]
  px_rect(tb, ERASER_X, ERASER_Y, ERASER_W, ERASER_H, bg)

  ic = active ? [1.0, 1.0, 1.0, 1.0] : [0.5, 0.5, 0.6, 1]
  # Pixel "E"
  ex = ERASER_X + 12
  ey = ERASER_Y + 5
  px_rect(tb, ex, ey, 3, 20, ic)       # vertical bar
  px_rect(tb, ex, ey, 16, 3, ic)       # top
  px_rect(tb, ex, ey + 8, 12, 3, ic)   # middle
  px_rect(tb, ex, ey + 17, 16, 3, ic)  # bottom
end

# --- Clear icon (row 2) ---
CLEAR_X = 372
CLEAR_Y = 50
CLEAR_W = 40
CLEAR_H = 30

def draw_clear_icon(tb)
  bg = [0.55, 0.12, 0.12, 1]
  px_rect(tb, CLEAR_X, CLEAR_Y, CLEAR_W, CLEAR_H, bg)

  ic = [1, 0.8, 0.8, 1]
  cx = CLEAR_X + CLEAR_W / 2
  # Lid
  px_rect(tb, cx - 10, CLEAR_Y + 4, 20, 3, ic)
  px_rect(tb, cx - 4, CLEAR_Y + 2, 8, 2, ic)
  # Body
  px_rect(tb, cx - 7, CLEAR_Y + 7, 14, 18, ic)
  # Stripes inside (dark)
  stripe = [0.55, 0.12, 0.12, 1]
  px_rect(tb, cx - 3, CLEAR_Y + 10, 2, 12, stripe)
  px_rect(tb, cx + 1, CLEAR_Y + 10, 2, 12, stripe)
end

# --- Separator line ---
def draw_separators(tb)
  px_rect(tb, 0, TOOLBAR_H - 3, WINDOW_W, 3, [0.3, 0.3, 0.4, 1])
end

# Redraw the whole toolbar
def redraw_toolbar(tb, color_idx, shape_idx, size_idx, eraser)
  tb.clear
  draw_separators(tb)
  draw_color_swatches(tb, color_idx)
  draw_shape_icons(tb, shape_idx)
  draw_size_icons(tb, size_idx)
  draw_eraser_icon(tb, eraser)
  draw_clear_icon(tb)
end

redraw_toolbar(tb, current_color_idx, current_shape_idx, current_size_idx, eraser_on)

# === Toolbar hit areas ===
#
# Transparent overlays at z:11 sit above the toolbar canvas (z:10).

COLORS.each_with_index do |_c, i|
  sx = SWATCH_X0 + i * (SWATCH_SZ + SWATCH_GAP)
  Button.new(x: sx, y: SWATCH_Y, width: SWATCH_SZ, height: SWATCH_SZ, z: 11) do
    current_color_idx = i
    eraser_on = false
    redraw_toolbar(tb, current_color_idx, current_shape_idx, current_size_idx, eraser_on)
  end
end

SHAPES.each_index do |i|
  bx = SHAPE_X0 + i * (SHAPE_BTN_W + SHAPE_GAP)
  Button.new(x: bx, y: SHAPE_Y, width: SHAPE_BTN_W, height: SHAPE_BTN_H, z: 11) do
    current_shape_idx = i
    redraw_toolbar(tb, current_color_idx, current_shape_idx, current_size_idx, eraser_on)
  end
end

SIZES.each_index do |i|
  bx = SIZE_X0 + i * (SIZE_BTN_W + SIZE_GAP)
  Button.new(x: bx, y: SIZE_Y, width: SIZE_BTN_W, height: SIZE_BTN_H, z: 11) do
    current_size_idx = i
    redraw_toolbar(tb, current_color_idx, current_shape_idx, current_size_idx, eraser_on)
  end
end

Button.new(x: ERASER_X, y: ERASER_Y, width: ERASER_W, height: ERASER_H, z: 11) do
  eraser_on = !eraser_on
  redraw_toolbar(tb, current_color_idx, current_shape_idx, current_size_idx, eraser_on)
end

CANVAS_FILL = [0.95, 0.93, 0.88, 1]

Button.new(x: CLEAR_X, y: CLEAR_Y, width: CLEAR_W, height: CLEAR_H, z: 11) do
  canvas.clear(CANVAS_FILL)
end

# === Drawing helpers ===

def stamp(canvas, shape, x, y, size, color)
  half = size / 2.0
  case shape
  when :square
    canvas.fill_square(x: x - half, y: y - half, size: size, color: color)
  when :circle
    canvas.fill_circle(x: x, y: y, radius: half, color: color)
  when :triangle
    canvas.fill_triangle(
      x1: x, y1: y - half,
      x2: x - half, y2: y + half,
      x3: x + half, y3: y + half,
      color: color
    )
  end
end

def erase(canvas, x, y, size)
  half = size / 2.0
  canvas.clear(CANVAS_FILL, x: (x - half).to_i, y: (y - half).to_i,
               width: size.to_i, height: size.to_i)
end

# Yield evenly-spaced points along the segment (x0,y0)→(x1,y1), skipping the
# start. Mouse-move deltas can be chunky, so each move stamps the whole
# segment rather than just the endpoint.
def stroke(x0, y0, x1, y1, size)
  dx = x1 - x0
  dy = y1 - y0
  step = [size / 4.0, 1.0].max
  steps = [(Math.sqrt(dx * dx + dy * dy) / step).ceil, 1].max
  steps.times do |i|
    t = (i + 1).to_f / steps
    yield(x0 + dx * t, y0 + dy * t)
  end
end

# === Events ===

last_x = nil
last_y = nil

on :mouse_down do |event|
  next unless event.button?(:left) && event.y >= CANVAS_Y

  drawing = true
  cx = event.x
  cy = event.y - CANVAS_Y
  sz = SIZES[current_size_idx]
  if eraser_on
    erase(canvas, cx, cy, sz)
  else
    stamp(canvas, SHAPES[current_shape_idx], cx, cy, sz, COLORS[current_color_idx])
  end
  last_x = cx
  last_y = cy
end

on :mouse_up do
  drawing = false
  last_x = nil
  last_y = nil
end

on :mouse_move do |event|
  next unless drawing && event.y >= CANVAS_Y

  cx = event.x
  cy = event.y - CANVAS_Y
  sz = SIZES[current_size_idx]
  stroke(last_x, last_y, cx, cy, sz) do |x, y|
    if eraser_on
      erase(canvas, x, y, sz)
    else
      stamp(canvas, SHAPES[current_shape_idx], x, y, sz, COLORS[current_color_idx])
    end
  end
  last_x = cx
  last_y = cy
end

show
