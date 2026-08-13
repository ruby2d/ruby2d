# A fountain of bouncing balls, built with `ruby2d build --spinel`.
#
# `square.rb` shows that the target compiles a Ruby 2D script. This shows that
# it runs one: a scene that moves, spawns, collides and recycles for as long as
# you leave it open, at 60fps, from a single standalone binary.
#
#   RUBY2D_SPINEL=../spinel/bin/spinel ruby2d build --spinel spinel/examples/fountain.rb
#   ruby2d launch --native
#
# Close it with the window button or Cmd-Q.
#
# The physics is `examples/bouncing_balls.rb`'s. What differs is that this one
# has no input: an emitter sweeps the top of the window on a sine and sprays
# balls continuously, where the original waits for the mouse. That is not a
# stylistic choice — input does not work on this target yet (see README.md), so
# a demo that needed it would be a demo of nothing.
#
# The other difference is the ball pool. The original removes the oldest ball
# when the pile is capped; this one recycles it, resetting the same `Circle`
# back to the emitter. Removal reaches a `Hash#delete_if` the compiler refuses
# today, and recycling is the better answer anyway — the allocation count stops
# climbing the moment the pool fills.
#
# Everything else here is ordinary Ruby 2D, written the way the examples are.

require 'ruby2d'

# === Tunables ===

WIDTH = 800              # window width in pixels
HEIGHT = 600             # window height in pixels
# MAX_BALLS = 180          # pool size; the oldest ball is recycled once full
MAX_BALLS = 20000          # pool size; the oldest ball is recycled once full
# SPAWN_INTERVAL = 0.05    # seconds between spawns
SPAWN_INTERVAL = 0.001    # seconds between spawns
GRAVITY = 2160           # downward acceleration (px/sec²)
WALL_BOUNCE = 0.9        # horizontal velocity retained after wall bounce
FLOOR_BOUNCE = 0.85      # vertical velocity retained after floor bounce
# FLOOR_FRICTION = 1.21    # horizontal velocity decay rate on floor contact (per-sec)
FLOOR_FRICTION = 1.0    # horizontal velocity decay rate on floor contact (per-sec)

# EMITTER_Y = 25           # height the balls are sprayed from
EMITTER_Y = -50           # height the balls are sprayed from
EMITTER_SWING = 300      # how far the emitter travels either side of center
EMITTER_SPEED = 1.1      # sweep rate in radians/sec
EMITTER_SPREAD = 90      # random horizontal velocity added to each ball

# === Window ===

set title: 'Ruby 2D ▸ Spinel ▸ Fountain', width: WIDTH, height: HEIGHT, background: '#0a0a23'

# === Emitter ===

# Position and velocity of the emitter at time `t`. The velocity is the
# position's derivative, and handing it to each new ball is what makes the
# stream arc the way a swung hose does instead of falling straight down.
def emitter_x(t)
  WIDTH / 2.0 + Math.sin(t * EMITTER_SPEED) * EMITTER_SWING
end

def emitter_vx(t)
  Math.cos(t * EMITTER_SPEED) * EMITTER_SPEED * EMITTER_SWING
end

# === Ball pool ===

Ball = Struct.new(:shape, :vx, :vy)

def random_color
  [rand * 0.6 + 0.4, rand * 0.6 + 0.4, rand * 0.6 + 0.4, 0.85]
end

def spawn_vx(vx)
  vx + rand * EMITTER_SPREAD * 2 - EMITTER_SPREAD
end

def make_ball(x, vx)
  Ball.new(
    Circle.new(x: x, y: EMITTER_Y, radius: 10 + rand(26), color: random_color),
    spawn_vx(vx),
    0.0
  )
end

# Send an existing ball back to the emitter, rather than dropping it and
# building another. Its `Circle` is already on the window's render list, so
# nothing has to be added or removed.
def recycle_ball(ball, x, vx)
  s = ball.shape
  s.x = x
  s.y = EMITTER_Y
  s.radius = 10 + rand(26)
  s.color = random_color
  ball.vx = spawn_vx(vx)
  ball.vy = 0.0
end

# === Mutable state ===

balls = []
cursor = 0        # next ball to recycle, once the pool is full
elapsed = 0.0
spawn_accum = 0.0 # seconds accumulated toward the next spawn

marker = Circle.new(x: emitter_x(0.0), y: EMITTER_Y, radius: 8, color: 'white')

# === Per-frame update ===

update do |dt|
  # Read the frame delta into a local before using it. A nested block that
  # reads the update block's own parameter — `balls.each` below does — makes
  # Spinel infer that parameter as `Integer`, and every delta then truncates to
  # zero, so the scene compiles, runs, and sits perfectly still. See README.md.
  step = dt
  elapsed += step

  x = emitter_x(elapsed)
  vx = emitter_vx(elapsed)
  marker.x = x

  spawn_accum += step
  while spawn_accum >= SPAWN_INTERVAL
    spawn_accum -= SPAWN_INTERVAL
    if balls.size < MAX_BALLS
      balls << make_ball(x, vx)
    else
      recycle_ball(balls[cursor], x, vx)
      cursor = (cursor + 1) % MAX_BALLS
    end
  end

  balls.each do |b|
    s = b.shape
    b.vy += GRAVITY * step
    # Longhand because `s.x += …` does not compile on this target yet — the
    # writer is a `def` rather than an `attr_writer`. See matz/spinel#3809.
    s.x = s.x + b.vx * step
    s.y = s.y + b.vy * step

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
      b.vx *= Math.exp(-FLOOR_FRICTION * step)
    end
  end
end

show
