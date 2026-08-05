# Bouncing balls
# Colorful balls fall under gravity, losing a little energy with each impact.
#
# Twenty balls bounce off the walls and floor. Click to drop another
# ball, or click and hold to spray a continuous stream — the pile is
# capped so the oldest balls vanish to keep room. Press `r` to reset.

require 'ruby2d'

# === Tunables ===

WIDTH = 800              # window width in pixels
HEIGHT = 600             # window height in pixels
INITIAL_BALLS = 20       # balls present at startup
MAX_BALLS = 250          # cap; oldest balls are popped when exceeded
SPAWN_INTERVAL = 0.025   # seconds between spawns while the mouse is held
GRAVITY = 2160           # downward acceleration (px/sec²)
WALL_BOUNCE = 0.9        # horizontal velocity retained after wall bounce
FLOOR_BOUNCE = 0.85      # vertical velocity retained after floor bounce
FLOOR_FRICTION = 1.21    # horizontal velocity decay rate on floor contact (per-sec)

# === Window ===

set title: 'Ruby 2D ▸ Examples ▸ Bouncing balls', width: WIDTH, height: HEIGHT, background: '#0a0a23'
set close_on_esc: true

# === Ball struct and helpers ===

Ball = Struct.new(:shape, :vx, :vy)

def make_ball(x = nil, y = nil)
  r = 10 + rand(26)
  Ball.new(
    Circle.new(
      x: x || r + rand(WIDTH - r * 2),
      y: y || r + rand(200),
      radius: r,
      color: [rand * 0.6 + 0.4, rand * 0.6 + 0.4, rand * 0.6 + 0.4, 0.85]
    ),
    rand * 720 - 360,
    0.0
  )
end

def add_ball(balls, x, y)
  balls << make_ball(x, y)
  balls.shift.shape.remove while balls.size > MAX_BALLS
end

# === Mutable state ===

balls = Array.new(INITIAL_BALLS) { make_ball }

mouse_held = false
mouse_x = 0
mouse_y = 0
spawn_accum = 0.0  # seconds accumulated toward the next spawn while held

# === Input ===

on :mouse_down do |event|
  mouse_held = true
  mouse_x = event.x
  mouse_y = event.y
  add_ball(balls, mouse_x, mouse_y)
  spawn_accum = 0.0
end

on :mouse_up do
  mouse_held = false
end

on :mouse_move do |event|
  mouse_x = event.x
  mouse_y = event.y
end

on key_down: :r do
  balls.each { |b| b.shape.remove }
  balls.replace(Array.new(INITIAL_BALLS) { make_ball })
end

# === Per-frame update ===

update do |dt|
  if mouse_held
    spawn_accum += dt
    while spawn_accum >= SPAWN_INTERVAL
      spawn_accum -= SPAWN_INTERVAL
      add_ball(balls, mouse_x, mouse_y)
    end
  end

  balls.each do |b|
    s = b.shape
    b.vy += GRAVITY * dt
    s.x += b.vx * dt
    s.y += b.vy * dt

    if s.x - s.radius < 0
      s.x = s.radius
      b.vx = b.vx.abs * WALL_BOUNCE
    elsif s.x + s.radius > WIDTH
      s.x = WIDTH - s.radius
      b.vx = -b.vx.abs * WALL_BOUNCE
    end

    if s.y + s.radius > HEIGHT
      s.y = HEIGHT - s.radius
      b.vy = -b.vy.abs * FLOOR_BOUNCE
      b.vx *= Math.exp(-FLOOR_FRICTION * dt)
    elsif s.y - s.radius < 0
      s.y = s.radius
      b.vy = b.vy.abs
    end
  end
end

show
