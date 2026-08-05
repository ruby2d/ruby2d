# N-body
# Thousands of motes of dust orbit a gravity well, shearing into spiral arms.
#
# The disc starts on a polar lattice and winds itself up: every mote orbits at
# the same speed no matter how far out it sits, so the inner ranks lap the
# outer ones and the rings and spokes shear into spirals. Move the mouse and
# the dust streams after the cursor — the faster you move the harder it pulls,
# and the grip releases when you stop. Click to set off a shockwave that blows
# a cavity in the disc. Press `r` to rebuild the lattice. Stress test for many
# small shapes updated every frame.
#
# Caveats for physics nerds:
#   - The force law is effectively 1/r, not Newtonian 1/r². The coefficient
#     is divided by r² but then multiplied by the displacement vector instead
#     of the unit vector. The softer falloff is what gives the swarm its
#     sweeping orbits instead of violent slingshots — and, by accident, a flat
#     rotation curve, the same observation real galaxies need dark matter to
#     explain.
#   - The spokes are material arms, not density waves, so differential
#     rotation winds them up and phase-mixes them away within a minute or so.
#     The rings outlast them only because the drag in the update loop pins
#     each mote to the radius it started on. Real spiral arms don't wind up,
#     which is the winding problem density-wave theory exists to solve. Press
#     `r` to redraw the spokes.
#   - Motes feel the core and the cursor but never each other, so this is a
#     two-body problem run once per mote, not an N-body simulation.
#   - Integration is plain Euler against wall-clock dt, so behavior is
#     framerate-dependent — fine for a demo, not for reproducibility.
#   - Do not use this for your astronomy homework, mission planning, or
#     any task where being wrong has consequences beyond mild visual
#     disappointment.

require 'ruby2d'

# === Tunables ===

# Target mote count, rounded to fit the polar lattice. The web build runs
# mruby on WebAssembly, several times slower than native, so it gets fewer.
BODY_COUNT = Ruby2D.web? ? 2000 : 5000

UNIVERSE_WIDTH = 800     # window width in pixels
UNIVERSE_HEIGHT = 600    # window height in pixels
STAR_COUNT = 200         # background stars
DISC_INNER = 100         # inner edge of the dust disc (px from the core)
DISC_OUTER = 275         # outer edge; kept clear of the window edges
LATTICE_JITTER = 0.45    # random spread off each lattice point, in cell widths
ORBIT_SPEED = 55         # speed of a circular orbit, at any radius (px/sec)
SOFTENING = 24           # close-range force cap; prevents NaN at r = 0
CORE_RADIUS = 65         # radius of the core's glow (px)
CORE_LAYERS = 7          # translucent discs stacked to fake the glow's falloff
CURSOR_PULL = 40_000     # cursor attraction at full grip
CURSOR_FULL_SPEED = 700  # cursor speed that reaches full grip (px/sec)
GRIP_DECAY = 4.0         # grip fade rate once the cursor stops (per sec)
SETTLE = 0.5             # rate a disturbed mote relaxes onto a circular orbit
HEAL = 0.25              # rate a mote drifts back to its seeded radius
SHOCK_RADIUS = 260       # blast radius of a click (px)
SHOCK_SPEED = 160        # outward kick at the blast center (px/sec)
SHOCK_LIFE = 0.5         # shockwave ring lifetime (sec)
SHOCK_RINGS = 4          # overlapping shockwaves the ring pool can show
HOT_SPEED = 220          # speed mapped to the hottest color (px/sec)
HEAT_LEVELS = 24         # color ramp steps; see the update loop
HEAT_TOP = HEAT_LEVELS - 1
HEAT_STEP = HOT_SPEED.to_f / HEAT_TOP

# An orbit is circular when v² / r matches the inward pull, and that pull
# falls off as 1/r here (see the header), so v comes out constant — the same
# orbital speed at every radius. Angular speed is what varies, as v / r, which
# is why the disc has a hole in it: motes close to the core would whip round
# fast enough to be dizzying, so the lattice starts at DISC_INNER.
CORE_PULL = ORBIT_SPEED * ORBIT_SPEED
CENTER_X = UNIVERSE_WIDTH / 2.0
CENTER_Y = UNIVERSE_HEIGHT / 2.0
SOFTENING2 = SOFTENING * SOFTENING

# Ramp stops: at rest, at a brisk drift, at full tilt.
COLD = [0.20, 0.28, 0.70].freeze
WARM = [0.25, 0.80, 0.95].freeze
HOT = [1.00, 0.94, 0.80].freeze

# === Window ===

set title: 'Ruby 2D ▸ Examples ▸ N-body',
    width: UNIVERSE_WIDTH, height: UNIVERSE_HEIGHT, background: '#05050f'
set close_on_esc: true

# === Motes ===

Mote = Struct.new(:vx, :vy, :home, :depth, :level, :dot)
Shock = Struct.new(:ring, :age)

# Place `color` at position `t` along the cold-to-hot ramp. Mutating in place
# beats assigning a fresh Color: the native color cache only rebuilds when a
# channel actually changes.
def heat(color, t)
  if t < 0.5
    u = t * 2
    color.r = COLD[0] + (WARM[0] - COLD[0]) * u
    color.g = COLD[1] + (WARM[1] - COLD[1]) * u
    color.b = COLD[2] + (WARM[2] - COLD[2]) * u
  else
    u = t * 2 - 1
    color.r = WARM[0] + (HOT[0] - WARM[0]) * u
    color.g = WARM[1] + (HOT[1] - WARM[1]) * u
    color.b = WARM[2] + (HOT[2] - WARM[2]) * u
  end
end

# Split the mote budget into rings and spokes so the lattice cells come out
# roughly square at the disc's mid-radius.
disc_span = DISC_OUTER - DISC_INNER
disc_mid = (DISC_INNER + DISC_OUTER) / 2.0
rings = [Math.sqrt(BODY_COUNT * disc_span / (2 * Math::PI * disc_mid)).round, 2].max
spokes = (BODY_COUNT.to_f / rings).round
ring_gap = disc_span / (rings - 1)
spoke_gap = 2 * Math::PI / spokes

# === State ===

cursor_x = CENTER_X
cursor_y = CENTER_Y
last_x = CENTER_X
last_y = CENTER_Y
grip = 0.0
next_shock = 0

# === Renderables ===

STAR_COUNT.times do
  Circle.new(x: rand * UNIVERSE_WIDTH, y: rand * UNIVERSE_HEIGHT,
             radius: rand < 0.85 ? 1 : 1.6, sectors: 6, z: 0,
             color: '#cfd8ff', opacity: 0.1 + rand * 0.35)
end

# The core, stacked from the outside in so the overlapping alpha builds a
# falloff. It is the one fixed thing on screen once the disc starts turning,
# which is what keeps the rotation from reading as vertigo.
CORE_LAYERS.times do |i|
  Circle.new(x: CENTER_X, y: CENTER_Y, sectors: 40, z: 1,
             radius: CORE_RADIUS * (1 - i * 0.9 / CORE_LAYERS),
             color: '#9ecbff', opacity: 0.06)
end
Circle.new(x: CENTER_X, y: CENTER_Y, radius: 2.5, sectors: 12, z: 1,
           color: '#f2f8ff', opacity: 0.9)

# Depth is a parallax cue: nearer motes are larger, brighter, and swing harder
# on the cursor's leash, so stirring the disc pulls it apart into layers.
motes = Array.new(rings * spokes) do
  depth = 0.35 + rand * 0.65
  Mote.new(
    0.0, 0.0, 0.0, depth, -1,
    Circle.new(
      radius: 1.0 + 2.0 * depth, sectors: 6, z: 2,
      color: '#3348b3', opacity: 0.35 + 0.6 * depth
    )
  )
end

shocks = Array.new(SHOCK_RINGS) do
  Shock.new(
    Circle.new(radius: 1, sectors: 48, z: 3, fill: false,
               stroke_width: 2, stroke_color: '#bfe9ff', visible: false),
    SHOCK_LIFE
  )
end

# Seed the lattice, every mote on a circular orbit around the core. Same speed
# at every radius means the inner rings lap the outer ones, so the spokes
# shear into spirals over the first half-minute. Jitter goes on the position
# rather than the speed, so each mote still starts exactly circular.
reset = lambda do
  motes.each_with_index do |m, i|
    r = DISC_INNER + (i / spokes) * ring_gap + (rand - 0.5) * ring_gap * LATTICE_JITTER
    a = (i % spokes) * spoke_gap + (rand - 0.5) * spoke_gap * LATTICE_JITTER
    sin = Math.sin(a)
    cos = Math.cos(a)
    m.dot.x = CENTER_X + cos * r
    m.dot.y = CENTER_Y + sin * r
    m.vx = -sin * ORBIT_SPEED
    m.vy = cos * ORBIT_SPEED
    m.home = r
  end
end

reset.call

# === Input ===

on :mouse_move do |event|
  cursor_x = event.x
  cursor_y = event.y
end

on mouse_down: :left do |event|
  shock = shocks[next_shock]
  next_shock = (next_shock + 1) % SHOCK_RINGS
  shock.age = 0.0
  shock.ring.x = event.x
  shock.ring.y = event.y

  motes.each do |m|
    d = m.dot
    dx = d.x - event.x
    dy = d.y - event.y
    r = Math.sqrt(dx * dx + dy * dy)
    next if r > SHOCK_RADIUS || r < 0.001

    kick = SHOCK_SPEED * (1 - r / SHOCK_RADIUS)
    m.vx += dx / r * kick
    m.vy += dy / r * kick
  end
end

on key_down: :r do
  reset.call
end

# === Update ===

update do |dt|
  # Grip tracks how fast the cursor is moving and fades once it stops, so the
  # dust streams after the pointer and coasts free the moment you let go.
  moved = Math.sqrt((cursor_x - last_x)**2 + (cursor_y - last_y)**2)
  cursor_speed = dt.positive? ? moved / dt : 0.0
  grip *= Math.exp(-GRIP_DECAY * dt)
  grip = [cursor_speed / CURSOR_FULL_SPEED, grip].max
  grip = 1.0 if grip > 1.0
  last_x = cursor_x
  last_y = cursor_y

  pull = CURSOR_PULL * grip
  relax = 1 - Math.exp(-SETTLE * dt)

  # Copy every constant the loop below reads into a local first. A constant
  # is a table lookup, not a compile-time value: on the wasm build one costs
  # about as much as a method call, and the loop reads sixteen of them per
  # mote per frame. Locals are register slots, so this is free.
  center_x = CENTER_X
  center_y = CENTER_Y
  core_pull = CORE_PULL
  softening2 = SOFTENING2
  orbit_speed = ORBIT_SPEED
  heal = HEAL
  universe_width = UNIVERSE_WIDTH
  universe_height = UNIVERSE_HEIGHT
  heat_step = HEAT_STEP
  heat_top = HEAT_TOP
  hot_speed = HOT_SPEED

  # A `while` loop rather than `each`, for the same reason the engine's own
  # hot paths use one: on the wasm build every block call costs a method
  # dispatch, and at 5,000 motes a frame those add up to milliseconds.
  i = 0
  count = motes.size
  while i < count
    m = motes[i]
    i += 1
    d = m.dot
    x = d.x
    y = d.y

    ex = x - center_x
    ey = y - center_y
    r2 = ex * ex + ey * ey
    k = core_pull / (r2 + softening2)
    ax = -ex * k
    ay = -ey * k

    if grip > 0.01
      dx = cursor_x - x
      dy = cursor_y - y
      k = pull * m.depth / (dx * dx + dy * dy + softening2)
      ax += dx * k
      ay += dy * k
    end

    vx = m.vx + ax * dt
    vy = m.vy + ay * dt

    # Dust discs circularize — dissipation bleeds off whatever isn't a
    # circular orbit, which is how real protoplanetary discs flatten out — so
    # each mote is eased toward the circular velocity for the radius it is at,
    # plus a nudge back toward the radius it was seeded on. On an undisturbed
    # orbit the mote already *is* the target, leaving gravity alone to hold
    # it. Damping the speed alone is not enough: the cursor arrives pulling
    # motes radially, and a radial velocity carries no angular momentum, so
    # clamping only the magnitude sinks the whole disc into the core.
    r = Math.sqrt(r2)
    if r > 1
      ux = ex / r
      uy = ey / r
      radial = (m.home - r) * heal
      vx += (ux * radial - uy * orbit_speed - vx) * relax
      vy += (uy * radial + ux * orbit_speed - vy) * relax
    end

    m.vx = vx
    m.vy = vy
    d.x = (x + vx * dt) % universe_width
    d.y = (y + vy * dt) % universe_height

    # Color follows speed, quantized to HEAT_LEVELS steps — 24 is finer than
    # the eye can pick out on a 3px dot. Recoloring rebuilds the native color
    # cache, so it only happens when a mote crosses a step, and the test for
    # that compares *squared* speed against the step's squared bounds. Most
    # motes stay in their step from one frame to the next, so most of them
    # skip the square root as well.
    lvl = m.level
    lo = lvl * heat_step
    hi = lo + heat_step
    speed2 = vx * vx + vy * vy
    next unless speed2 < lo * lo || (speed2 >= hi * hi && lvl < heat_top)

    t = Math.sqrt(speed2) / hot_speed
    t = 1.0 if t > 1.0
    level = (t * heat_top).to_i
    if level != lvl
      m.level = level
      heat(d.color, level.to_f / heat_top)
    end
  end

  shocks.each do |s|
    next if s.age >= SHOCK_LIFE

    s.age += dt
    t = s.age / SHOCK_LIFE
    if t >= 1.0
      s.ring.visible = false
    else
      # Ease out: the ring sprints away from the click and coasts to a stop.
      s.ring.radius = SHOCK_RADIUS * (1 - (1 - t) * (1 - t))
      s.ring.opacity = 0.7 * (1 - t)
      s.ring.visible = true
    end
  end
end

show
