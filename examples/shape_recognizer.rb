# Shape recognizer
# A two-layer neural net learns triangles, circles, and squares on a 16×16 grid.
#
# On startup it trains on a stream of procedurally generated shapes
# (random sizes, rotations, brush widths, and small position jitter);
# the left grid shows each training shape as the network sees it, and a
# yellow box marks its true class on the right — so you can watch the
# receptive fields resolve and the predictions catch up to ground truth
# in real time. After training, draw with the mouse on the left grid:
# the middle panel shows the network in action (each hidden unit is
# rendered as its 16×16 receptive field, lines pulse with activations
# and weights), and the right panel shows the predicted class with a
# confidence bar. Press `c` to clear the grid; `r` to retrain from
# scratch.
#
# A note on what makes this work: an MLP can't learn translation
# invariance from raw pixels (that's CNNs' job), so training shapes are
# centered with small jitter and the user's drawing is auto-centered (by
# centroid) before the network sees it. With that, ~99% accuracy on
# centered shapes; ~85% if you draw way off-center and rely on the
# centroid shift.

require 'ruby2d'

# === Tunables ===

WIDTH = 1200             # window width in pixels
HEIGHT = 600             # window height in pixels

GRID = 16                # input is GRID × GRID = 256 cells
INPUT_DIM = GRID * GRID
GRID_CENTER = (GRID - 1) / 2.0  # 7.5
HIDDEN = 16              # hidden-layer width
NUM_CLASSES = 3
CLASSES = %w[triangle circle square].freeze
CLASS_COLORS = %w[#fb923c #38bdf8 #a3e635].freeze  # orange / cyan / lime

# Training (online: a fresh example is generated each step, so the network
# can't memorize a fixed set — it has to learn shape-ness)
TRAIN_TOTAL_STEPS = 18_000
LEARNING_RATE = 0.06
TRAIN_PER_FRAME = 70
POSITION_JITTER = 1.5    # training-shape position offset from center, in cells
TRAIN_BRUSHES = [0.7, 0.8, 0.9, 1.0].freeze  # brackets USER_BRUSH so it's mid-distribution, not at the upper edge
USER_BRUSH = 0.9         # brush radius the user paints with

# Pacing for the two training visuals, in updates per second. Training
# itself runs at TRAIN_PER_FRAME each frame regardless; these only set how
# fast the visualization reads, and being wall-clock rates they read the
# same whether the build does 15 fps or 150. The thumbnails are the
# expensive panel — a repaint touches all 16 receptive fields — so they
# advance more slowly than the shape slideshow, which costs nothing.
SHAPE_UPDATES_PER_SEC = 8   # training shapes shown per second
RF_UPDATES_PER_SEC = 3      # receptive-field repaints per second

# Drawing area (left panel)
DRAW_X = 40
DRAW_Y = 110
DRAW_CELL = 18
DRAW_W = GRID * DRAW_CELL
DRAW_RIGHT = DRAW_X + DRAW_W

# Network panel — hidden units rendered as 16×16 receptive-field thumbnails.
# HIDDEN_TOP/BOTTOM sit far enough apart that HIDDEN_SPACING (= 34 here)
# is strictly greater than RF_SIZE (= 32), so adjacent thumbnails clear
# each other with a 2 px gutter — leaving room for the active-unit stroke.
RF_X = 470
RF_CELL = 2
RF_SIZE = GRID * RF_CELL
HIDDEN_TOP = 60          # center y of the topmost thumbnail
HIDDEN_BOTTOM = 570      # center y of the bottommost thumbnail
HIDDEN_SPACING = (HIDDEN_BOTTOM - HIDDEN_TOP).to_f / (HIDDEN - 1)

# Output panel — class icons sized to roughly the same 48 px bbox: a
# 24-radius circle is the baseline; the square matches at side 48; the
# triangle gets a larger circumradius (pointy shapes look smaller for
# the same enclosing radius) and is shifted down by TRI_OFFSET so its
# bounding box (rather than its centroid) sits on cy — otherwise it
# reads as floating high relative to the bar centerline.
OUT_X = 880
OUT_Y = [150, 300, 450].freeze
OUT_RADIUS = 24                 # circle radius
TRI_RADIUS = 30                 # triangle circumradius
TRI_OFFSET = TRI_RADIUS / 4.0   # shift to bbox-center the triangle on cy
SQUARE_SIDE = 48                # square side
ICON_HALF = 26                  # max half-extent across icons (drives line endpoints + highlight)
BAR_X = 920
BAR_W = 240
BAR_H = 18
TARGET_PAD = 6           # padding around the target-class highlight box

# Loss sparkline (under the drawing area, fills left-to-right as training progresses)
SPARKLINE_X = DRAW_X
SPARKLINE_Y = DRAW_Y + DRAW_W + 60
SPARKLINE_W = DRAW_W
SPARKLINE_H = 70
SPARKLINE_HISTORY = 200                                       # number of samples to plot
SPARKLINE_SAMPLE_EVERY = TRAIN_TOTAL_STEPS / SPARKLINE_HISTORY # one sample every ~90 steps

# Smoothing factor for the prediction bars/icons. Each frame the displayed
# softmax moves SMOOTH_RATE of the way toward the raw network output, so
# rapid training-shape switching doesn't read as flicker on the right panel.
SMOOTH_RATE = 0.25

IDLE_PULSE_RATE = 1.5    # rad/s — input lines breathe at ~4 s/cycle while idle

# When true, post-training overlays the user's ink centroid (yellow dot)
# and the grid center (faint cross) on the drawing area, making the
# auto-centering shift visible. Off by default — useful but noisy.
SHOW_CENTROID_HINT = false

# === Window ===

set title: 'Ruby 2D ▸ Examples ▸ Shape recognizer', width: WIDTH, height: HEIGHT
set close_on_esc: true
set background: '#0b1220'

canvas = Canvas.new(x: 0, y: 0, width: WIDTH, height: HEIGHT, fill: [0, 0, 0, 0])

# The receptive-field thumbnails get their own canvas, below the main one.
# They only change as W1 moves, so they repaint at RF_UPDATES_PER_SEC
# while training and once when it finishes — not every frame. Their own
# layer is what makes that possible: the main canvas is cleared and
# repainted each frame for the drawing grid and the active-unit outlines
# that sit on top of these thumbnails, and a shared canvas would take the
# thumbnails with it.
rf_canvas = Canvas.new(x: RF_X, y: 0, width: RF_SIZE, height: HEIGHT,
                       fill: [0, 0, 0, 0], z: -1)

# === Palettes ===

GRAY_PAL = Array.new(32) do |i|
  t = i / 31.0
  [0.05 + t * 0.93, 0.07 + t * 0.88, 0.12 + t * 0.83, 1.0]
end

# Diverging palette: blue (negative weights) → near-black (zero) → orange (positive)
DIVERGING_PAL = Array.new(32) do |i|
  t = (i - 15.5) / 15.5  # roughly -1..1
  if t.negative?
    a = -t
    [0.05 + a * 0.05, 0.10 + a * 0.30, 0.18 + a * 0.55, 1.0]
  else
    [0.18 + t * 0.65, 0.12 + t * 0.30, 0.06 + t * 0.04, 1.0]
  end
end

# Every canvas cell the panels paint sits at a fixed position — only which
# color bucket it lands in changes from frame to frame. Building the
# rectangles once and re-bucketing references costs no allocation, where
# rebuilding them inline allocated ~4,400 arrays every frame.
DRAW_RECTS = Array.new(GRID * GRID) do |n|
  [DRAW_X + (n % GRID) * DRAW_CELL, DRAW_Y + (n / GRID) * DRAW_CELL,
   DRAW_CELL, DRAW_CELL]
end
RF_RECTS = Array.new(HIDDEN) do |i|
  ty = (HIDDEN_TOP + i * HIDDEN_SPACING - RF_SIZE / 2.0).round
  # x is relative to `rf_canvas`, which starts at RF_X; y is absolute
  # because that canvas spans the full window height.
  Array.new(GRID * GRID) do |n|
    [(n % GRID) * RF_CELL, ty + (n / GRID) * RF_CELL, RF_CELL, RF_CELL]
  end
end
draw_buckets = Array.new(GRAY_PAL.size) { [] }
thumb_buckets = Array.new(DIVERGING_PAL.size) { [] }

CLASS_RGB = CLASS_COLORS.map do |hex|
  [hex[1..2].to_i(16) / 255.0, hex[3..4].to_i(16) / 255.0, hex[5..6].to_i(16) / 255.0]
end
DIM_RGB = [0.12, 0.16, 0.22].freeze

# === Network ===

def rand_normal(stddev)
  u = rand
  u = 1e-9 if u.zero?
  Math.sqrt(-2 * Math.log(u)) * Math.cos(2 * Math::PI * rand) * stddev
end

def fresh_weights
  he1 = Math.sqrt(2.0 / INPUT_DIM)
  he2 = Math.sqrt(2.0 / HIDDEN)
  [
    Array.new(HIDDEN * INPUT_DIM) { rand_normal(he1) },
    Array.new(HIDDEN, 0.0),
    Array.new(NUM_CLASSES * HIDDEN) { rand_normal(he2) },
    Array.new(NUM_CLASSES, 0.0)
  ]
end

# Forward pass with sparse input — `non_zero` is the list of pixel indices
# above threshold. Drawings are mostly empty cells, so skipping zeros makes
# both training and per-frame inference much faster.
def forward(x, non_zero, w1, b1, w2, b2)
  h = Array.new(HIDDEN)
  # The two `non_zero` sweeps — here and in `train_step` — are the hottest
  # loops in the file: HIDDEN passes over every inked pixel, twice per
  # training step. A block per element would cost more than the multiply
  # and add inside it, so these two spell out the loop.
  nz = non_zero.length
  HIDDEN.times do |i|
    s = b1[i]
    base = i * INPUT_DIM
    t = 0
    while t < nz
      j = non_zero[t]
      s += w1[base + j] * x[j]
      t += 1
    end
    h[i] = s.positive? ? s : 0.0
  end
  z = Array.new(NUM_CLASSES)
  NUM_CLASSES.times do |k|
    s = b2[k]
    base = k * HIDDEN
    HIDDEN.times { |j| s += w2[base + j] * h[j] }
    z[k] = s
  end
  m = z.max
  ez = z.map { |v| Math.exp(v - m) }
  sum = ez.sum
  [h, ez.map { |v| v / sum }]
end

# One SGD step with cross-entropy loss on a softmax output. Returns the loss.
def train_step(x, non_zero, target, w1, b1, w2, b2, lr)
  h, y = forward(x, non_zero, w1, b1, w2, b2)

  dz2 = y.dup
  dz2[target] -= 1.0

  dh = Array.new(HIDDEN, 0.0)
  HIDDEN.times do |j|
    next if h[j].zero?  # ReLU gate: gradient is zero where the unit was inactive
    s = 0.0
    NUM_CLASSES.times { |k| s += w2[k * HIDDEN + j] * dz2[k] }
    dh[j] = s
  end

  NUM_CLASSES.times do |k|
    base = k * HIDDEN
    g = lr * dz2[k]
    HIDDEN.times { |j| w2[base + j] -= g * h[j] }
    b2[k] -= g
  end
  nz = non_zero.length
  HIDDEN.times do |i|
    g = dh[i]
    next if g.zero?
    base = i * INPUT_DIM
    lg = lr * g
    t = 0
    while t < nz
      j = non_zero[t]
      w1[base + j] -= lg * x[j]
      t += 1
    end
    b1[i] -= lg
  end

  -Math.log(y[target] + 1e-9)
end

# === Shape rasterization ===

def stamp(grid, fx, fy, br)
  x0 = (fx - br).floor
  x1 = (fx + br).ceil
  y0 = (fy - br).floor
  y1 = (fy + br).ceil
  # `while`, not ranges: a training example stamps ~140 times, and each
  # `(a..b).each` pair allocated a Range per row. Comparing squared
  # distances also keeps the square root off the rejected cells.
  br2 = br * br
  y = y0
  while y <= y1
    if y >= 0 && y < GRID
      dy = y - fy
      dy2 = dy * dy
      row = y * GRID
      x = x0
      while x <= x1
        if x >= 0 && x < GRID
          dx = x - fx
          d2 = dx * dx + dy2
          if d2 <= br2
            v = 1.0 - Math.sqrt(d2) / br
            idx = row + x
            grid[idx] += (1.0 - grid[idx]) * v
          end
        end
        x += 1
      end
    end
    y += 1
  end
end

def stroke(grid, x0, y0, x1, y1, br)
  # Space the stamps at half the brush radius: close enough that the disks
  # always overlap, and no closer. A fixed rate independent of `br` either
  # leaves gaps for a wide brush or (as a flat 4x per cell did here)
  # stamps four times over the same ground for a narrow one.
  steps = (Math.sqrt((x1 - x0)**2 + (y1 - y0)**2) / (br * 0.5)).ceil
  steps = 1 if steps < 1
  (steps + 1).times do |i|
    t = i.to_f / steps
    stamp(grid, x0 + (x1 - x0) * t, y0 + (y1 - y0) * t, br)
  end
end

def jitter
  GRID_CENTER + (rand - 0.5) * POSITION_JITTER * 2
end

# Hand-drawn shapes are rarely closed cleanly — the most common artifact
# is a small gap where the user starts and ends the stroke (especially on
# circles). Each generator occasionally drops a piece of its outline so
# the network sees "almost-closed" shapes during training and doesn't
# treat a closed boundary as a hard requirement. Triangles and squares
# get a small gap probability too, otherwise the network would learn
# "has a gap" ≈ "is a circle" and start mis-classifying open polygons.

def gen_triangle(grid, br)
  cx = jitter; cy = jitter
  r = 4.5 + rand * 2.5
  rot = rand * 2 * Math::PI
  pts = 3.times.map do |i|
    a = rot + i * 2 * Math::PI / 3
    [cx + Math.cos(a) * r, cy + Math.sin(a) * r]
  end
  skip_last = rand < 0.15
  3.times do |i|
    next if skip_last && i == 2
    x0, y0 = pts[i]; x1, y1 = pts[(i + 1) % 3]
    stroke(grid, x0, y0, x1, y1, br)
  end
end

def gen_circle(grid, br)
  cx = jitter; cy = jitter
  r = 3.5 + rand * 3.0
  segs = 32
  gap_start = rand < 0.50 ? rand(segs) : -1
  gap_len = gap_start >= 0 ? 1 + rand(3) : 0
  segs.times do |i|
    next if gap_len > 0 && (((i - gap_start) % segs) < gap_len)
    a0 = i * 2 * Math::PI / segs
    a1 = (i + 1) * 2 * Math::PI / segs
    stroke(grid, cx + Math.cos(a0) * r, cy + Math.sin(a0) * r,
                 cx + Math.cos(a1) * r, cy + Math.sin(a1) * r, br)
  end
end

def gen_square(grid, br)
  cx = jitter; cy = jitter
  half = 3.5 + rand * 2.5
  rot = rand * Math::PI / 2  # square has 4-fold rotational symmetry
  c = Math.cos(rot); s = Math.sin(rot)
  pts = [[-half, -half], [half, -half], [half, half], [-half, half]].map do |x, y|
    [cx + x * c - y * s, cy + x * s + y * c]
  end
  skip_last = rand < 0.10
  4.times do |i|
    next if skip_last && i == 3
    x0, y0 = pts[i]; x1, y1 = pts[(i + 1) % 4]
    stroke(grid, x0, y0, x1, y1, br)
  end
end

GENERATORS = [method(:gen_triangle), method(:gen_circle), method(:gen_square)].freeze

def make_example(k)
  grid = Array.new(INPUT_DIM, 0.0)
  GENERATORS[k].call(grid, TRAIN_BRUSHES.sample)
  non_zero = []
  j = 0
  while j < INPUT_DIM
    non_zero << j if grid[j] > 0.001
    j += 1
  end
  [grid, non_zero, k]
end

# Ink-weighted centroid of a 16×16 grid in cell coordinates, or nil if
# the grid is essentially empty.
def grid_centroid(grid)
  total = 0.0; cx = 0.0; cy = 0.0
  GRID.times do |r|
    GRID.times do |c|
      v = grid[r * GRID + c]
      next if v < 0.001
      total += v; cx += c * v; cy += r * v
    end
  end
  return nil if total < 1e-6
  [cx / total, cy / total]
end

# Shift a 16×16 grid so its ink centroid lands at the grid center. The MLP
# can't learn translation invariance from raw pixels — auto-centering at
# inference time is what lets a user draw anywhere on the grid and still
# get a good prediction.
def centered_input(grid)
  c = grid_centroid(grid)
  return grid if c.nil?
  cx, cy = c
  dx = (GRID_CENTER - cx).round
  dy = (GRID_CENTER - cy).round
  return grid if dx.zero? && dy.zero?

  out = Array.new(INPUT_DIM, 0.0)
  GRID.times do |r|
    nr = r + dy
    next if nr.negative? || nr >= GRID
    GRID.times do |c|
      nc = c + dx
      next if nc.negative? || nc >= GRID
      out[nr * GRID + nc] = grid[r * GRID + c]
    end
  end
  out
end

# === Mutable state ===

w1, b1, w2, b2 = fresh_weights
state = { steps: 0, loss: 0.0, done: false }

user_grid = Array.new(INPUT_DIM, 0.0)
last_mouse = nil
mouse_held = false

current_h = Array.new(HIDDEN, 0.0)
current_y = Array.new(NUM_CLASSES, 1.0 / NUM_CLASSES)
display_y = Array.new(NUM_CLASSES, 1.0 / NUM_CLASSES)  # smoothed softmax for the bars/icons

# Most recently captured training example — what the drawing panel
# shows and what the prediction bars are computed from while training.
display_grid = Array.new(INPUT_DIM, 0.0)
display_nz = []
display_class = nil
rf_dirty = true      # receptive-field thumbnails need repainting
shape_accum = 0.0    # fractional progress toward the next shape swap
rf_accum = 0.0       # fractional progress toward the next thumbnail repaint

loss_history = []  # appended every SPARKLINE_SAMPLE_EVERY training steps
elapsed = 0.0      # seconds since show, drives the idle pulse

# === Persistent renderables ===

header_text = Text.new('Training…', x: DRAW_X, y: 70, size: 16, color: '#cbd5e1')
network_label = Text.new('Network', y: 20, size: 16, color: '#cbd5e1')
network_label.x = RF_X + RF_SIZE / 2 - network_label.width / 2
prediction_label = Text.new('Prediction', y: 70, size: 16, color: '#cbd5e1')
prediction_label.x = OUT_X - prediction_label.width / 2
hint = Text.new('R retrain',
                x: DRAW_X, y: DRAW_Y + DRAW_W + 10, size: 12, color: '#64748b')

# Drawing-area frame
[
  [DRAW_X - 1, DRAW_Y - 1, DRAW_RIGHT + 1, DRAW_Y - 1],
  [DRAW_X - 1, DRAW_Y + DRAW_W + 1, DRAW_RIGHT + 1, DRAW_Y + DRAW_W + 1],
  [DRAW_X - 1, DRAW_Y - 1, DRAW_X - 1, DRAW_Y + DRAW_W + 1],
  [DRAW_RIGHT + 1, DRAW_Y - 1, DRAW_RIGHT + 1, DRAW_Y + DRAW_W + 1]
].each do |x1, y1, x2, y2|
  Line.new(x1: x1, y1: y1, x2: x2, y2: y2, stroke_width: 1, color: '#1e293b')
end

# Loss-sparkline frame and label
Text.new('Loss', x: SPARKLINE_X, y: SPARKLINE_Y - 22, size: 12, color: '#94a3b8')
[
  [SPARKLINE_X - 1, SPARKLINE_Y - 1,
   SPARKLINE_X + SPARKLINE_W + 1, SPARKLINE_Y - 1],
  [SPARKLINE_X - 1, SPARKLINE_Y + SPARKLINE_H + 1,
   SPARKLINE_X + SPARKLINE_W + 1, SPARKLINE_Y + SPARKLINE_H + 1],
  [SPARKLINE_X - 1, SPARKLINE_Y - 1,
   SPARKLINE_X - 1, SPARKLINE_Y + SPARKLINE_H + 1],
  [SPARKLINE_X + SPARKLINE_W + 1, SPARKLINE_Y - 1,
   SPARKLINE_X + SPARKLINE_W + 1, SPARKLINE_Y + SPARKLINE_H + 1]
].each do |x1, y1, x2, y2|
  Line.new(x1: x1, y1: y1, x2: x2, y2: y2, stroke_width: 1, color: '#1e293b')
end

# Input → hidden: a visual abstraction. Each input pixel actually connects
# to every hidden unit (256 × 16 = 4096 connections), which would be
# unreadable on screen. Instead we draw one summary line per hidden unit;
# its thickness/opacity track that unit's post-ReLU activation each frame
# — i.e. how strongly the unit's receptive-field pattern matches what's
# on the grid.
input_lines = HIDDEN.times.map do |i|
  src_y = DRAW_Y + (i + 0.5) * DRAW_W / HIDDEN.to_f
  dst_y = HIDDEN_TOP + i * HIDDEN_SPACING
  Line.new(x1: DRAW_RIGHT + 6, y1: src_y, x2: RF_X - 6, y2: dst_y,
           stroke_width: 1, color: [0.55, 0.7, 0.95, 0.20])
end

# Hidden → output: every connection is drawn (HIDDEN × NUM_CLASSES = 48).
# Orange = positive weight — when this hidden unit fires, it pushes this
# class up. Blue = negative weight — firing pushes the class down.
# Thickness/opacity scale with |w · h|, the connection's actual
# contribution this frame, so you can see which paths are driving the
# current prediction rather than just which weights happen to be large.
output_lines = []
NUM_CLASSES.times do |k|
  HIDDEN.times do |i|
    src_y = HIDDEN_TOP + i * HIDDEN_SPACING
    output_lines << Line.new(x1: RF_X + RF_SIZE + 6, y1: src_y,
                             x2: OUT_X - ICON_HALF - 4, y2: OUT_Y[k],
                             stroke_width: 1, color: [0.6, 0.7, 0.85, 0.20])
  end
end

# Output: bar background, colored fill, big class circle, label
NUM_CLASSES.times do |k|
  Rectangle.new(x: BAR_X, y: OUT_Y[k] - BAR_H / 2,
                width: BAR_W, height: BAR_H, color: '#1e293b')
end
out_bars = NUM_CLASSES.times.map do |k|
  Rectangle.new(x: BAR_X, y: OUT_Y[k] - BAR_H / 2,
                width: 0, height: BAR_H, color: CLASS_COLORS[k])
end
# One icon per class. Sized for visual balance — the triangle gets a
# larger circumradius than the circle/square's enclosing radius so it
# carries similar visual weight, and is shifted down by TRI_OFFSET so
# its bounding box (not its centroid, which sits 1/4 R above the base)
# centers on cy and lines up with the rest.
out_icons = NUM_CLASSES.times.map do |k|
  cx = OUT_X
  cy = OUT_Y[k]
  dim = DIM_RGB + [1.0]
  case k
  when 0  # triangle, point up, equilateral, bbox-centered at (cx, cy)
    s60 = Math.sin(Math::PI / 3)
    Triangle.new(x1: cx,                  y1: cy - TRI_RADIUS + TRI_OFFSET,
                 x2: cx - TRI_RADIUS * s60, y2: cy + TRI_RADIUS / 2.0 + TRI_OFFSET,
                 x3: cx + TRI_RADIUS * s60, y3: cy + TRI_RADIUS / 2.0 + TRI_OFFSET,
                 color: dim)
  when 1
    Circle.new(x: cx, y: cy, radius: OUT_RADIUS, color: dim, sectors: 32)
  when 2
    Square.new(x: cx - SQUARE_SIDE / 2, y: cy - SQUARE_SIDE / 2,
               size: SQUARE_SIDE, color: dim)
  end
end

result_text = Text.new('—', y: 510, size: 30, color: '#cbd5e1', visible: false)
status = Text.new('Training…', x: DRAW_X, y: HEIGHT - 28, size: 13, color: '#94a3b8')

# Repaint every hidden unit's receptive field: the 16×16 slice of W1
# weighting how each input pixel feeds that unit, normalized per unit so
# the strongest weight uses the full palette. Driven by `rf_dirty` rather
# than run every frame — see `rf_canvas`.
draw_receptive_fields = lambda do
  rf_canvas.clear
  thumb_buckets.each(&:clear)
  HIDDEN.times do |i|
    base = i * INPUT_DIM
    wmax = 0.0
    INPUT_DIM.times do |j|
      a = w1[base + j].abs
      wmax = a if a > wmax
    end
    wmax = 1e-6 if wmax < 1e-6
    rects = RF_RECTS[i]
    j = 0
    while j < INPUT_DIM
      v = w1[base + j] / wmax  # normalized to -1..1
      idx = ((v + 1.0) * 0.5 * 31).round.clamp(0, 31)
      thumb_buckets[idx] << rects[j]
      j += 1
    end
  end
  thumb_buckets.each_with_index do |rects, i|
    next if rects.empty?

    rf_canvas.fill_rectangles(rectangles: rects, color: DIVERGING_PAL[i])
  end
end

reset = lambda do
  rf_dirty = true
  shape_accum = 0.0
  rf_accum = 0.0
  user_grid.fill(0.0)
  last_mouse = nil
  mouse_held = false
  w1, b1, w2, b2 = fresh_weights
  state[:steps] = 0
  state[:loss] = 0.0
  state[:done] = false
  display_grid = Array.new(INPUT_DIM, 0.0)
  display_nz = []
  display_class = nil
  display_y.fill(1.0 / NUM_CLASSES)
  loss_history.clear
  status.content = 'Training…'
  header_text.content = 'Training…'
  header_text.color = '#cbd5e1'
  hint.content = 'R retrain'
end

# === Input ===

def user_grid_coords(event)
  return nil unless event.x.between?(DRAW_X, DRAW_RIGHT - 1) &&
                    event.y.between?(DRAW_Y, DRAW_Y + DRAW_W - 1)
  [(event.x - DRAW_X) / DRAW_CELL.to_f, (event.y - DRAW_Y) / DRAW_CELL.to_f]
end

on :mouse_down do |event|
  next unless event.button?(:left)
  next unless state[:done]   # the grid is showing training shapes — not a canvas yet
  pos = user_grid_coords(event)
  next unless pos
  mouse_held = true
  stamp(user_grid, *pos, USER_BRUSH)
  last_mouse = pos
end

on :mouse_up do
  mouse_held = false
  last_mouse = nil
end

on :mouse_move do |event|
  next unless mouse_held
  pos = user_grid_coords(event)
  next unless pos
  if last_mouse
    stroke(user_grid, *last_mouse, *pos, USER_BRUSH)
  else
    stamp(user_grid, *pos, USER_BRUSH)
  end
  last_mouse = pos
end

on(key_down: :c) do
  user_grid.fill(0.0)
  last_mouse = nil
end

on(key_down: :r) { reset.call }

# === Update ===

update do |dt|
  elapsed += dt

  # --- Train (online: fresh example each step) ---
  last_x = nil; last_nz = nil; last_class = nil
  unless state[:done]
    TRAIN_PER_FRAME.times do
      break if state[:steps] >= TRAIN_TOTAL_STEPS
      x, nz, target = make_example(rand(NUM_CLASSES))
      l = train_step(x, nz, target, w1, b1, w2, b2, LEARNING_RATE)
      state[:loss] = state[:loss].zero? ? l : state[:loss] * 0.99 + l * 0.01
      state[:steps] += 1
      loss_history << state[:loss] if (state[:steps] % SPARKLINE_SAMPLE_EVERY).zero?
      last_x = x; last_nz = nz; last_class = target
    end
    if state[:steps] >= TRAIN_TOTAL_STEPS
      state[:done] = true
      rf_dirty = true    # last repaint: the weights stop moving here
      status.content = format('Trained — final loss %.3f. Draw a shape!', state[:loss])
      header_text.content = 'Draw a shape'
      header_text.color = '#cbd5e1'
      hint.content = 'C clear   ·   R retrain'
    else
      pct = (state[:steps] * 100.0 / TRAIN_TOTAL_STEPS).to_i
      status.content = format('Training… %d%%   loss %.3f', pct, state[:loss])
    end

    # Both panels advance on wall-clock accumulators, so the visualization
    # reads at the same speed everywhere. Training runs far faster than the
    # eye and at very different speeds per platform — pacing these by
    # frames or by step count made them strobe on one build and crawl on
    # another. Surplus is dropped rather than carried: at most one shape
    # and one repaint per frame, however long the frame was.
    shape_accum += SHAPE_UPDATES_PER_SEC * dt
    if last_x && (display_class.nil? || shape_accum >= 1.0)
      shape_accum = 0.0
      display_grid = last_x
      display_nz = last_nz
      display_class = last_class
    end

    rf_accum += RF_UPDATES_PER_SEC * dt
    if rf_accum >= 1.0
      rf_accum = 0.0
      rf_dirty = true
    end

    if !state[:done] && display_class
      header_text.content = "Training on #{CLASSES[display_class].upcase}"
      header_text.color = CLASS_COLORS[display_class]
    end
  end

  # --- Forward pass ---
  # While training, classify the displayed training shape (so the user
  # sees the network's current verdict on the very example it just took
  # a gradient step on). After training, classify the user's drawing.
  if state[:done]
    centered = centered_input(user_grid)
    forward_grid = centered
    forward_nz = []
    INPUT_DIM.times { |j| forward_nz << j if centered[j] > 0.001 }
    panel_grid = user_grid
  else
    forward_grid = display_grid
    forward_nz = display_nz
    panel_grid = display_grid
  end
  current_h, current_y = forward(forward_grid, forward_nz, w1, b1, w2, b2)

  # Predictions are meaningful while a training shape is on screen, or
  # after training when the user has drawn enough ink. Otherwise the
  # bars/lines/icons would reflect the learned biases on an empty grid
  # — visually misleading — so we keep them in a neutral resting state.
  show_prediction = if state[:done]
                      forward_nz.size > 4
                    else
                      !display_class.nil?
                    end

  # Ease the displayed softmax toward the network's raw output. With a
  # training shape changing several times a second, the raw
  # current_y would jump on each switch; this turns the jumps into
  # smooth animation. Snap back to uniform when there's nothing to
  # predict so the bars don't drift on bias alone.
  if show_prediction
    NUM_CLASSES.times { |k| display_y[k] += (current_y[k] - display_y[k]) * SMOOTH_RATE }
  else
    display_y.fill(1.0 / NUM_CLASSES)
  end

  # --- Render canvas: drawing grid + receptive-field thumbnails ---
  canvas.clear

  draw_buckets.each(&:clear)
  n = 0
  while n < INPUT_DIM
    idx = (panel_grid[n] * 31).round.clamp(0, 31)
    draw_buckets[idx] << DRAW_RECTS[n]
    n += 1
  end
  draw_buckets.each_with_index do |rects, i|
    next if rects.empty?
    canvas.fill_rectangles(rectangles: rects, color: GRAY_PAL[i])
  end

  # Each thumbnail visualizes one hidden unit's "receptive field": the
  # 16×16 slice of W1 weighting how every input pixel feeds into that
  # unit. Orange cells are pixels that push the unit's activation up
  # when ink is present; blue cells push it down. Right after random
  # init the thumbnails look like noise; as training progresses you'll
  # see them resolve into shape detectors — patterns the unit has
  # learned to fire on. This is the network's self-discovered
  # vocabulary, the features it built without anyone telling it what
  # to look for.
  if rf_dirty
    draw_receptive_fields.call
    rf_dirty = false
  end

  # Outline thumbnails whose unit is firing on the current input, so the
  # eye can pick out which features are matching. Stroke is drawn on the
  # thumbnail's own edge (not padded out) so adjacent active units don't
  # touch in the 2 px gutter between thumbnails.
  h_max = current_h.max
  h_max = 1.0 if h_max < 1e-6
  if show_prediction
    HIDDEN.times do |i|
      a = current_h[i] / h_max
      next if a < 0.05
      ty = (HIDDEN_TOP + i * HIDDEN_SPACING - RF_SIZE / 2.0).round
      canvas.stroke_rectangle(x: RF_X, y: ty, width: RF_SIZE, height: RF_SIZE,
                              stroke_width: 1, color: [0.95, 0.85, 0.40, 0.2 + a * 0.6])
    end
  end

  # Box the target class while training so you can see what label the
  # network is being pushed toward this step (vs. its current guess,
  # shown in the bars and icon tints).
  if !state[:done] && display_class
    cy = OUT_Y[display_class]
    canvas.stroke_rectangle(
      x: OUT_X - ICON_HALF - TARGET_PAD,
      y: cy - ICON_HALF - TARGET_PAD,
      width: 2 * (ICON_HALF + TARGET_PAD),
      height: 2 * (ICON_HALF + TARGET_PAD),
      stroke_width: 2,
      color: [0.98, 0.85, 0.30, 0.85]
    )
  end

  # Centroid hint — once trained, mark grid center with a faint cross
  # and the user's ink centroid with a small dot. The visible offset
  # between them is exactly what centered_input compensates for before
  # the network sees the drawing, which is otherwise invisible to the user.
  if SHOW_CENTROID_HINT && state[:done]
    cen_x = DRAW_X + (GRID_CENTER + 0.5) * DRAW_CELL
    cen_y = DRAW_Y + (GRID_CENTER + 0.5) * DRAW_CELL
    canvas.draw_line(x1: cen_x - 8, y1: cen_y, x2: cen_x + 8, y2: cen_y,
                     stroke_width: 1, color: [0.95, 0.85, 0.30, 0.35])
    canvas.draw_line(x1: cen_x, y1: cen_y - 8, x2: cen_x, y2: cen_y + 8,
                     stroke_width: 1, color: [0.95, 0.85, 0.30, 0.35])
    if forward_nz.size > 4 && (centroid = grid_centroid(user_grid))
      cgx, cgy = centroid
      canvas.fill_ellipse(x: DRAW_X + (cgx + 0.5) * DRAW_CELL,
                          y: DRAW_Y + (cgy + 0.5) * DRAW_CELL,
                          xradius: 3.5, yradius: 3.5,
                          color: [0.95, 0.85, 0.30, 0.9])
    end
  end

  # Loss curve — fills the panel left-to-right as samples accumulate.
  # Y is normalized to the running max so early high losses don't
  # squash the late curve into a flat line.
  if loss_history.size >= 2
    max_l = loss_history.max
    max_l = 1e-6 if max_l < 1e-6
    step = SPARKLINE_W.to_f / (SPARKLINE_HISTORY - 1)
    pts = loss_history.each_with_index.map do |l, i|
      [SPARKLINE_X + i * step,
       SPARKLINE_Y + SPARKLINE_H - 4 - (l / max_l) * (SPARKLINE_H - 8)]
    end
    canvas.draw_polyline(points: pts, stroke_width: 1.5, color: '#38bdf8')
  end

  # --- Update connection lines based on current activations & weights ---
  # When show_prediction is false, fall back to the lines' resting style
  # rather than letting bias-driven activations on an empty grid drive
  # the animation.
  if show_prediction
    HIDDEN.times do |i|
      a = current_h[i] / h_max
      line = input_lines[i]
      line.stroke_width = 0.6 + a * 3.4
      line.color = [0.55, 0.75, 1.0, 0.10 + a * 0.55]
    end
    NUM_CLASSES.times do |k|
      base = k * HIDDEN
      HIDDEN.times do |i|
        w = w2[base + i]
        contribution = (w * current_h[i]).abs
        line = output_lines[k * HIDDEN + i]
        line.stroke_width = 0.5 + (contribution * 1.6).clamp(0, 4.5)
        alpha = 0.10 + (contribution * 0.9).clamp(0, 0.7)
        line.color = if w >= 0
                       [0.96, 0.60, 0.32, alpha]
                     else
                       [0.32, 0.65, 0.96, alpha]
                     end
      end
    end
  else
    # Idle pulse — input lines breathe slowly so the network reads as
    # alive while it waits for a drawing. Output lines stay flat so the
    # eye isn't pulled in two directions.
    pulse = 0.5 + 0.5 * Math.sin(elapsed * IDLE_PULSE_RATE)
    input_lines.each do |line|
      line.stroke_width = 0.8 + 0.4 * pulse
      line.color = [0.55, 0.7, 0.95, 0.10 + 0.10 * pulse]
    end
    output_lines.each do |line|
      line.stroke_width = 1
      line.color = [0.6, 0.7, 0.85, 0.20]
    end
  end

  # --- Update output panel ---
  # Drive bars, icon tints, and the predicted-class pick from display_y
  # rather than current_y, so everything moves at the same smoothed
  # cadence and a momentary tie between two classes doesn't make the
  # label hop back and forth between them.
  predicted = 0
  best = -1.0
  NUM_CLASSES.times do |k|
    p = show_prediction ? display_y[k] : 0.0
    out_bars[k].width = (BAR_W * p).round
    rb, gb, bb = CLASS_RGB[k]
    rd, gd, bdd = DIM_RGB
    out_icons[k].color = [rd + (rb - rd) * p, gd + (gb - gd) * p,
                          bdd + (bb - bdd) * p, 1.0]
    if display_y[k] > best
      best = display_y[k]
      predicted = k
    end
  end

  # The result label sits directly under whichever icon was picked, so
  # the eye associates the word with its shape. Hidden entirely when
  # there's nothing to predict — a stray dash on screen reads as a
  # leftover placeholder, not a "neutral" state.
  if show_prediction
    result_text.content = CLASSES[predicted].upcase
    result_text.color = best > 0.5 ? CLASS_COLORS[predicted] : '#94a3b8'
    result_text.x = OUT_X - result_text.width / 2
    result_text.y = OUT_Y[predicted] + ICON_HALF + 6
    result_text.show
  else
    result_text.hide
  end
end

show
