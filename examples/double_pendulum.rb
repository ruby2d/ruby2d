# Double pendulum
# Two arms swinging from a fixed pivot, tracing a cycling rainbow trail.
#
# Governed by the Lagrangian equations of motion and integrated with RK4
# for stability. Grab the end bob with the mouse to pose the arms, then
# let go to set it swinging — flick as you release to throw it with spin.
# Press `r` for a fresh random drop.

require 'ruby2d'

# === Tunables ===

WIDTH = 800              # window width in pixels
HEIGHT = 600             # window height in pixels
PIVOT_X = WIDTH / 2.0    # pivot x position
PIVOT_Y = HEIGHT / 2.0   # pivot y, centered so the whole swing stays in view
L1 = 140.0               # length of arm 1 in pixels
L2 = 140.0               # length of arm 2 in pixels
REACH_MAX = L1 + L2      # farthest the end bob can reach from the pivot
REACH_MIN = (L1 - L2).abs # closest the end bob can reach to the pivot
M1 = 1.0                 # mass of bob 1
M2 = 1.0                 # mass of bob 2
G  = 1500.0              # gravitational acceleration (px/sec²)
SUB_STEPS = 8            # RK4 sub-steps per frame for stability
TRAIL_HUE_RATE = 0.15    # rate of rainbow color cycling (cycles/sec)
VEL_SMOOTH = 30.0        # responsiveness of the throw velocity estimate (1/sec)
THROW_MAX = 15.0         # cap on release angular velocity (rad/sec)

# === Window ===

set title: 'Ruby 2D ▸ Examples ▸ Double pendulum', width: WIDTH, height: HEIGHT
set close_on_esc: true

BG = [0.04, 0.04, 0.08, 1]

# === Helpers ===

def deriv(t1, w1, t2, w2)
  s = Math.sin(t1 - t2)
  c = Math.cos(t1 - t2)
  den = 2 * M1 + M2 - M2 * Math.cos(2 * t1 - 2 * t2)

  a1 = (-G * (2 * M1 + M2) * Math.sin(t1) -
        M2 * G * Math.sin(t1 - 2 * t2) -
        2 * s * M2 * (w2 * w2 * L2 + w1 * w1 * L1 * c)) / (L1 * den)

  a2 = (2 * s * (w1 * w1 * L1 * (M1 + M2) +
                 G * (M1 + M2) * Math.cos(t1) +
                 w2 * w2 * L2 * M2 * c)) / (L2 * den)

  [w1, a1, w2, a2]
end

def rk4_step(t1, w1, t2, w2, dt)
  d1 = deriv(t1, w1, t2, w2)
  d2 = deriv(t1 + 0.5 * dt * d1[0], w1 + 0.5 * dt * d1[1],
             t2 + 0.5 * dt * d1[2], w2 + 0.5 * dt * d1[3])
  d3 = deriv(t1 + 0.5 * dt * d2[0], w1 + 0.5 * dt * d2[1],
             t2 + 0.5 * dt * d2[2], w2 + 0.5 * dt * d2[3])
  d4 = deriv(t1 + dt * d3[0], w1 + dt * d3[1],
             t2 + dt * d3[2], w2 + dt * d3[3])
  [
    t1 + dt / 6.0 * (d1[0] + 2 * d2[0] + 2 * d3[0] + d4[0]),
    w1 + dt / 6.0 * (d1[1] + 2 * d2[1] + 2 * d3[1] + d4[1]),
    t2 + dt / 6.0 * (d1[2] + 2 * d2[2] + 2 * d3[2] + d4[2]),
    w2 + dt / 6.0 * (d1[3] + 2 * d2[3] + 2 * d3[3] + d4[3])
  ]
end

def hsv_rgb(h, s, v)
  i = (h * 6).floor
  f = h * 6 - i
  p = v * (1 - s)
  q = v * (1 - f * s)
  tt = v * (1 - (1 - f) * s)
  case i % 6
  when 0 then [v, tt, p]
  when 1 then [q, v, p]
  when 2 then [p, v, tt]
  when 3 then [p, q, v]
  when 4 then [tt, p, v]
  else        [v, p, q]
  end
end

# Wrap an angle difference into [-PI, PI] so continuity checks and
# velocity estimates ignore full-turn wraparound.
def wrap_pi(a)
  ((a + Math::PI) % (2 * Math::PI)) - Math::PI
end

# Inverse kinematics: arm angles that place the end bob at (px, py). A
# two-link arm can reach a target two ways (elbow either side); we return
# whichever bend stays closest to the reference pose, so grabbing and
# dragging never snap the arm through a flip. Angles follow the sim's
# convention — measured from straight down, with x = sin, y = cos.
def solve_ik(px, py, ref_t1, ref_t2)
  dx = px - PIVOT_X
  dy = py - PIVOT_Y
  return [ref_t1, ref_t2] if dx.zero? && dy.zero?

  d = Math.hypot(dx, dy).clamp(REACH_MIN + 0.001, REACH_MAX - 0.001)
  phi = Math.atan2(dx, dy)                          # pivot → target heading
  cos_bend = ((d * d - L1 * L1 - L2 * L2) / (2 * L1 * L2)).clamp(-1.0, 1.0)
  bend = Math.atan2(Math.sqrt(1 - cos_bend * cos_bend), cos_bend)  # avoid acos

  best = nil
  best_cost = nil
  [bend, -bend].each do |b|
    a1 = phi - Math.atan2(L2 * Math.sin(b), L1 + L2 * Math.cos(b))
    a2 = a1 + b
    cost = wrap_pi(a1 - ref_t1).abs + wrap_pi(a2 - ref_t2).abs
    if best_cost.nil? || cost < best_cost
      best = [a1, a2]
      best_cost = cost
    end
  end
  best
end

# === Mutable state ===

# Arm angles (from straight down) and angular velocities; `reset` seeds
# the angles randomly below. While `dragging`, the sim is paused and the
# end bob tracks the cursor.
t1 = 0.0
w1 = 0.0
t2 = 0.0
w2 = 0.0
hue = 0.0
dragging = false
mouse_x = PIVOT_X
mouse_y = PIVOT_Y

# === Renderables ===

canvas = Canvas.new(x: 0, y: 0, width: WIDTH, height: HEIGHT, fill: BG)

arm1 = Line.new(x1: PIVOT_X, y1: PIVOT_Y, x2: PIVOT_X, y2: PIVOT_Y,
                stroke_width: 3, color: [0.85, 0.85, 0.95, 1], z: 5)
arm2 = Line.new(x1: PIVOT_X, y1: PIVOT_Y, x2: PIVOT_X, y2: PIVOT_Y,
                stroke_width: 3, color: [0.85, 0.85, 0.95, 1], z: 5)
grab_ring = Circle.new(x: PIVOT_X, y: PIVOT_Y, radius: 18,
                       color: [0.6, 0.9, 1.0, 0.4], z: 4, visible: false)
bob1 = Circle.new(x: PIVOT_X, y: PIVOT_Y, radius: 8,
                  color: [0.95, 0.6, 0.3, 1], z: 6)
bob2 = Circle.new(x: PIVOT_X, y: PIVOT_Y, radius: 10,
                  color: [0.4, 0.85, 0.95, 1], z: 6)
Circle.new(x: PIVOT_X, y: PIVOT_Y, radius: 4,
           color: [0.7, 0.7, 0.8, 1], z: 7)

# === Reset ===

# Release the pendulum from rest at a random position. Both arms start
# in the upper hemisphere ([PI/2, 3PI/2] from straight down) so there is
# always potential energy to unleash — a near-straight-down start would
# barely move.
reset = lambda do
  t1 = Math::PI / 2 + rand * Math::PI
  t2 = Math::PI / 2 + rand * Math::PI
  w1 = 0.0
  w2 = 0.0
  dragging = false
  grab_ring.hide
  canvas.clear
end
reset.call

# === Input ===

# Grab the end bob and snap it to the cursor. The sim pauses until
# release; `update` then tracks the cursor and estimates throw velocity.
on mouse_down: :left do |event|
  mouse_x = event.x
  mouse_y = event.y
  t1, t2 = solve_ik(mouse_x, mouse_y, t1, t2)
  w1 = 0.0
  w2 = 0.0
  dragging = true
  grab_ring.show
end

on :mouse_move do |event|
  mouse_x = event.x
  mouse_y = event.y
end

# Release: keep the drag-estimated angular velocity (capped) as the
# throw, so a flick imparts spin and letting go at rest just drops it.
on :mouse_up do
  next unless dragging
  dragging = false
  w1 = w1.clamp(-THROW_MAX, THROW_MAX)
  w2 = w2.clamp(-THROW_MAX, THROW_MAX)
  grab_ring.hide
end

on(key_down: :r) { reset.call }

# === Update ===

update do |dt|
  if dragging
    # Follow the cursor via IK; estimate angular velocity for the throw
    # by smoothing the per-frame change in each arm's angle.
    target = solve_ik(mouse_x, mouse_y, t1, t2)
    if dt > 0
      blend = 1 - Math.exp(-VEL_SMOOTH * dt)
      w1 += (wrap_pi(target[0] - t1) / dt - w1) * blend
      w2 += (wrap_pi(target[1] - t2) / dt - w2) * blend
    end
    t1, t2 = target
  else
    step_dt = dt / SUB_STEPS

    prev_x = PIVOT_X + L1 * Math.sin(t1) + L2 * Math.sin(t2)
    prev_y = PIVOT_Y + L1 * Math.cos(t1) + L2 * Math.cos(t2)

    SUB_STEPS.times do
      t1, w1, t2, w2 = rk4_step(t1, w1, t2, w2, step_dt)

      x = PIVOT_X + L1 * Math.sin(t1) + L2 * Math.sin(t2)
      y = PIVOT_Y + L1 * Math.cos(t1) + L2 * Math.cos(t2)

      hue = (hue + TRAIL_HUE_RATE * step_dt) % 1.0
      r, g, b = hsv_rgb(hue, 0.85, 1.0)
      canvas.draw_line(
        x1: prev_x, y1: prev_y, x2: x, y2: y,
        stroke_width: 1.5, color: [r, g, b, 0.7]
      )
      prev_x = x
      prev_y = y
    end
  end

  j1x = PIVOT_X + L1 * Math.sin(t1)
  j1y = PIVOT_Y + L1 * Math.cos(t1)
  j2x = j1x + L2 * Math.sin(t2)
  j2y = j1y + L2 * Math.cos(t2)
  arm1.x2 = j1x
  arm1.y2 = j1y
  arm2.x1 = j1x
  arm2.y1 = j1y
  arm2.x2 = j2x
  arm2.y2 = j2y
  bob1.x = j1x
  bob1.y = j1y
  bob2.x = j2x
  bob2.y = j2y
  grab_ring.x = j2x
  grab_ring.y = j2y
end

show
