# Hill driver
# Drive across rolling hills, catch air off the crests, and grab fuel cans
# before you run dry.
#
# Right/RT accelerates, left/LT brakes or reverses, hold accelerate with space
# (or X) to turbo-boost, and up/down or left stick tilts the car while
# airborne. Press `r` (or Start) to restart.

require 'ruby2d'

# === Tunables ===

WIDTH = 900                # window width in pixels
HEIGHT = 540               # window height in pixels
WORLD_W = 12600            # total world width in pixels
FINISH_X = WORLD_W - 360   # finish flag x, set inside the world edge so the
                           # camera can scroll past it and frame the whole flag
GROUND_BASE = 380          # mean ground y in world space (px)
HILL_AMP1 = 92             # primary hill amplitude (px)
HILL_FREQ1 = 0.0042        # primary hill frequency (rad/px)
HILL_AMP2 = 34             # secondary hill amplitude (px)
HILL_FREQ2 = 0.0119        # secondary hill frequency (rad/px)
HILL_PHASE2 = 1.7          # secondary hill phase offset (rad)
GRAVITY = 1900             # downward acceleration (px/sec²)
ENGINE = 860               # forward thrust along slope (px/sec²)
TURBO_ENGINE = 1500        # extra forward thrust while turbo-boosting (px/sec²)
BRAKE = 1300               # opposing force when pressing left (px/sec²)
REVERSE_MAX = 240          # cap on reverse speed (px/sec)
ROLL_FRICTION = 0.42       # rolling drag rate while grounded (per-sec)
AIR_DRAG = 0.08            # horizontal drag while airborne (per-sec)
TILT_TORQUE = 7.5          # angular accel from tilt input (rad/sec²)
TILT_DAMP = 1.4            # angular velocity damping in air (per-sec)
GROUND_ALIGN = 16.0        # angle ease rate toward slope when grounded (per-sec)
WHEEL_RADIUS = 13          # wheel radius (px)
CHASSIS_W = 60             # chassis width (px)
CHASSIS_H = 18             # chassis height (px)
WHEEL_DX = 21              # half-distance between wheels (px)
WHEEL_DY = 10              # wheel y offset below chassis center (px)
CAMERA_SMOOTHING = 5.5     # camera lerp toward car (per-sec)
START_FUEL = 12.0          # starting fuel (seconds of throttle)
MAX_FUEL = 20.0            # fuel tank cap (sec)
CAN_FUEL = 4.0             # fuel granted per can (sec)
CAN_SPACING = 560          # world-space gap between fuel cans (px)
ENGINE_FUEL = 1.5          # fuel burn rate while accelerating (per-sec)
TURBO_FUEL = 3.5           # fuel burn rate while turbo-boosting (per-sec)
TERRAIN_STEP = 14          # column spacing when rendering hills (px)
GRASS_THICK = 34           # depth of the green grass band above the soil (px)
CAN_HOVER = 22             # height a fuel can floats above the ground (px)
SPARK_LIFE = 0.55          # fuel-can pickup spark lifetime (sec)
EMBER_LIFE = 0.22          # turbo exhaust ember lifetime (sec)
FUEL_FLASH = 0.35          # fuel-bar flash duration on pickup (sec)
PX_PER_M = 12              # world px shown as one meter in the HUD

# Daytime sky, sun, and clouds. The sky, sun, and clouds are static backdrop
# objects living behind the HUD; the world scrolls past in the render block.
SKY_TOP = '#4a9fe0'        # sky color at the top of the window
SKY_HORIZON = '#cfeafc'    # sky color near the horizon
SUN_X = WIDTH - 130        # sun center x (screen space)
SUN_Y = 96                 # sun center y (screen space)
CLOUDS = [                 # [x, y (screen), scale]
  [130, 78, 1.0], [360, 132, 0.7], [560, 62, 1.2],
  [740, 112, 0.9], [850, 156, 0.6]
].freeze

GROUND_OFFSET = WHEEL_RADIUS + WHEEL_DY  # distance from chassis center down to wheel bottom

# === Window ===

set title: 'Ruby 2D ▸ Examples ▸ Hill driver',
    width: WIDTH, height: HEIGHT, background: SKY_HORIZON
set close_on_esc: true

# === Helpers ===

# Smooth procedural terrain as a sum of two sines. `terrain_y` returns the
# ground y in world space; `terrain_slope` is its analytic derivative dy/dx.

def terrain_y(x)
  GROUND_BASE +
    HILL_AMP1 * Math.sin(x * HILL_FREQ1) +
    HILL_AMP2 * Math.sin(x * HILL_FREQ2 + HILL_PHASE2)
end

def terrain_slope(x)
  HILL_AMP1 * HILL_FREQ1 * Math.cos(x * HILL_FREQ1) +
    HILL_AMP2 * HILL_FREQ2 * Math.cos(x * HILL_FREQ2 + HILL_PHASE2)
end

# A soft cloud: four overlapping white puffs, added to the scene graph at low
# z so the HUD stays on top of it.

def build_cloud(cx, cy, s)
  white = [1.0, 1.0, 1.0, 0.92]
  Circle.new(x: cx,          y: cy,          radius: 26 * s, color: white, z: 1)
  Circle.new(x: cx - 30 * s, y: cy + 8 * s,  radius: 20 * s, color: white, z: 1)
  Circle.new(x: cx + 32 * s, y: cy + 6 * s,  radius: 22 * s, color: white, z: 1)
  Circle.new(x: cx + 4 * s,  y: cy + 14 * s, radius: 24 * s, color: white, z: 1)
end

# A little amber jerry can — body, top handle, spout, and a highlight — sitting
# above a soft ground shadow. `sx`/`sy` are its screen position; the can floats
# CAN_HOVER above the ground, so the shadow drops to `sy + CAN_HOVER`. `gslope`
# is the ground slope under the can, used to rotate the shadow onto the hill.

def draw_can(sx, sy, gslope)
  gy = sy + CAN_HOVER          # ground surface just below the can
  Ellipse.render(x: sx, y: gy, xradius: 9, yradius: 3,
                 rotate: Math.atan(gslope) * 180.0 / Math::PI,
                 color: [0.0, 0.0, 0.0, 0.14])
  Rectangle.render(x: sx - 8, y: sy - 20, width: 16, height: 22, color: '#f2b01e')
  Rectangle.render(x: sx - 4, y: sy - 16, width: 9,  height: 14, color: '#ffd257')
  Rectangle.render(x: sx - 7, y: sy - 24, width: 14, height: 4,  color: '#a16207')
  Rectangle.render(x: sx + 3, y: sy - 27, width: 4,  height: 4,  color: '#a16207')
  Line.render(x1: sx - 2, y1: sy - 3, x2: sx + 2, y2: sy - 14,
              stroke_width: 2, color: [1.0, 1.0, 1.0, 0.5])
end

# === Level ===

can_data = []
can_x = 360
while can_x <= FINISH_X - 260
  can_data << [can_x, terrain_y(can_x) - CAN_HOVER]
  can_x += CAN_SPACING
end

# === Backdrop ===
#
# Static sky, sun, and clouds at z:0-1. The scrolling world renders at z:10 and
# the HUD at z:19-21, so the three layers stack backdrop → world → HUD.

Quad.new(x1: 0, y1: 0, x2: WIDTH, y2: 0, x3: WIDTH, y3: HEIGHT, x4: 0, y4: HEIGHT,
         color: [SKY_TOP, SKY_TOP, SKY_HORIZON, SKY_HORIZON], z: 0)

Circle.new(x: SUN_X, y: SUN_Y, radius: 62, color: [1.0, 0.95, 0.7, 0.18], z: 0)
Circle.new(x: SUN_X, y: SUN_Y, radius: 42, color: [1.0, 0.96, 0.75, 0.28], z: 0)
Circle.new(x: SUN_X, y: SUN_Y, radius: 30, color: '#fff2b0', z: 0)

CLOUDS.each { |cx, cy, s| build_cloud(cx, cy, s) }

# === HUD ===

fuel_label = Text.new('', x: 16, y: 12, size: 16, color: '#1e293b', z: 20)
score_label = Text.new('', x: 16, y: 34, size: 16, color: '#1e293b', z: 20)
Rectangle.new(x: 16, y: 60, width: 220, height: 8, color: '#1e293b', z: 19)
fuel_bar = Rectangle.new(x: 16, y: 60, width: 0, height: 8, color: '#fbbf24', z: 20)
dist_label = Text.new('', x: WIDTH - 128, y: 12, size: 16, color: '#1e293b', z: 20)

# End-of-run banner — hidden until the run finishes. `x: :center` re-resolves
# against the live viewport, and the dark panel keeps the text readable over
# the bright daytime scene.
banner_panel = Rectangle.new(x: 0, y: HEIGHT / 2 - 68, width: WIDTH, height: 136,
                             color: [0.05, 0.07, 0.11, 0.55], z: 20, visible: false)
banner_title = Text.new('', x: :center, y: HEIGHT / 2 - 52, size: 40,
                        color: '#fde047', z: 21, visible: false)
banner_subtitle = Text.new('Press R to restart', x: :center, y: HEIGHT / 2 + 8,
                           size: 20, color: '#f8fafc', z: 21, visible: false)

# === Mutable state ===

world_x = 80.0
world_y = 0.0
vx = 0.0
vy = 0.0
angle = 0.0
ang_vel = 0.0
wheel_spin = 0.0
on_ground = true
gas = false
brake = false
turbo = false
tilt = 0
# Effective inputs, recombined each frame from the keyboard latches above and
# the live gamepad (see the top of `update`). Declared here so both `update`
# and `render` close over the same variables.
accel = false
braking = false
boosting = false
tilt_dir = 0
camera_x = 0.0
camera_y = 0.0
fuel = START_FUEL
score = 0
sparks = []
embers = []
fuel_flash = 0.0
can_collected = Array.new(can_data.length, false)
finished = false

reset = lambda do
  world_x = 80.0
  world_y = terrain_y(80.0) - GROUND_OFFSET
  vx = 0.0; vy = 0.0
  angle = Math.atan(terrain_slope(80.0))
  ang_vel = 0.0
  wheel_spin = 0.0
  on_ground = true
  gas = false; brake = false; turbo = false; tilt = 0
  fuel = START_FUEL
  score = 0
  sparks.clear
  embers.clear
  fuel_flash = 0.0
  can_collected.fill(false)
  finished = false
  banner_panel.hide
  banner_title.hide
  banner_subtitle.hide
  dist_label.show
end
reset.call

# End the run and raise the banner. Closes over the locals above, so assigning
# `finished` here flips the same flag the update loop reads.
finish_with = lambda do |message|
  finished = true
  banner_title.content = message
  banner_panel.show
  banner_title.show
  banner_subtitle.show
  dist_label.hide
end

# === Input ===

on :key_down do |event|
  case event.key
  when :right then gas = true
  when :left then brake = true
  when :up then tilt = -1
  when :down then tilt = 1
  when :space then turbo = true
  when :r then reset.call
  end
end

on :key_up do |event|
  case event.key
  when :right then gas = false
  when :left then brake = false
  when :up, :down then tilt = 0
  when :space then turbo = false
  end
end

on gamepad_button_down: :start do
  reset.call
end

# === Per-frame update ===
#
# Velocity is in world space (px/sec). When grounded, engine, turbo, and brake
# push along the surface tangent so thrust climbs hills naturally; gravity is
# left to act in world space and is handled by the ground-clamp step below.
# When airborne the car free-flies and the up/down keys spin it via `ang_vel`.

update do |dt|
  # Combine the keyboard latches (set by key events) with the live gamepad
  # state each frame, so releasing a gamepad control actually stops the action.
  accel    = gas
  braking  = brake
  boosting = turbo
  tilt_dir = tilt
  gamepads.each do |pad|
    accel    ||= pad.axis(:right_trigger) > 0.1 || pad.held?(:south) || pad.held?(:dpad_right)
    braking  ||= pad.axis(:left_trigger)  > 0.1 || pad.held?(:dpad_left)
    boosting ||= pad.held?(:west)
    if tilt_dir.zero?
      ly = pad.axis(:left_y)
      tilt_dir = -1 if ly < -0.3 || pad.held?(:dpad_up)
      tilt_dir =  1 if ly >  0.3 || pad.held?(:dpad_down)
    end
  end

  vy += GRAVITY * dt

  if on_ground
    slope = terrain_slope(world_x)
    inv_len = 1.0 / Math.sqrt(1 + slope * slope)
    tx = inv_len
    ty = slope * inv_len

    if accel && fuel.positive?
      vx += ENGINE * tx * dt
      vy += ENGINE * ty * dt
      fuel -= ENGINE_FUEL * dt
    end

    # Turbo: a hard forward shove along the slope, but only while accelerating
    # and grounded — the wheels need traction. Held on its own it's like
    # neutral: it still burns fuel and flares the exhaust (handled after the
    # branch), just without driving the car.
    if boosting && accel && fuel.positive?
      vx += TURBO_ENGINE * tx * dt
      vy += TURBO_ENGINE * ty * dt
    end

    if braking
      forward = vx * tx + vy * ty
      if forward > -REVERSE_MAX
        vx -= BRAKE * tx * dt
        vy -= BRAKE * ty * dt
      end
    end

    # Collapse velocity onto the tangent every frame so the gravity we just
    # added acts as the standard "along-slope" component, and the normal
    # component (which would otherwise drive the car through the ground) is
    # cancelled by the ground-clamp below.
    v_t = vx * tx + vy * ty
    vx = v_t * tx
    vy = v_t * ty

    drag = Math.exp(-ROLL_FRICTION * dt)
    vx *= drag; vy *= drag

    target = Math.atan(slope)
    a = 1 - Math.exp(-GROUND_ALIGN * dt)
    angle += (target - angle) * a
    ang_vel = 0.0
  else
    vx *= Math.exp(-AIR_DRAG * dt)
    ang_vel += TILT_TORQUE * tilt_dir * dt
    ang_vel *= Math.exp(-TILT_DAMP * dt)
    angle += ang_vel * dt
  end

  # Turbo burns fuel fast and throws embers out the tailpipe, grounded or not.
  if boosting && fuel.positive?
    fuel -= TURBO_FUEL * dt
    pipe = -(CHASSIS_W / 2.0 + 4)
    exx = world_x + pipe * Math.cos(angle)
    exy = world_y + pipe * Math.sin(angle)
    3.times do
      dir = angle + Math::PI + (rand - 0.5) * 0.3
      spd = 250 + rand * 150
      embers << [exx, exy, Math.cos(dir) * spd, Math.sin(dir) * spd, EMBER_LIFE * (0.6 + rand * 0.4)]
    end
  end

  world_x += vx * dt
  world_y += vy * dt

  # Wheel-spin visual: arc length along chassis-forward direction over radius.
  forward_speed = vx * Math.cos(angle) + vy * Math.sin(angle)
  wheel_spin += forward_speed / WHEEL_RADIUS * dt

  # Ground-clamp: if the chassis center is below the local ground line, snap
  # to the surface and project velocity onto the tangent (kill normal motion).
  ground_y = terrain_y(world_x) - GROUND_OFFSET
  if world_y >= ground_y
    if !on_ground
      slope = terrain_slope(world_x)
      inv_len = 1.0 / Math.sqrt(1 + slope * slope)
      tx = inv_len; ty = slope * inv_len
      v_t = vx * tx + vy * ty
      vx = v_t * tx
      vy = v_t * ty
      ang_vel = 0.0
    end
    on_ground = true
    world_y = ground_y
  else
    on_ground = false
  end

  # World edges keep the car in the level; crossing the finish line raises the
  # banner once but leaves the car free to keep driving around.
  if world_x < 40
    world_x = 40
    vx = 0 if vx < 0
  elsif world_x > WORLD_W - 40
    world_x = WORLD_W - 40
    vx = 0 if vx > 0
  end
  finish_with.call('You reached the end!') if !finished && world_x >= FINISH_X

  # Camera leads slightly in the direction of travel; the tall lower bound
  # leaves headroom to follow the car through a big jump.
  target_cx = (world_x - WIDTH * 0.4 + vx * 0.25).clamp(0, WORLD_W - WIDTH)
  target_cy = (world_y - HEIGHT * 0.65).clamp(GROUND_BASE - HEIGHT * 1.15, GROUND_BASE - HEIGHT * 0.4)
  smooth = 1 - Math.exp(-CAMERA_SMOOTHING * dt)
  camera_x += (target_cx - camera_x) * smooth
  camera_y += (target_cy - camera_y) * smooth

  # Can pickups (cheap AABB-ish radius check around the chassis). Each grab
  # tops up fuel, flashes the bar, and throws a little burst of sparks.
  can_data.each_with_index do |(cx, cy), i|
    next if can_collected[i]
    if (cx - world_x).abs < 22 && (cy - world_y).abs < 28
      can_collected[i] = true
      score += 1
      fuel = [fuel + CAN_FUEL, MAX_FUEL].min
      fuel_flash = FUEL_FLASH
      10.times do
        a = rand * Math::PI * 2
        spd = 70 + rand * 150
        sparks << [cx, cy, Math.cos(a) * spd, Math.sin(a) * spd - 50, SPARK_LIFE]
      end
    end
  end

  # Advance and expire pickup sparks; a little gravity pulls them back down.
  sparks.each do |s|
    s[4] -= dt
    s[0] += s[2] * dt
    s[1] += s[3] * dt
    s[3] += 320 * dt
  end
  sparks.reject! { |s| s[4] <= 0 }

  # Advance turbo exhaust embers — heavy drag on both axes so they shoot
  # straight out of the pipe and snuff quickly instead of trailing away.
  embers.each do |e|
    e[4] -= dt
    e[0] += e[2] * dt
    e[1] += e[3] * dt
    e[2] *= Math.exp(-7.0 * dt)
    e[3] *= Math.exp(-7.0 * dt)
  end
  embers.reject! { |e| e[4] <= 0 }

  # Fade the fuel bar from a white flash back to its amber (#fbbf24).
  if fuel_flash > 0
    fuel_flash -= dt
    t = (fuel_flash / FUEL_FLASH).clamp(0.0, 1.0)
    fuel_bar.color.r = 0.984 + (1 - 0.984) * t
    fuel_bar.color.g = 0.749 + (1 - 0.749) * t
    fuel_bar.color.b = 0.141 + (1 - 0.141) * t
  end

  if fuel <= 0
    fuel = 0
    if !finished && on_ground && vx.abs < 6 && vy.abs < 6
      finish_with.call('Out of fuel!')
    end
  end

  fuel_text = "Fuel: #{format('%.1f', fuel)}s"
  fuel_label.content = fuel_text unless fuel_label.content == fuel_text
  score_text = "Cans: #{score} / #{can_data.length}"
  score_label.content = score_text unless score_label.content == score_text
  fuel_bar.width = (220 * fuel / MAX_FUEL).clamp(0, 220)

  # Distance to the flag, right-aligned so the number can grow without shifting.
  dist_m = [((FINISH_X - world_x) / PX_PER_M).round, 0].max
  dist_text = "#{dist_m}m to go"
  if dist_label.content != dist_text
    dist_label.content = dist_text
    dist_label.x = WIDTH - dist_label.width - 16
  end
end

# === Render ===

render z: 10 do
  # Farthest hazy mountains — very slow parallax, tinted toward the sky.
  mtn_step = 80
  sx = -mtn_step
  while sx <= WIDTH + mtn_step
    wx = sx + camera_x * 0.2
    m1 = 48 * Math.sin(wx * 0.0016) + 24 * Math.sin(wx * 0.0037 + 2.1)
    m2 = 48 * Math.sin((wx + mtn_step) * 0.0016) + 24 * Math.sin((wx + mtn_step) * 0.0037 + 2.1)
    y1 = GROUND_BASE - 120 + m1 - camera_y * 0.25
    y2 = GROUND_BASE - 120 + m2 - camera_y * 0.25
    Quad.render(x1: sx, y1: y1, x2: sx + mtn_step, y2: y2,
                x3: sx + mtn_step, y3: HEIGHT, x4: sx, y4: HEIGHT,
                color: '#aec7d1')
    sx += mtn_step
  end

  # Nearer parallax hills, hazed toward the sky for depth.
  far_step = 60
  sx = -far_step
  while sx <= WIDTH + far_step
    wx = sx + camera_x * 0.4
    h1 = HILL_AMP1 * 1.4 * Math.sin(wx * HILL_FREQ1 * 0.55) + 40
    y1 = GROUND_BASE - 80 + h1 - camera_y * 0.45
    h2 = HILL_AMP1 * 1.4 * Math.sin((wx + far_step) * HILL_FREQ1 * 0.55) + 40
    y2 = GROUND_BASE - 80 + h2 - camera_y * 0.45
    Quad.render(x1: sx, y1: y1, x2: sx + far_step, y2: y2,
                x3: sx + far_step, y3: HEIGHT, x4: sx, y4: HEIGHT,
                color: '#8fb996')
    sx += far_step
  end

  # Main terrain — a strip of trapezoids from the surface to the bottom of the
  # window: a green grass band along the top, then soil shading from topsoil to
  # a darker subsoil below. Sample one step beyond the viewport on each side so
  # edges don't clip as the camera moves between frames.
  start_x = ((camera_x / TERRAIN_STEP).floor - 1) * TERRAIN_STEP
  end_x = start_x + WIDTH + TERRAIN_STEP * 2
  x = start_x
  while x <= end_x
    y1 = terrain_y(x) - camera_y
    y2 = terrain_y(x + TERRAIN_STEP) - camera_y
    sx1 = x - camera_x
    sx2 = x + TERRAIN_STEP - camera_x
    Quad.render(x1: sx1, y1: y1, x2: sx2, y2: y2,
                x3: sx2, y3: y2 + GRASS_THICK, x4: sx1, y4: y1 + GRASS_THICK,
                color: '#4d9e3f')
    Quad.render(x1: sx1, y1: y1 + GRASS_THICK, x2: sx2, y2: y2 + GRASS_THICK,
                x3: sx2, y3: HEIGHT, x4: sx1, y4: HEIGHT,
                color: ['#6b4a2f', '#6b4a2f', '#3f2d1d', '#3f2d1d'])
    Line.render(x1: sx1, y1: y1, x2: sx2, y2: y2, stroke_width: 3, color: '#86d95c')
    x += TERRAIN_STEP
  end

  # Checkered finish flag on a pole at the end of the world.
  fsx = FINISH_X - camera_x
  if fsx > -80 && fsx < WIDTH + 80
    fy = terrain_y(FINISH_X) - camera_y
    ftop = fy - 130
    Rectangle.render(x: fsx - 2, y: ftop, width: 4, height: fy - ftop, color: '#475569')
    cell = 11
    4.times do |r|
      6.times do |c|
        shade = (r + c).even? ? '#f8fafc' : '#111827'
        Rectangle.render(x: fsx + 2 + c * cell, y: ftop + r * cell,
                         width: cell, height: cell, color: shade)
      end
    end
  end

  # Cans.
  can_data.each_with_index do |(cx, cy), i|
    next if can_collected[i]
    draw_can(cx - camera_x, cy - camera_y, terrain_slope(cx))
  end

  # Turbo exhaust embers glowing just behind the tailpipe.
  embers.each do |ex, ey, _evx, _evy, elife|
    a = (elife / EMBER_LIFE).clamp(0.0, 1.0)
    Circle.render(x: ex - camera_x, y: ey - camera_y, radius: 1.0 + a * 2.0,
                  color: [1.0, 0.5 + a * 0.35, 0.15, a])
  end

  # Car. Build local-space points then rotate by `angle` and translate to
  # the screen. Local origin is the chassis center; +y is "down" in body
  # space, which lines up with screen y after rotation.
  cos_a = Math.cos(angle)
  sin_a = Math.sin(angle)
  cx = world_x - camera_x
  cy = world_y - camera_y
  to_screen = ->(lx, ly) { [cx + lx * cos_a - ly * sin_a, cy + lx * sin_a + ly * cos_a] }

  # Soft contact shadow on the ground below the car — a flattened ellipse
  # rotated onto the local ground slope so it hugs the hill instead of lying
  # flat. Shrinks and fades as the car gains air.
  ground_sy = terrain_y(world_x) - camera_y
  air = (terrain_y(world_x) - GROUND_OFFSET) - world_y
  sh = (1 - air / 300.0).clamp(0.15, 1.0)
  slope_deg = Math.atan(terrain_slope(world_x)) * 180.0 / Math::PI
  Ellipse.render(x: cx, y: ground_sy, xradius: CHASSIS_W * 0.62 * sh, yradius: 5 * sh,
                 rotate: slope_deg, color: [0.0, 0.0, 0.0, 0.20 * sh])

  hw = CHASSIS_W / 2.0
  hh = CHASSIS_H / 2.0

  # Turbo flame or a light exhaust puff out the tailpipe (behind the chassis).
  if boosting && fuel.positive?
    flick = 14 + rand * 8
    b1 = to_screen.call(-hw - 3, -5)
    b2 = to_screen.call(-hw - 3, 5)
    tip = to_screen.call(-hw - 3 - flick, (rand - 0.5) * 3)
    Triangle.render(x1: b1[0], y1: b1[1], x2: b2[0], y2: b2[1], x3: tip[0], y3: tip[1],
                    color: ['#f97316', '#f97316', '#fca311'])
    b3 = to_screen.call(-hw - 3, -2.5)
    b4 = to_screen.call(-hw - 3, 2.5)
    tip2 = to_screen.call(-hw - 3 - flick * 0.6, (rand - 0.5) * 2)
    Triangle.render(x1: b3[0], y1: b3[1], x2: b4[0], y2: b4[1], x3: tip2[0], y3: tip2[1],
                    color: ['#fde047', '#fde047', '#fff7cc'])
  elsif accel && fuel.positive?
    puff = to_screen.call(-hw - 6, 0)
    r = 4 + rand * 3
    Circle.render(x: puff[0] + rand(-2..2), y: puff[1] + rand(-2..2),
                  radius: r, color: [0.32, 0.34, 0.38, 0.5])
  end

  c1 = to_screen.call(-hw, -hh)
  c2 = to_screen.call(hw, -hh)
  c3 = to_screen.call(hw, hh)
  c4 = to_screen.call(-hw, hh)
  Quad.render(x1: c1[0], y1: c1[1], x2: c2[0], y2: c2[1],
              x3: c3[0], y3: c3[1], x4: c4[0], y4: c4[1],
              color: '#e63946')

  cab1 = to_screen.call(-12, -hh)
  cab2 = to_screen.call(18, -hh)
  cab3 = to_screen.call(12, -hh - 14)
  cab4 = to_screen.call(-6, -hh - 14)
  Quad.render(x1: cab1[0], y1: cab1[1], x2: cab2[0], y2: cab2[1],
              x3: cab3[0], y3: cab3[1], x4: cab4[0], y4: cab4[1],
              color: '#bde0fe')

  [-WHEEL_DX, WHEEL_DX].each do |wx|
    pos = to_screen.call(wx, WHEEL_DY)
    Circle.render(x: pos[0], y: pos[1], radius: WHEEL_RADIUS, color: '#0f172a')
    Circle.render(x: pos[0], y: pos[1], radius: WHEEL_RADIUS - 4, color: '#475569')
    sx2 = pos[0] + Math.cos(angle + wheel_spin) * (WHEEL_RADIUS - 2)
    sy2 = pos[1] + Math.sin(angle + wheel_spin) * (WHEEL_RADIUS - 2)
    Line.render(x1: pos[0], y1: pos[1], x2: sx2, y2: sy2, stroke_width: 2, color: '#cbd5e1')
  end

  # Fuel-can pickup sparks, brightest when freshly spawned.
  sparks.each do |px, py, _pvx, _pvy, life|
    a = (life / SPARK_LIFE).clamp(0.0, 1.0)
    Circle.render(x: px - camera_x, y: py - camera_y, radius: 1.5 + a * 2.5,
                  color: [1.0, 0.93, 0.5, a])
  end
end

show
