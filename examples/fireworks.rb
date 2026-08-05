# Particle fireworks
# Click to launch rockets that arc upward and explode into fading sparks.
#
# Each launch fires from the bottom of the window, arcs, and bursts into
# colored sparks with short glowing trails. Press `r` to clear the sky.

require 'ruby2d'

# === Tunables ===

WIDTH = 800                # window width in pixels
HEIGHT = 600               # window height in pixels
GRAVITY = 432              # downward acceleration (px/sec²)
SPARKS = 70                # sparks emitted per rocket burst
SPARK_DRAG = 0.907         # spark velocity decay rate (per second)
AUTO_LAUNCH_RATE = 1.08    # average self-launches per second

# === Window ===

set title: 'Ruby 2D ▸ Examples ▸ Particle fireworks', width: WIDTH, height: HEIGHT, background: '#050816'
set close_on_esc: true

# === Game-object structs ===

Rocket = Struct.new(:x, :y, :vx, :vy, :target_y, :color, :shape)
Spark = Struct.new(:x, :y, :vx, :vy, :life, :color, :shape)

def random_color
  [[1.0, 0.35, 0.35, 1], [1.0, 0.75, 0.2, 1], [0.3, 0.8, 1.0, 1],
   [0.6, 0.5, 1.0, 1], [0.4, 1.0, 0.55, 1]].sample
end

def launch(rockets, x, y)
  color = random_color
  rockets << Rocket.new(
    WIDTH / 2, HEIGHT - 10,
    (x - WIDTH / 2) / 85.0 * 60, -480 - rand * 180,  # px/sec
    y, color,
    Circle.new(x: WIDTH / 2, y: HEIGHT - 10, radius: 4, color: color)
  )
end

# === Mutable state ===

rockets = []
sparks = []

# === Input ===

on :mouse_down do |event|
  launch(rockets, event.x, event.y)
end

on key_down: :r do
  rockets.each { |r| r.shape.remove }
  sparks.each { |s| s.shape.remove }
  rockets.clear
  sparks.clear
end

# === Per-frame update ===

update do |dt|
  if rand < AUTO_LAUNCH_RATE * dt
    launch(rockets, rand(WIDTH), rand(90..260))
  end

  rockets.dup.each do |r|
    r.x += r.vx * dt
    r.y += r.vy * dt
    r.vy += GRAVITY * 0.35 * dt  # rockets feel lighter than sparks
    r.shape.x = r.x
    r.shape.y = r.y

    next unless r.vy >= 0 || r.y <= r.target_y

    r.shape.remove
    rockets.delete(r)
    SPARKS.times do
      angle = rand * Math::PI * 2
      speed = 72 + rand * 288  # px/sec
      color = r.color.dup
      sparks << Spark.new(
        r.x, r.y, Math.cos(angle) * speed, Math.sin(angle) * speed,
        1.0, color,  # life starts at 1.0 second
        Circle.new(x: r.x, y: r.y, radius: 2 + rand * 2, color: color)
      )
    end
  end

  spark_drag = Math.exp(-SPARK_DRAG * dt)
  sparks.dup.each do |s|
    s.x += s.vx * dt
    s.y += s.vy * dt
    s.vy += GRAVITY * dt
    s.vx *= spark_drag
    s.vy *= spark_drag
    s.life -= dt
    s.shape.x = s.x
    s.shape.y = s.y
    s.shape.opacity = [s.life, 0].max

    next unless s.life <= 0

    s.shape.remove
    sparks.delete(s)
  end
end

show
