# Lorenz attractor
# Lorenz's three-equation convection model traces its butterfly attractor in 3D.
#
# Edward Lorenz's three-equation toy model of atmospheric convection
#
#   dx/dt = σ (y − x)
#   dy/dt = x (ρ − z) − y
#   dz/dt = x y − β z
#
# never settles and never repeats, yet stays bounded inside a strange,
# butterfly-shaped region. Here it's integrated step by step with
# Euler, kept as a 3D trail, then perspective-projected and depth-shaded.
# The view rotates so you can see the structure from every angle.
# Press R to start over from a different seed point.

require 'ruby2d'

# === Tunables ===

WIDTH = 800              # window width in pixels
HEIGHT = 600             # window height in pixels
SIGMA = 10.0             # classical Lorenz parameters
RHO = 28.0
BETA = 8.0 / 3.0
DT = 0.005               # integration step (small enough for Euler stability)
STEPS_PER_FRAME = 60     # integration steps applied each frame
TRAIL_LEN = 2200         # how many trail points to keep
SCALE = 11               # pixels per Lorenz unit
CAMERA = 180.0           # camera distance in scaled units
TILT = 0.35              # fixed tilt around the screen-X axis (radians)
SPIN_RATE = 0.25         # idle rotation around the vertical axis (rad/sec)

CX = WIDTH  / 2
CY = HEIGHT / 2

# === Window ===

set title: 'Ruby 2D ▸ Examples ▸ Lorenz attractor',
    width: WIDTH, height: HEIGHT, background: '#06081a'
set close_on_esc: true

# === State ===

lx = 0.0; ly = 0.0; lz = 0.0
trail = []          # collected (lx, ly, lz) tuples in integration order
spin = 0.0

reset = lambda do
  lx = 0.1
  ly = 0.0
  lz = 0.0
  trail.clear
end

reset.call

# === Input ===

on key_down: :r do
  reset.call
end

# === Per-frame update ===

update do |dt|
  spin += SPIN_RATE * dt

  STEPS_PER_FRAME.times do
    dxv = SIGMA * (ly - lx)
    dyv = lx * (RHO - lz) - ly
    dzv = lx * ly - BETA * lz
    lx += DT * dxv
    ly += DT * dyv
    lz += DT * dzv
    trail << [lx, ly, lz]
  end

  trail.shift(trail.length - TRAIL_LEN) if trail.length > TRAIL_LEN
end

# === Render ===

# Lorenz `z` becomes screen-vertical (the convection variable is
# naturally the "up" axis); Lorenz `y` becomes screen-depth. Each trail
# point is rotated around the vertical axis by `spin`, tilted by a
# fixed amount around the horizontal axis, then perspective-projected.
# Per-vertex color encodes depth so the trail dims as it wraps behind.
render do
  cs = Math.cos(spin); ss = Math.sin(spin)
  ct = Math.cos(TILT); st = Math.sin(TILT)

  pts = []
  colors = []
  trail.each do |px, py, pz|
    wx = px
    wy = pz - 25     # center the attractor vertically
    wz = py

    wy2 =  wy * ct - wz * st
    wz2 =  wy * st + wz * ct

    wx3 =  wx * cs + wz2 * ss
    wz3 = -wx * ss + wz2 * cs

    f = CAMERA / (CAMERA - wz3)
    pts << [CX + wx3 * SCALE * f, CY - wy2 * SCALE * f]

    t = ((wz3 + 30) / 60.0).clamp(0.0, 1.0)
    colors << [0.30 + 0.65 * t, 0.50 + 0.45 * t, 0.85 + 0.15 * t, 0.20 + 0.75 * t]
  end

  Polyline.render(points: pts, color: colors, stroke_width: 1.5) if pts.length >= 2
end

show
