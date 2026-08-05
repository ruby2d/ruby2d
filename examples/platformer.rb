# Platformer playground
# A tiny side-scrolling platformer scene built from Ruby 2D shapes.
#
# Use left/right (or the gamepad dpad) to run, space/up (or the south
# button) to jump, and press `r` to return to the start.

require 'ruby2d'

# === Tunables ===

WIDTH = 800              # window width in pixels
HEIGHT = 600             # window height in pixels
GROUND_Y = 540           # y of the ground strip in world space
WORLD_W = 1600           # total world width in pixels
GRAVITY = 1980           # downward acceleration (px/sec²)
RUN_ACCEL = 2520         # horizontal acceleration while pressing left/right (px/sec²)
FRICTION = 11.9          # horizontal decay rate when no input (per-sec; vx *= exp(-FRICTION * dt))
JUMP_V = -750            # initial jump velocity (px/sec, negative is up)
MAX_SPEED = 420          # horizontal speed cap (px/sec)
CAMERA_SMOOTHING = 7.67  # camera ease rate toward the player (per-sec)
GEM_BOB_AMP = 6          # how far gems bob up and down (px)
GEM_BOB_RATE = 2.6       # gem bob speed (rad/sec)

# Daytime sky and earthy world colors.
SKY_TOP = '#38a9f4'      # sky at the top of the window
SKY_HORIZON = '#c4ecfe'  # sky near the horizon
SUN_X = WIDTH - 120      # sun center x (screen space)
SUN_Y = 96               # sun center y (screen space)
HILL_FAR = '#a7ccd8'     # hazy far hills
HILL_NEAR = '#8bbf86'    # green near hills
CLOUD = [1.0, 1.0, 1.0, 0.9]
DIRT = '#7a5334'         # ground fill
GRASS = '#4d9e3f'        # grass band and platform caps
GRASS_CAP = '#86d95c'    # bright grass highlight line

# === Window ===

set title: 'Ruby 2D ▸ Examples ▸ Platformer playground', width: WIDTH, height: HEIGHT, background: SKY_HORIZON
set close_on_esc: true

# === Game-object structs ===

Box = Struct.new(:x, :y, :width, :height)

def rects_overlap?(a, b)
  a.x < b.x + b.width && a.x + a.width > b.x &&
    a.y < b.y + b.height && a.y + a.height > b.y
end

# Build a red diamond gem at (x, y) — trapezoidal crown + triangular
# pavilion + lighter facet. Shared by the playfield gems and the HUD icon.
def build_gem(x, y, z: 0)
  crown = Quad.new(
    x1: x - 8,  y1: y - 10,
    x2: x + 8,  y2: y - 10,
    x3: x + 14, y3: y - 4,
    x4: x - 14, y4: y - 4,
    color: '#dc2626', z: z
  )
  pavilion = Triangle.new(
    x1: x - 14, y1: y - 4,
    x2: x + 14, y2: y - 4,
    x3: x,      y3: y + 10,
    color: '#dc2626', z: z
  )
  facet = Triangle.new(
    x1: x - 8,  y1: y - 10,
    x2: x,      y2: y - 4,
    x3: x - 14, y3: y - 4,
    color: '#fca5a5', z: z
  )
  [crown, pavilion, facet]
end

# Four overlapping white puffs make a soft cloud, returned as a list so the
# parallax loop can scroll each puff.
def cloud_puffs(cx, cy, s)
  [
    Circle.new(x: cx,          y: cy,          radius: 24 * s, color: CLOUD, z: -35),
    Circle.new(x: cx - 26 * s, y: cy + 7 * s,  radius: 17 * s, color: CLOUD, z: -35),
    Circle.new(x: cx + 28 * s, y: cy + 5 * s,  radius: 19 * s, color: CLOUD, z: -35),
    Circle.new(x: cx + 2 * s,  y: cy + 11 * s, radius: 20 * s, color: CLOUD, z: -35)
  ]
end

# === Backdrop ===
#
# A gradient sky and a soft sun sit still; clouds and two rows of rounded hills
# scroll at a fraction of the camera speed for a parallax sense of depth. Each
# scrolling piece is stored as `[shape, base_x, factor]`. Everything lives at
# negative z, behind the playfield.

Quad.new(x1: 0, y1: 0, x2: WIDTH, y2: 0, x3: WIDTH, y3: HEIGHT, x4: 0, y4: HEIGHT,
         color: [SKY_TOP, SKY_TOP, SKY_HORIZON, SKY_HORIZON], z: -40)

Circle.new(x: SUN_X, y: SUN_Y, radius: 60, color: [1.0, 0.95, 0.7, 0.16], z: -39)
Circle.new(x: SUN_X, y: SUN_Y, radius: 40, color: [1.0, 0.96, 0.75, 0.26], z: -39)
Circle.new(x: SUN_X, y: SUN_Y, radius: 28, color: '#fff2b0', z: -39)

parallax = []

[[150, 90, 1.0], [430, 128, 0.7], [660, 72, 1.1], [980, 116, 0.85]].each do |cx, cy, s|
  cloud_puffs(cx, cy, s).each { |c| parallax << [c, c.x, 0.1] }
end

# Far hazy hills (slow), then nearer green hills (faster) — big circles whose
# rounded tops peek above the ground.
[120, 480, 900, 1360, 1650].each do |hx|
  parallax << [Circle.new(x: hx, y: 560, radius: 160, color: HILL_FAR, z: -30), hx, 0.15]
end
[260, 700, 1120, 1520].each do |hx|
  parallax << [Circle.new(x: hx, y: 650, radius: 210, color: HILL_NEAR, z: -20), hx, 0.3]
end

# === Level ===

level_data = [
  [0, GROUND_Y, 1600, 60],
  [150, 455, 160, 24],
  [390, 390, 150, 24],
  [660, 450, 180, 24],
  [930, 350, 130, 24],
  [1160, 430, 180, 24],
  [1400, 300, 140, 24]
]

# The ground is a brown dirt rect with a grass band and a bright cap line on
# top; floating platforms are slate with a thin grass cap. `platforms[0]` is
# the ground and doubles as the collision floor.
platforms = level_data.map.with_index do |(x, y, w, h), i|
  Rectangle.new(x: x, y: y, width: w, height: h, color: i.zero? ? DIRT : '#a8a29e')
end
grass_strip = Rectangle.new(x: 0, y: GROUND_Y, width: WORLD_W, height: 16, color: GRASS, z: 1)
grass_cap = Rectangle.new(x: 0, y: GROUND_Y, width: WORLD_W, height: 3, color: GRASS_CAP, z: 1)
platform_caps = level_data.drop(1).map do |x, y, w, _h|
  Rectangle.new(x: x, y: y, width: w, height: 5, color: GRASS, z: 1)
end

# Highest platform top at or below `from_y` under world x `x`, defaulting to
# the ground. Used to drop gem and player shadows onto the right surface.
surface_below = lambda do |x, from_y|
  best = GROUND_Y
  level_data.each do |px, py, pw, _ph|
    best = [best, py].min if x >= px && x <= px + pw && py >= from_y - 1
  end
  best
end

# Red diamond gems — each stored as `[shape, world_x, world_y]` so the update
# loop can scroll and bob all parts together against the camera.
gem_data = [[220, 425], [460, 360], [1000, 320], [1465, 270]]
gems = gem_data.map do |x, y|
  build_gem(x, y, z: 3).map { |s| [s, s.x, s.y] }
end
gem_collected = Array.new(gems.length, false)

# A soft shadow on the surface under each gem; it shrinks as the gem bobs up.
gem_shadow_y = gem_data.map { |gx, gy| surface_below.call(gx, gy) }
gem_shadows = gem_data.map.with_index do |(gx, _gy), i|
  Ellipse.new(x: gx, y: gem_shadow_y[i], xradius: 12, yradius: 4,
              color: 'black', opacity: 0.18, z: 2)
end

# === Mutable state ===

player = Rectangle.new(x: 60, y: GROUND_Y - 42, width: 28, height: 42, color: '#1e3a8a', z: 4)
player_shadow = Ellipse.new(x: 0, y: 0, xradius: 16, yradius: 5, color: 'black', opacity: 0.24, z: 2)

# HUD: a red gem icon followed by a "× N" counter, Mario-64 style. Reuses
# `build_gem` so the icon and the playfield gems stay in lockstep.
hud_cx, hud_cy = 30, 26
build_gem(hud_cx, hud_cy, z: 10)
label = Text.new('× 0', x: hud_cx + 20, y: hud_cy - 14, size: 22, color: '#0f172a', z: 10)

player_world_x = 60.0
player_world_y = GROUND_Y - 42.0
vx = 0.0
vy = 0.0
left = false
right = false
on_ground = false
camera_x = 0.0
collected = 0
anim = 0.0

reset = lambda do
  player_world_x = 60.0
  player_world_y = GROUND_Y - 42.0
  vx = 0.0
  vy = 0.0
  collected = 0
  gem_collected.fill(false)
  gems.each { |parts| parts.each { |s, _, _| s.visible = true } }
  gem_shadows.each { |s| s.visible = true }
  label.content = '× 0'
end

# === Input ===

on key_down: :left do
  left = true
end

on key_down: :right do
  right = true
end

on key_up: :left do
  left = false
end

on key_up: :right do
  right = false
end

on key_down: %i[space up], gamepad_button_down: :south do
  if on_ground
    vy = JUMP_V
    on_ground = false
  end
end

on key_down: :r do
  reset.call
end

# === Per-frame update ===
#
# Ruby 2D calls this block once per rendered frame and passes `dt` — wall-clock
# seconds since the previous update. All rates below are in per-second units
# (velocities in px/sec, accelerations in px/sec², drag as a per-second decay
# rate `vx *= Math.exp(-rate * dt)`), so feel is identical at any refresh rate.

update do |dt|
  anim += dt

  # Combine keyboard with the dpad held state across all connected pads,
  # so either input runs the player and they don't fight each other.
  go_left  = left  || gamepads.any? { |p| p.held?(:dpad_left) }
  go_right = right || gamepads.any? { |p| p.held?(:dpad_right) }

  vx -= RUN_ACCEL * dt if go_left
  vx += RUN_ACCEL * dt if go_right
  vx *= Math.exp(-FRICTION * dt) unless go_left || go_right
  vx = vx.clamp(-MAX_SPEED, MAX_SPEED)
  vy += GRAVITY * dt

  player_world_x += vx * dt
  player_box = Box.new(player_world_x, player_world_y, player.width, player.height)
  level_data.each do |x, y, w, h|
    p = Box.new(x, y, w, h)
    next unless rects_overlap?(player_box, p)

    if vx > 0
      player_world_x = p.x - player.width
    elsif vx < 0
      player_world_x = p.x + p.width
    end
    vx = 0
    player_box.x = player_world_x
  end

  player_world_y += vy * dt
  player_box.x = player_world_x
  player_box.y = player_world_y
  on_ground = false
  level_data.each do |x, y, w, h|
    p = Box.new(x, y, w, h)
    next unless rects_overlap?(player_box, p)

    if vy > 0
      player_world_y = p.y - player.height
      on_ground = true
    elsif vy < 0
      player_world_y = p.y + p.height
    end
    vy = 0
    player_box.y = player_world_y
  end

  if player_world_y > HEIGHT + 80
    player_world_x = 60
    player_world_y = GROUND_Y - 42
    vx = 0
    vy = 0
  end

  player_world_x = player_world_x.clamp(0, WORLD_W - player.width)
  target_x = (player_world_x - WIDTH * 0.45).clamp(0, WORLD_W - WIDTH)
  camera_x += (target_x - camera_x) * (1 - Math.exp(-CAMERA_SMOOTHING * dt))

  # Parallax backdrop, then the ground, platforms, and their grass caps.
  parallax.each { |s, bx, f| s.x = bx - camera_x * f }
  platforms.each_with_index { |p, i| p.x = level_data[i][0] - camera_x }
  platform_caps.each_with_index { |c, i| c.x = level_data[i + 1][0] - camera_x }
  grass_strip.x = -camera_x
  grass_cap.x = -camera_x

  # Gems bob on a shared clock (each offset in phase); their shadows shrink as
  # they rise.
  gems.each_with_index do |parts, i|
    bob = Math.sin(anim * GEM_BOB_RATE + i * 1.3) * GEM_BOB_AMP
    parts.each { |s, wx, wy| s.x = wx - camera_x; s.y = wy + bob }
    unless gem_collected[i]
      sc = 1.0 + bob / 15.0
      gem_shadows[i].x = gem_data[i][0] - camera_x
      gem_shadows[i].xradius = 12 * sc
      gem_shadows[i].yradius = 4 * sc
    end
    next if gem_collected[i]

    if (gem_data[i][0] - player_world_x).abs < 28 && (gem_data[i][1] - player_world_y - 20).abs < 34
      gem_collected[i] = true
      parts.each { |s, _, _| s.visible = false }
      gem_shadows[i].visible = false
      collected += 1
      label.content = "× #{collected}"
    end
  end

  # Player drop shadow onto the surface below, shrinking and fading with height.
  feet = player_world_y + player.height
  surf = surface_below.call(player_world_x + player.width / 2.0, feet - 2)
  scale = (1.0 - (surf - feet) / 260.0).clamp(0.25, 1.0)
  player_shadow.x = player_world_x + player.width / 2.0 - camera_x
  player_shadow.y = surf
  player_shadow.xradius = 16 * scale
  player_shadow.yradius = 5 * scale
  player_shadow.opacity = 0.24 * scale

  player.x = player_world_x - camera_x
  player.y = player_world_y
end

show
