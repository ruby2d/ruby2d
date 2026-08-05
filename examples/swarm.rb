# Swarm
# Drifting dots linked to their nearest neighbors form a living mesh.
#
# 120 dots drift across a dark field, each linked to its two nearest
# neighbors by a thin line — a living network that re-stitches itself
# every frame. The cursor pushes dots aside within a small radius, so
# the mesh bends and tears around it as you move. Press `r` to scatter.

require 'ruby2d'

# === Tunables ===

WIDTH = 800              # window width in pixels
HEIGHT = 600             # window height in pixels
DOT_COUNT = 120          # number of dots in the swarm
NEIGHBORS = 2            # links per dot to its nearest neighbors
LINK_RADIUS = 160        # links beyond this distance are not drawn
DRIFT_SPEED = 25         # average dot drift speed (px/sec)
PUSH_RADIUS = 100        # cursor influence radius
PUSH_STRENGTH = 300      # max cursor push speed (px/sec)
FADE_IN_RATE = 3.0       # opacity units per second when a link forms
FADE_OUT_RATE = 2.0      # opacity units per second when a link drops

# === Window ===

set title: 'Ruby 2D ▸ Examples ▸ Swarm', width: WIDTH, height: HEIGHT, background: '#0a0a23'
set close_on_esc: true

# === Initialization ===

Dot = Struct.new(:x, :y, :vx, :vy, :shape)
Edge = Struct.new(:line, :opacity)

def random_velocity
  angle = rand * 2 * Math::PI
  speed = DRIFT_SPEED * (0.6 + rand * 0.8)
  [Math.cos(angle) * speed, Math.sin(angle) * speed]
end

def random_dot
  vx, vy = random_velocity
  x = rand * WIDTH
  y = rand * HEIGHT
  Dot.new(
    x, y, vx, vy,
    Circle.new(
      x: x, y: y, radius: 3,
      color: [rand * 0.5 + 0.5, rand * 0.5 + 0.5, rand * 0.5 + 0.5, 0.8]
    )
  )
end

dots = Array.new(DOT_COUNT) { random_dot }

# Pool sized to cover the steady-state edge count plus headroom for edges
# still fading out while their replacements fade in.
LINE_POOL_SIZE = DOT_COUNT * NEIGHBORS * 3
free_lines = Array.new(LINE_POOL_SIZE) do
  Line.new(x1: 0, y1: 0, x2: 0, y2: 0,
           stroke_width: 1, color: [0.6, 0.75, 1.0, 0],
           visible: false)
end

# Active edges keyed by sorted-pair index. Tracking by pair (rather than by
# line slot) lets opacity ease toward its distance-based target across
# frames, so links fade in/out instead of snapping when the K-nearest
# neighbor set shifts.
edges = {}

# Reused per-frame buffers. `desired` is cleared rather than rebuilt, and
# the two `best_*` arrays hold one dot's nearest-NEIGHBORS selection.
desired = {}
best_d2 = Array.new(NEIGHBORS, 0.0)
best_j = Array.new(NEIGHBORS, -1)

mouse_x = WIDTH / 2.0
mouse_y = HEIGHT / 2.0

# === Input ===

on :mouse_move do |event|
  mouse_x = event.x
  mouse_y = event.y
end

on key_down: :r do
  dots.each do |d|
    d.x = rand * WIDTH
    d.y = rand * HEIGHT
    d.vx, d.vy = random_velocity
  end
end

# === Update ===

update do |dt|
  push_r2 = PUSH_RADIUS * PUSH_RADIUS
  link_r2 = LINK_RADIUS * LINK_RADIUS

  # Move dots: drift + cursor push, wrap at edges
  dots.each do |d|
    px = 0.0
    py = 0.0
    rx = d.x - mouse_x
    ry = d.y - mouse_y
    r2 = rx * rx + ry * ry
    if r2 < push_r2 && r2 > 0.001
      r = Math.sqrt(r2)
      push = PUSH_STRENGTH * (1.0 - r / PUSH_RADIUS) * dt
      px = (rx / r) * push
      py = (ry / r) * push
    end
    d.x = (d.x + d.vx * dt + px) % WIDTH
    d.y = (d.y + d.vy * dt + py) % HEIGHT
    d.shape.x = d.x
    d.shape.y = d.y
  end

  # Collect this frame's desired pairs and their target opacities. Pair
  # distance is symmetric, so a pair selected from both endpoints writes
  # the same target either way.
  # Only the NEIGHBORS nearest survive, so each candidate is inserted
  # straight into a sorted fixed-size buffer. Building a full candidate
  # list and sorting it would allocate ~20 arrays per dot to discard all
  # but two — the cutoff test below rejects most candidates outright.
  desired.clear
  cutoff = link_r2 + 1.0
  DOT_COUNT.times do |i|
    di = dots[i]
    NEIGHBORS.times do |n|
      best_d2[n] = cutoff
      best_j[n] = -1
    end
    DOT_COUNT.times do |j|
      next if i == j
      dj = dots[j]
      dx = di.x - dj.x
      dy = di.y - dj.y
      d2 = dx * dx + dy * dy
      next if d2 > link_r2 || d2 >= best_d2[NEIGHBORS - 1]

      n = NEIGHBORS - 1
      while n > 0 && best_d2[n - 1] > d2
        best_d2[n] = best_d2[n - 1]
        best_j[n] = best_j[n - 1]
        n -= 1
      end
      best_d2[n] = d2
      best_j[n] = j
    end
    NEIGHBORS.times do |n|
      j = best_j[n]
      next if j.negative?

      key = i < j ? i * DOT_COUNT + j : j * DOT_COUNT + i
      desired[key] = (1.0 - Math.sqrt(best_d2[n]) / LINK_RADIUS) * 0.5
    end
  end

  # Allocate lines for newly desired pairs (starting at opacity 0 so they
  # fade in rather than appearing at full target opacity).
  desired.each_key do |key|
    next if edges.key?(key)
    line = free_lines.pop
    break unless line
    edges[key] = Edge.new(line, 0.0)
  end

  # Ease each active edge's opacity toward its target, render it, and
  # release lines whose edges have fully faded out.
  edges.delete_if do |key, edge|
    target = desired[key] || 0.0
    edge.opacity = if edge.opacity < target
                     [edge.opacity + FADE_IN_RATE * dt, target].min
                   else
                     [edge.opacity - FADE_OUT_RATE * dt, target].max
                   end
    if edge.opacity <= 0.001 && target.zero?
      edge.line.visible = false
      free_lines << edge.line
      true
    else
      di = dots[key / DOT_COUNT]
      dj = dots[key % DOT_COUNT]
      line = edge.line
      dx = di.x - dj.x
      dy = di.y - dj.y
      if dx * dx + dy * dy > link_r2
        # Endpoints span more than LINK_RADIUS ▸ typically because a dot
        # just wrapped at the screen edge or was scattered. Hide the line
        # while the edge fades out so it doesn't shoot across the window.
        line.visible = false
      else
        line.x1 = di.x
        line.y1 = di.y
        line.x2 = dj.x
        line.y2 = dj.y
        line.opacity = edge.opacity
        line.visible = true
      end
      false
    end
  end
end

show
