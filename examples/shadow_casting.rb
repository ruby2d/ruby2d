# 2D shadow casting
# A top-down flashlight paints a lit region behind sharp obstacle shadows.
#
# Light rays from the cursor are stopped by the rectangles, painting a
# brightly lit region surrounded by hard shadows. Move the mouse to sweep
# the light around. Press R to regenerate the scene.

require 'ruby2d'

# === Tunables ===

WIDTH = 800             # window width in pixels
HEIGHT = 600            # window height in pixels
NUM_OBSTACLES = 7       # rectangles scattered across the scene
OBS_MIN = 36            # smallest obstacle side, in pixels
OBS_MAX = 130           # largest obstacle side, in pixels
FALLOFF = 480           # distance over which the light fades to dark
ANGLE_EPS = 0.0003      # offset for the corner-peek rays (radians)
LIGHT_RGB = [1.0, 0.86, 0.45].freeze  # warm flashlight tint

# === Window ===

set title: 'Ruby 2D ▸ Examples ▸ 2D shadow casting',
    width: WIDTH, height: HEIGHT, background: '#08080d'
set close_on_esc: true
set render_mode: :on_demand

# === Helpers ===

# Ray (rx, ry) + t * (dx, dy) intersected with segment (s1)→(s2).
# Returns the ray parameter t (>= 0) of the closest hit, or nil. Since
# (dx, dy) is a unit vector, t is the hit distance in pixels.
def ray_segment_t(rx, ry, dx, dy, sx1, sy1, sx2, sy2)
  ex = sx2 - sx1
  ey = sy2 - sy1
  denom = dx * ey - dy * ex
  return nil if denom.abs < 1e-9

  inv = 1.0 / denom
  t = ((sx1 - rx) * ey - (sy1 - ry) * ex) * inv
  u = ((sx1 - rx) * dy - (sy1 - ry) * dx) * inv
  return nil if t < 0 || u < 0 || u > 1

  t
end

# === State ===

obstacles = []
segments  = []
corners   = []
light_x = WIDTH / 2.0
light_y = HEIGHT / 2.0

# === Reset ===

reset = lambda do
  obstacles.clear
  segments.clear
  corners.clear

  # The window border so every ray terminates somewhere.
  segments.push([0, 0, WIDTH, 0],
                [WIDTH, 0, WIDTH, HEIGHT],
                [WIDTH, HEIGHT, 0, HEIGHT],
                [0, HEIGHT, 0, 0])
  corners.push([0, 0], [WIDTH, 0], [WIDTH, HEIGHT], [0, HEIGHT])

  NUM_OBSTACLES.times do
    w = OBS_MIN + rand(OBS_MAX - OBS_MIN)
    h = OBS_MIN + rand(OBS_MAX - OBS_MIN)
    x = 24 + rand(WIDTH  - w - 48)
    y = 24 + rand(HEIGHT - h - 48)
    obstacles << [x, y, w, h]
    segments.push([x,     y,     x + w, y    ],
                  [x + w, y,     x + w, y + h],
                  [x + w, y + h, x,     y + h],
                  [x,     y + h, x,     y    ])
    corners.push([x, y], [x + w, y], [x + w, y + h], [x, y + h])
  end
  request_render
end

reset.call

# === Input ===

on :mouse_move do |event|
  light_x = event.x
  light_y = event.y
  request_render
end

on key_down: :r do
  reset.call
end

# === Render ===

render do
  # For every corner in the scene, cast three rays — one straight at
  # the corner and one tiny offset on each side — so the second pair
  # slips past and lands on whatever wall is hiding behind it. The
  # difference between the two is exactly the shadow boundary.
  hits = []
  corners.each do |cx, cy|
    base = Math.atan2(cy - light_y, cx - light_x)
    [-ANGLE_EPS, 0.0, ANGLE_EPS].each do |off|
      ang = base + off
      dx  = Math.cos(ang)
      dy  = Math.sin(ang)
      best_t = nil
      segments.each do |sx1, sy1, sx2, sy2|
        t = ray_segment_t(light_x, light_y, dx, dy, sx1, sy1, sx2, sy2)
        next if t.nil?

        best_t = t if best_t.nil? || t < best_t
      end
      next if best_t.nil?

      hits << [light_x + dx * best_t, light_y + dy * best_t, ang, best_t]
    end
  end
  hits.sort_by! { |h| h[2] }

  # Triangle fan from the light to each consecutive pair of hits. The
  # per-vertex alpha (opaque at the source, transparent at FALLOFF)
  # gives the radial falloff so far walls fade into shadow.
  inner = [LIGHT_RGB[0], LIGHT_RGB[1], LIGHT_RGB[2], 0.92]
  hits.each_with_index do |(hx, hy, _, t1), i|
    nx, ny, _, t2 = hits[(i + 1) % hits.length]
    a1 = (1.0 - t1 / FALLOFF).clamp(0.0, 0.92)
    a2 = (1.0 - t2 / FALLOFF).clamp(0.0, 0.92)
    Triangle.render(
      x1: light_x, y1: light_y,
      x2: hx,      y2: hy,
      x3: nx,      y3: ny,
      color: [inner,
              [LIGHT_RGB[0], LIGHT_RGB[1], LIGHT_RGB[2], a1],
              [LIGHT_RGB[0], LIGHT_RGB[1], LIGHT_RGB[2], a2]]
    )
  end

  obstacles.each do |x, y, w, h|
    Rectangle.render(x: x, y: y, width: w, height: h, color: '#1f2937')
  end

  Circle.render(x: light_x, y: light_y, radius: 5, color: '#fef9c3')
end

show
