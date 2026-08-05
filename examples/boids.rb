# Boids
# A flocking simulation governed by separation, alignment, and cohesion.
#
# The flock self-organizes from local rules with no global plan. Move
# the cursor near the flock to scatter it; press `r` to randomize.
# Neighbor lookups go through a uniform spatial grid rather than
# comparing every pair, which is what keeps the flock cheap to run.

require 'ruby2d'

# === Tunables ===

WIDTH = 800             # window width in pixels
HEIGHT = 600            # window height in pixels
COUNT = 90              # number of boids in the flock
VIEW_RADIUS = 70        # how far a boid can see neighbors (pixels)
AVOID_RADIUS = 24       # personal-space radius for separation (pixels)
MAX_SPEED = 432         # cap on boid velocity (px/sec)
MIN_SPEED = 80          # boids cruise at least this fast (px/sec)
MAX_FORCE = 1152        # cap on per-update steering force (px/sec²)
ALIGNMENT = 4.2         # alignment blend rate toward neighbor heading (per sec)
COHESION = 1.2          # cohesion blend rate toward flock center (per sec)
SEPARATION = 10.8       # separation blend rate away from close neighbors (per sec)
MOUSE_REPULSION = 12960 # repulsion strength from the cursor (px/sec²)
CELL_W = 80             # spatial grid cell width in pixels (≥ VIEW_RADIUS)
CELL_H = 75             # spatial grid cell height in pixels (≥ VIEW_RADIUS)

GCOLS = WIDTH / CELL_W
GROWS = HEIGHT / CELL_H
NEIGHBORHOOD = [-1, 0, 1].freeze

# === Window ===

set title: 'Ruby 2D ▸ Examples ▸ Boids', width: WIDTH, height: HEIGHT, background: '#07111f'
set close_on_esc: true

# === Boid struct and helpers ===

Boid = Struct.new(:x, :y, :vx, :vy, :tri)

def make_boid
  angle = rand * Math::PI * 2
  Boid.new(
    rand(WIDTH), rand(HEIGHT),
    Math.cos(angle) * MAX_SPEED, Math.sin(angle) * MAX_SPEED,
    Triangle.new(x1: 0, y1: -8, x2: -5, y2: 6, x3: 5, y3: 6, color: '#67e8f9')
  )
end

def limit(x, y, max)
  mag = Math.sqrt(x * x + y * y)
  return [x, y] if mag <= max || mag.zero?

  [x / mag * max, y / mag * max]
end

def set_boid_triangle(boid)
  angle = Math.atan2(boid.vy, boid.vx) + Math::PI / 2
  pts = [[0, -10], [-6, 8], [6, 8]].map do |px, py|
    c = Math.cos(angle)
    s = Math.sin(angle)
    [boid.x + px * c - py * s, boid.y + px * s + py * c]
  end
  boid.tri.x1, boid.tri.y1 = pts[0]
  boid.tri.x2, boid.tri.y2 = pts[1]
  boid.tri.x3, boid.tri.y3 = pts[2]
end

# === Mutable state ===

boids = Array.new(COUNT) { make_boid }
buckets = Array.new(GCOLS * GROWS) { [] }
mouse_x = -1000
mouse_y = -1000

# === Input ===

on :mouse_move do |event|
  mouse_x = event.x
  mouse_y = event.y
end

on key_down: :r do
  boids.each do |b|
    b.x = rand(WIDTH)
    b.y = rand(HEIGHT)
    angle = rand * Math::PI * 2
    b.vx = Math.cos(angle) * MAX_SPEED
    b.vy = Math.sin(angle) * MAX_SPEED
  end
end

# === Per-frame update ===

update do |dt|
  # Bucket every boid by cell. Cells are at least VIEW_RADIUS across and
  # divide the window exactly, so a boid's visible neighbors can only lie
  # in the 3×3 block around its own cell — and the toroidal wrap lands on
  # a cell boundary. `clear` keeps each bucket's backing array, so the
  # refill reuses capacity instead of allocating one per frame.
  buckets.each(&:clear)
  boids.each do |b|
    gx = (b.x / CELL_W).to_i.clamp(0, GCOLS - 1)
    gy = (b.y / CELL_H).to_i.clamp(0, GROWS - 1)
    buckets[gy * GCOLS + gx] << b
  end

  boids.each do |b|
    sep_x = 0.0
    sep_y = 0.0
    ali_x = 0.0
    ali_y = 0.0
    coh_x = 0.0
    coh_y = 0.0
    neighbors = 0

    cx = (b.x / CELL_W).to_i.clamp(0, GCOLS - 1)
    cy = (b.y / CELL_H).to_i.clamp(0, GROWS - 1)

    NEIGHBORHOOD.each do |oy|
      row = ((cy + oy) % GROWS) * GCOLS
      NEIGHBORHOOD.each do |ox|
        buckets[row + ((cx + ox) % GCOLS)].each do |other|
          next if other.equal?(b)

          dx = other.x - b.x
          dy = other.y - b.y
          dx -= WIDTH if dx > WIDTH / 2
          dx += WIDTH if dx < -WIDTH / 2
          dy -= HEIGHT if dy > HEIGHT / 2
          dy += HEIGHT if dy < -HEIGHT / 2
          d2 = dx * dx + dy * dy
          next if d2 > VIEW_RADIUS * VIEW_RADIUS

          d = Math.sqrt(d2) + 0.001
          neighbors += 1
          ali_x += other.vx
          ali_y += other.vy
          coh_x += b.x + dx
          coh_y += b.y + dy
          if d < AVOID_RADIUS
            sep_x -= dx / d
            sep_y -= dy / d
          end
        end
      end
    end

    ax = 0.0
    ay = 0.0
    if neighbors.positive?
      ali_x, ali_y = limit(ali_x / neighbors, ali_y / neighbors, MAX_SPEED)
      ax += (ali_x - b.vx) * ALIGNMENT
      ay += (ali_y - b.vy) * ALIGNMENT

      target_x = coh_x / neighbors
      target_y = coh_y / neighbors
      seek_x, seek_y = limit(target_x - b.x, target_y - b.y, MAX_SPEED)
      ax += (seek_x - b.vx) * COHESION
      ay += (seek_y - b.vy) * COHESION

      sep_x, sep_y = limit(sep_x, sep_y, MAX_SPEED)
      ax += sep_x * SEPARATION
      ay += sep_y * SEPARATION
    end

    mdx = b.x - mouse_x
    mdy = b.y - mouse_y
    md2 = mdx * mdx + mdy * mdy
    if md2 < 80 * 80
      md = Math.sqrt(md2) + 0.001
      ax += mdx / md * MOUSE_REPULSION
      ay += mdy / md * MOUSE_REPULSION
    end

    ax, ay = limit(ax, ay, MAX_FORCE)
    b.vx += ax * dt
    b.vy += ay * dt
    b.vx, b.vy = limit(b.vx, b.vy, MAX_SPEED)
    speed = Math.sqrt(b.vx * b.vx + b.vy * b.vy)
    if speed < MIN_SPEED && speed > 0.01
      b.vx *= MIN_SPEED / speed
      b.vy *= MIN_SPEED / speed
    end
    b.x = (b.x + b.vx * dt) % WIDTH
    b.y = (b.y + b.vy * dt) % HEIGHT
    set_boid_triangle(b)
  end
end

show
