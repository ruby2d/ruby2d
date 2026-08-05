# Marching squares
# Drifting metaballs merge and split as the iso-line is extracted live.
# Move the mouse to stir the blobs; press R to reshuffle.
#
# A handful of metaballs each contribute to a smooth scalar field
# (1/r² potential). The classic marching squares algorithm extracts
# the iso-line where the field equals a threshold: it samples on a
# coarse grid, then for each cell looks at which corners are above the
# threshold and connects the interpolated edge crossings. The blobs
# merge and split as the balls drift, and the cursor is one more ball
# you can herd them with.

require 'ruby2d'

# === Tunables ===

WIDTH = 800              # window width in pixels
HEIGHT = 600             # window height in pixels
CELL = 10                # marching squares cell size in pixels
NUM_BALLS = 6            # how many metaballs in motion
THRESHOLD = 1.0          # iso-level extracted as the contour
BALL_MIN_R = 60          # smallest metaball radius
BALL_MAX_R = 110         # largest metaball radius
BALL_SPEED = 160         # max ball speed (px/sec)
CURSOR_R = 70            # radius of the metaball that follows the mouse

GRID_W = WIDTH  / CELL
GRID_H = HEIGHT / CELL

# Edges per case in the marching-squares lookup table. Corners are
# numbered 0=BL, 1=BR, 2=TR, 3=TL; edges 0=bottom, 1=right, 2=top,
# 3=left. The 4-bit case index is built as bit0=c0, bit1=c1, …
EDGES = [
  [],                   # 0:  0000
  [[0, 3]],             # 1:  0001
  [[0, 1]],             # 2:  0010
  [[1, 3]],             # 3:  0011
  [[1, 2]],             # 4:  0100
  [[0, 1], [2, 3]],     # 5:  0101 (saddle)
  [[0, 2]],             # 6:  0110
  [[2, 3]],             # 7:  0111
  [[2, 3]],             # 8:  1000
  [[0, 2]],             # 9:  1001
  [[0, 3], [1, 2]],     # 10: 1010 (saddle)
  [[1, 2]],             # 11: 1011
  [[1, 3]],             # 12: 1100
  [[0, 1]],             # 13: 1101
  [[0, 3]],             # 14: 1110
  []                    # 15: 1111
].freeze

# === Window ===

set title: 'Ruby 2D ▸ Examples ▸ Marching squares',
    width: WIDTH, height: HEIGHT, background: '#0a0a14'
set close_on_esc: true

# === State ===

balls = Array.new(NUM_BALLS) do
  {
    x:  rand * WIDTH,
    y:  rand * HEIGHT,
    r:  BALL_MIN_R + rand * (BALL_MAX_R - BALL_MIN_R),
    vx: (rand - 0.5) * 2 * BALL_SPEED,
    vy: (rand - 0.5) * 2 * BALL_SPEED
  }
end

field = Array.new(GRID_H + 1) { Array.new(GRID_W + 1, 0.0) }

cursor_x  = WIDTH / 2.0
cursor_y  = HEIGHT / 2.0
cursor_on = false        # true once the mouse has moved into the field

reshuffle = lambda do
  balls.each do |b|
    b[:x]  = rand * WIDTH
    b[:y]  = rand * HEIGHT
    b[:r]  = BALL_MIN_R + rand * (BALL_MAX_R - BALL_MIN_R)
    b[:vx] = (rand - 0.5) * 2 * BALL_SPEED
    b[:vy] = (rand - 0.5) * 2 * BALL_SPEED
  end
end

# === Input ===

on :mouse_move do |event|
  cursor_x  = event.x
  cursor_y  = event.y
  cursor_on = true
end

on key_down: :r do
  reshuffle.call
end

# Flattened ball fields, refilled each frame. See the resample loop.
ball_x = Array.new(NUM_BALLS + 1, 0.0)
ball_y = Array.new(NUM_BALLS + 1, 0.0)
ball_r2 = Array.new(NUM_BALLS + 1, 0.0)

# === Per-frame update ===

update do |dt|
  balls.each do |b|
    b[:x] += b[:vx] * dt
    b[:y] += b[:vy] * dt
    b[:vx] = -b[:vx] if (b[:x] < 0 && b[:vx] < 0) || (b[:x] > WIDTH  && b[:vx] > 0)
    b[:vy] = -b[:vy] if (b[:y] < 0 && b[:vy] < 0) || (b[:y] > HEIGHT && b[:vy] > 0)
  end

  # Resample the scalar field at every grid corner. Each metaball
  # contributes r²/(d²+1) — the +1 keeps the field finite at the center.
  # The cursor is one more ball, so the mouse shapes the field too.
  # Flatten the balls (and the cursor, which acts as one more ball) into
  # plain arrays first. The resample below reads these at every one of
  # ~4,900 grid corners, where a Hash lookup per read costs far more than
  # the arithmetic around it.
  count = 0
  balls.each do |b|
    ball_x[count] = b[:x]
    ball_y[count] = b[:y]
    ball_r2[count] = b[:r] * b[:r]
    count += 1
  end
  if cursor_on
    ball_x[count] = cursor_x
    ball_y[count] = cursor_y
    ball_r2[count] = CURSOR_R * CURSOR_R
    count += 1
  end

  (GRID_H + 1).times do |gy|
    y = gy * CELL
    row = field[gy]
    (GRID_W + 1).times do |gx|
      x = gx * CELL
      sum = 0.0
      n = 0
      while n < count
        dx = x - ball_x[n]
        dy = y - ball_y[n]
        sum += ball_r2[n] / (dx * dx + dy * dy + 1.0)
        n += 1
      end
      row[gx] = sum
    end
  end
end

# === Render ===

# Two-pass stroke for a soft neon look: a thicker, faded line behind a
# crisp thin line on top.
GLOW = [0.99, 0.86, 0.27, 0.35]
CORE = [1.0,  0.97, 0.65, 1.0]

render do
  gy = 0
  while gy < GRID_H
    gx = 0
    while gx < GRID_W
      v0 = field[gy + 1][gx]
      v1 = field[gy + 1][gx + 1]
      v2 = field[gy][gx + 1]
      v3 = field[gy][gx]
      bits  = v0 > THRESHOLD ? 1 : 0
      bits |= 2 if v1 > THRESHOLD
      bits |= 4 if v2 > THRESHOLD
      bits |= 8 if v3 > THRESHOLD
      if bits != 0 && bits != 15
        cx = gx * CELL
        cy = gy * CELL
        EDGES[bits].each do |edge_a, edge_b|
          # Inline edge interpolation. `t` is the linear position of the
          # threshold between the two corner values along the edge.
          case edge_a
          when 0 then ax = cx + (THRESHOLD - v0) / (v1 - v0) * CELL; ay = cy + CELL
          when 1 then ax = cx + CELL; ay = cy + CELL - (THRESHOLD - v1) / (v2 - v1) * CELL
          when 2 then ax = cx + (THRESHOLD - v3) / (v2 - v3) * CELL; ay = cy
          else        ax = cx; ay = cy + CELL - (THRESHOLD - v0) / (v3 - v0) * CELL
          end
          case edge_b
          when 0 then bx = cx + (THRESHOLD - v0) / (v1 - v0) * CELL; by = cy + CELL
          when 1 then bx = cx + CELL; by = cy + CELL - (THRESHOLD - v1) / (v2 - v1) * CELL
          when 2 then bx = cx + (THRESHOLD - v3) / (v2 - v3) * CELL; by = cy
          else        bx = cx; by = cy + CELL - (THRESHOLD - v0) / (v3 - v0) * CELL
          end
          Line.render(x1: ax, y1: ay, x2: bx, y2: by, stroke_width: 6, color: GLOW)
          Line.render(x1: ax, y1: ay, x2: bx, y2: by, stroke_width: 2, color: CORE)
        end
      end
      gx += 1
    end
    gy += 1
  end
end

show
