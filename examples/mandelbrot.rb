# Mandelbrot zoomer
# Click to zoom into the Mandelbrot set, rendered fresh to a Canvas.
#
# Click anywhere to zoom in 4x at the cursor; right-click to zoom out.
# Press `r` to reset to the home view. Each view is rendered in 2x2 blocks,
# one horizontal band per frame, so the window stays responsive and a progress
# bar can track the work; within a band, pixels are grouped by escape-time
# bucket so each color is drawn in a single batched call.

require 'ruby2d'

# === Tunables ===

WIDTH = 800              # window width in pixels
HEIGHT = 600             # window height in pixels
PIXEL = 2                # render block size (smaller = sharper, slower)
BAND_ROWS = 16           # block-rows rendered per frame. The set is drawn one
                         # band at a time so only a band's worth of rectangles is
                         # ever live at once — without this bound a deep zoom's
                         # arrays overflow the mruby/WebAssembly heap and abort
                         # the tab. Larger = fewer frames, more peak memory.
MAX_ITER = 80            # iterations before declaring "in the set"
ZOOM_FACTOR = 4.0        # multiplicative zoom per click
COOLDOWN_FRAMES = 15     # frames that ignore input after a render finishes, so a
                         # rapid double-click reads as one zoom, not two
HOME_X = -0.5            # home view center (real)
HOME_Y = 0.0             # home view center (imaginary)
HOME_W = 3.5             # home view width in complex-plane units

PIXELS_W = WIDTH / PIXEL
PIXELS_H = HEIGHT / PIXEL

# === Window ===

set title: 'Ruby 2D ▸ Examples ▸ Mandelbrot zoomer', width: WIDTH, height: HEIGHT
set close_on_esc: true

canvas = Canvas.new(x: 0, y: 0, width: WIDTH, height: HEIGHT, fill: [0, 0, 0, 1])
status = Text.new('', x: 8, y: HEIGHT - 22, size: 13, color: [1.0, 1.0, 1.0, 0.7], z: 10)

# === Rendering overlay ===
#
# A centered "busy" panel shown while a view streams in: a translucent black
# backdrop (so the label reads over any part of the fractal), a prominent label,
# and a progress bar that fills as bands complete. `x:/y: :center` re-resolve
# against the live viewport each frame. The bar's track and fill share a fixed
# left edge so the fill grows rightward instead of staying centered.

PANEL_W = 320
PANEL_H = 108
BAR_W = 250
BAR_H = 12
PANEL_Y = (HEIGHT - PANEL_H) / 2
BAR_X = (WIDTH - BAR_W) / 2

overlay_panel = Rectangle.new(x: :center, y: :center, width: PANEL_W, height: PANEL_H,
                              color: [0.0, 0.0, 0.0, 0.6], z: 20)
overlay_label = Text.new('Rendering…', x: :center, y: PANEL_Y + 20, size: 30,
                         color: 'white', z: 22)
progress_track = Rectangle.new(x: BAR_X, y: PANEL_Y + 72, width: BAR_W, height: BAR_H,
                               color: [1.0, 1.0, 1.0, 0.18], z: 21)
progress_fill = Rectangle.new(x: BAR_X, y: PANEL_Y + 72, width: 0, height: BAR_H,
                              color: '#fbbf24', z: 22)
overlay = [overlay_panel, progress_track, progress_fill, overlay_label]

# === Palette ===

PALETTE = Array.new(MAX_ITER + 1) do |n|
  if n >= MAX_ITER
    [0.02, 0.02, 0.04, 1]
  else
    h = (n.to_f / 32 + 0.6) % 1.0
    s = 0.7
    v = 1.0
    i = (h * 6).floor
    f = h * 6 - i
    p = v * (1 - s)
    q = v * (1 - f * s)
    tt = v * (1 - (1 - f) * s)
    rgb = case i % 6
          when 0 then [v, tt, p]
          when 1 then [q, v, p]
          when 2 then [p, v, tt]
          when 3 then [p, q, v]
          when 4 then [tt, p, v]
          else        [v, p, q]
          end
    rgb + [1.0]
  end
end

# === Rendering ===

# Render a single horizontal band, block-rows [py_start, py_end), into the
# canvas. Pixels are sorted into escape-time buckets and each non-empty bucket
# is drawn in one batched call. One band's worth of rectangles is all that is
# ever live, so peak memory stays bounded no matter how deep the zoom — the
# whole-image bucket set would otherwise overflow the mruby/web heap.
def render_band(canvas, cx, cy, vw, py_start, py_end)
  view_h = vw * HEIGHT.to_f / WIDTH
  inv_w = vw / PIXELS_W
  inv_h = view_h / PIXELS_H
  origin_x = cx - vw / 2.0
  origin_y = cy - view_h / 2.0
  buckets = Array.new(MAX_ITER + 1) { [] }
  py = py_start
  while py < py_end
    cy_p = origin_y + py * inv_h
    PIXELS_W.times do |px|
      cx_p = origin_x + px * inv_w
      zr = 0.0
      zi = 0.0
      n = 0
      while n < MAX_ITER && zr * zr + zi * zi < 4.0
        zr_new = zr * zr - zi * zi + cx_p
        zi = 2 * zr * zi + cy_p
        zr = zr_new
        n += 1
      end
      buckets[n] << [px * PIXEL, py * PIXEL, PIXEL, PIXEL]
    end
    py += 1
  end
  buckets.each_with_index do |rects, n|
    next if rects.empty?
    canvas.fill_rectangles(rectangles: rects, color: PALETTE[n])
  end
end

def update_status(status, cx, cy, vw)
  zoom = HOME_W / vw
  status.content = format('center: (%.5f, %.5f)   zoom: %.1fx', cx, cy, zoom)
end

# === State ===

center_x  = HOME_X
center_y  = HOME_Y
view_w    = HOME_W
rendering = false        # true while a view is streaming in across frames
band_py   = 0            # next block-row to render this pass
cooldown  = 0            # frames left before input is accepted again

# Begin streaming the current view. The `update` loop renders one band per
# frame from here; the overlay stays up until the last band lands.
start_render = lambda do
  rendering = true
  band_py = 0
  progress_fill.width = 0
  overlay.each { |element| element.show }
end

# Kick off the first render so the window can appear immediately and fill in,
# rather than blocking on a full render before it is even visible.
start_render.call

# === Input ===
#
# Clicks are ignored while a render is streaming or during the brief cooldown
# after one, so mashing the mouse can't queue up a stack of zooms.

on :mouse_down do |event|
  next if rendering || cooldown > 0
  view_h = view_w * HEIGHT.to_f / WIDTH
  target_x = center_x + (event.x.to_f / WIDTH - 0.5) * view_w
  target_y = center_y + (event.y.to_f / HEIGHT - 0.5) * view_h
  if event.button? :right
    view_w *= ZOOM_FACTOR
  else
    view_w /= ZOOM_FACTOR
  end
  center_x = target_x
  center_y = target_y
  start_render.call
end

on key_down: :r do
  next if rendering || cooldown > 0
  center_x = HOME_X
  center_y = HOME_Y
  view_w   = HOME_W
  start_render.call
end

# === Per-frame update ===
#
# Render the next band, advance the progress bar, and — on the final band —
# refresh the status line, drop the overlay, and start the input cooldown.

update do
  cooldown -= 1 if cooldown > 0
  next unless rendering

  band_end = [band_py + BAND_ROWS, PIXELS_H].min
  render_band(canvas, center_x, center_y, view_w, band_py, band_end)
  band_py = band_end
  progress_fill.width = (BAR_W * (band_py.to_f / PIXELS_H)).round

  if band_py >= PIXELS_H
    rendering = false
    cooldown = COOLDOWN_FRAMES
    update_status(status, center_x, center_y, view_w)
    overlay.each { |element| element.hide }
  end
end

show
