# Mandelbrot zoomer
#
#   RUBY2D_SPINEL=../spinel/bin/spinel ruby2d build --spinel spinel/examples/mandelbrot.rb
#   ruby2d launch --native
#
# A port of `examples/mandelbrot.rb`. The math, the palette and the banded
# rendering are the original's; three things differ, each because of what this
# target can do today.
#
# **It zooms itself.** The original zooms where you click. Input does not work
# here, so once a view finishes it pauses, picks a block on the boundary of the
# set, and zooms there — the same thing a person clicking would look for. Past
# the depth where doubles run out of precision it returns home and starts over,
# so it runs indefinitely.
#
# **It draws into a grid of `Square`s, not a `Canvas`.** `Canvas` is not in this
# target: every one of its C entry points takes the Ruby object and reads ivars
# off it, and stores the surface pointer back inside it, so supporting it means
# splitting that layer into a Ruby-free core first. A `Square` per block needs
# none of that. The grid is built once at startup and only recolored after —
# nothing is created or removed once the window is up, which also keeps it clear
# of the `Hash#delete_if` that `remove` reaches.
#
# **There is no text.** `Text` is not in this target either, so the status line
# and the "Rendering…" label are gone and the progress bar carries the overlay
# on its own.
#
# **The frame is a blend of two very different speedups, and the tunables set
# the weights.** Escape-time arithmetic is a tight Ruby float loop, where Spinel
# runs ~25-30x faster than CRuby. Scene dispatch is a per-object cost every
# engine pays, and there Spinel is a flat ~3.2x — measured the same whether the
# scene loop merely reaches each object or draws it, so there is no part of that
# path where the gap is wider. Blend the two and you get whatever ratio their
# proportions imply.
#
# So the levers are the proportions, and they are not equally cheap:
#
# - `BAND_ROWS` is the free one. More block-rows per frame is more arithmetic
#   against an unchanged object count — it costs nothing but how fast a view
#   streams in. Raising it from 1 to 15 moves the whole example from 5.3x to
#   16.3x on a fixed view.
# - `MAX_ITER` buys colour detail with arithmetic, so it pulls the same way,
#   more slowly.
# - `PIXEL` pulls the other way: a smaller block is sharper but adds objects,
#   and objects are the 3.2x half.
#
# At the values below the example measures ~16x faster than CRuby, and holds
# 116fps against CRuby's 14.5 — while staying inside the frame budget on the
# deepest views, which is why `BAND_ROWS` stops at 4 rather than going higher.
#
# What does *not* help is micro-optimizing the escape loop. Hoisting `zr*zr`
# out of the guard, writing `2.0` instead of `2`, and lifting `MAX_ITER` into a
# local all measure within noise on both engines: `cc -O2` already eliminates
# the common subexpression, and CRuby's loop is bound by interpreter dispatch
# rather than by the multiplications. The loop below is written for clarity
# because clarity is free here.

require 'ruby2d'

# === Tunables ===

WIDTH = 800              # window width in pixels
HEIGHT = 600             # window height in pixels
PIXEL = 4                # block size (smaller = sharper, more objects)
BAND_ROWS = 4            # block-rows computed per frame
MAX_ITER = 2000          # iterations before declaring "in the set"
ZOOM_FACTOR = 4.0        # multiplicative zoom per hop
PAUSE_SECONDS = 0.5      # how long a finished view is held before zooming
MAX_ZOOM = 1.0e12        # past this, doubles run out — go home and start over
HOME_X = -0.5            # home view center (real)
HOME_Y = 0.0             # home view center (imaginary)
HOME_W = 3.5             # home view width in complex-plane units

PIXELS_W = WIDTH / PIXEL
PIXELS_H = HEIGHT / PIXEL

# The zoom target is picked from the middle of the view rather than its edge: a
# boundary block in the corner is usually a filament heading out of frame, and
# zooming there walks off the interesting part within a hop or two.
MARGIN_W = PIXELS_W / 4
MARGIN_H = PIXELS_H / 4

# === Window ===

set title: 'Ruby 2D ▸ Spinel ▸ Mandelbrot', width: WIDTH, height: HEIGHT,
    background: '#0a0a23'

# === Palette ===

PALETTE = Array.new(MAX_ITER + 1) do |n|
  if n >= MAX_ITER
    [0.02, 0.02, 0.04, 1.0]
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
    [rgb[0], rgb[1], rgb[2], 1.0]
  end
end

# === The grid ===
#
# One `Square` per block, laid out once, and the escape count for each. Only
# their contents ever change after startup — the scene's size and membership
# never do.
#
# Constants rather than locals because the methods below read them directly:
# passing them in as arguments is refused by the compiler today, with
# `unsupported closure capturing a non-integer variable`, whenever the call
# comes from inside the `update` block. See ../README.md.

GRID = []
COUNTS = []
py = 0
while py < PIXELS_H
  px = 0
  while px < PIXELS_W
    GRID << Square.new(x: px * PIXEL, y: py * PIXEL, size: PIXEL,
                       color: [0.02, 0.02, 0.04, 1.0])
    COUNTS << MAX_ITER
    px += 1
  end
  py += 1
end

# === Overlay ===
#
# A progress bar over a translucent panel, shown while a view streams in.

BAR_W = 250
BAR_H = 12
PANEL_W = 320
PANEL_H = 60
PANEL_X = (WIDTH - PANEL_W) / 2
PANEL_Y = (HEIGHT - PANEL_H) / 2
BAR_X = (WIDTH - BAR_W) / 2
BAR_Y = PANEL_Y + (PANEL_H - BAR_H) / 2

overlay_panel = Rectangle.new(x: PANEL_X, y: PANEL_Y, width: PANEL_W, height: PANEL_H,
                              color: [0.0, 0.0, 0.0, 0.6], z: 20)
progress_track = Rectangle.new(x: BAR_X, y: BAR_Y, width: BAR_W, height: BAR_H,
                               color: [1.0, 1.0, 1.0, 0.18], z: 21)
progress_fill = Rectangle.new(x: BAR_X, y: BAR_Y, width: 0, height: BAR_H,
                              color: '#fbbf24', z: 22)

# === Rendering ===

# Compute block-rows [py_start, py_end) and recolor their squares. `while`
# rather than `each` throughout: this is the hot loop, and it is the one place
# where the difference between engines is worth not giving away.
def render_band(cx, cy, vw, py_start, py_end)
  view_h = vw * HEIGHT.to_f / WIDTH
  inv_w = vw / PIXELS_W
  inv_h = view_h / PIXELS_H
  origin_x = cx - vw / 2.0
  origin_y = cy - view_h / 2.0

  py = py_start
  while py < py_end
    cy_p = origin_y + py * inv_h
    row = py * PIXELS_W
    px = 0
    while px < PIXELS_W
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
      COUNTS[row + px] = n
      GRID[row + px].color = PALETTE[n]
      px += 1
    end
    py += 1
  end
end

# === Picking where to go next ===

# A block is on the boundary if it escaped but touches one that did not. That
# is where the detail is, and it is what a person zooming would aim at.
def boundary?(px, py)
  i = py * PIXELS_W + px
  return false if COUNTS[i] >= MAX_ITER

  COUNTS[i - 1] >= MAX_ITER || COUNTS[i + 1] >= MAX_ITER ||
    COUNTS[i - PIXELS_W] >= MAX_ITER || COUNTS[i + PIXELS_W] >= MAX_ITER
end

# Collect the boundary blocks in the middle of the view and take one at random.
# Returns the block index, or -1 when the view has no boundary in it at all —
# which happens on a view that is entirely inside or entirely outside the set.
def pick_target
  found = []
  py = MARGIN_H
  while py < PIXELS_H - MARGIN_H
    px = MARGIN_W
    while px < PIXELS_W - MARGIN_W
      found << (py * PIXELS_W + px) if boundary?(px, py)
      px += 1
    end
    py += 1
  end

  return -1 if found.empty?

  found[rand(found.size)]
end

# === State ===

center_x = HOME_X
center_y = HOME_Y
view_w = HOME_W
rendering = true         # true while a view is streaming in across frames
band_py = 0              # next block-row to compute this pass
idle = 0.0               # seconds a finished view has been held

# === Per-frame update ===

update do |dt|
  # Read the frame delta into a local before use: a nested block that reads the
  # update block's own parameter makes Spinel infer it as `Integer`, and every
  # delta then truncates to zero. See ../README.md.
  step = dt

  if rendering
    band_end = band_py + BAND_ROWS
    band_end = PIXELS_H if band_end > PIXELS_H
    render_band(center_x, center_y, view_w, band_py, band_end)
    band_py = band_end
    progress_fill.width = (BAR_W * band_py) / PIXELS_H

    if band_py >= PIXELS_H
      rendering = false
      idle = 0.0
      overlay_panel.hide
      progress_track.hide
      progress_fill.hide
    end
  else
    idle = idle + step
    if idle >= PAUSE_SECONDS
      target = pick_target
      zoom = HOME_W / view_w

      if target < 0 || zoom > MAX_ZOOM
        center_x = HOME_X
        center_y = HOME_Y
        view_w = HOME_W
      else
        view_h = view_w * HEIGHT.to_f / WIDTH
        tx = target % PIXELS_W
        ty = target / PIXELS_W
        center_x = center_x + (tx.to_f / PIXELS_W - 0.5) * view_w
        center_y = center_y + (ty.to_f / PIXELS_H - 0.5) * view_h
        view_w = view_w / ZOOM_FACTOR
      end

      rendering = true
      band_py = 0
      progress_fill.width = 0
      overlay_panel.show
      progress_track.show
      progress_fill.show
    end
  end
end

show
