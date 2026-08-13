# A fixed number of balls bouncing in a box.
#
#   RUBY2D_SPINEL=../spinel/bin/spinel ruby2d build --spinel spinel/examples/balls.rb
#   ruby2d launch --native
#
# Less interesting to watch than `fountain.rb`, and that is the point: it is the
# scene `rake fps` compares engines with. Nothing is created or removed after
# startup and the timestep is fixed, so every frame does exactly the same work
# on every engine. A scene that grows — the fountain, before its pool fills —
# averages a moving workload and cannot be compared across runs.
#
# The fixed timestep matters for the same reason. With a real `dt`, a faster
# engine would simulate further per frame and so measure itself slower.

require 'ruby2d'

WIDTH = 800
HEIGHT = 600
COUNT = 180              # balls on screen, the fountain's default pool size
STEP = 1.0 / 60.0        # fixed simulation timestep in seconds

GRAVITY = 2160           # downward acceleration (px/sec²)
WALL_BOUNCE = 0.9        # horizontal velocity retained after wall bounce
FLOOR_BOUNCE = 0.85      # vertical velocity retained after floor bounce

set title: 'Ruby 2D ▸ Spinel ▸ Balls', width: WIDTH, height: HEIGHT,
    background: '#0a0a23'

Ball = Struct.new(:shape, :vx, :vy)

balls = []
i = 0
while i < COUNT
  r = 10 + rand(26)
  balls << Ball.new(
    Circle.new(x: r + rand(WIDTH - r * 2), y: r + rand(HEIGHT - r * 2), radius: r,
               color: [rand * 0.6 + 0.4, rand * 0.6 + 0.4, rand * 0.6 + 0.4, 0.85]),
    rand * 720 - 360,
    rand * 720 - 360
  )
  i += 1
end

update do
  balls.each do |b|
    s = b.shape
    b.vy += GRAVITY * STEP
    # Longhand because `s.x += …` does not compile on this target yet — the
    # writer is a `def` rather than an `attr_writer`. See matz/spinel#3809.
    s.x = s.x + b.vx * STEP
    s.y = s.y + b.vy * STEP

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
    elsif s.y - s.radius < 0
      s.y = s.radius
      b.vy = b.vy.abs
    end
  end
end

show
