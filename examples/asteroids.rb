# Asteroids
# A small clone of the classic, doubling as a tour of Ruby 2D fundamentals.
#
# Demonstrates the core building blocks:
#   * `set` configures the window
#   * `update do |dt| ... end` runs per-frame logic (no drawing); `dt` is
#     wall-clock seconds since the last update so motion stays consistent
#     across 60Hz, 120Hz, and slower frames alike
#   * `render do ... end` does immediate-mode drawing
#   * `on :key_down` / `on :key_up` capture input
#   * Persistent shapes (`Text.new`) coexist with one-shot draws (`Circle.render`)
#
# Controls: rotate with left/right, thrust with up, fire with space,
# restart with r.

require 'ruby2d'

# === Tunables ===

WIDTH = 800        # window width in pixels
HEIGHT = 600       # window height in pixels
SHIP_R = 15        # ship radius (used for collision and drawing)
THRUST = 1152      # acceleration while thrusting (px/sec²)
HIT_PENALTY = 500  # score deducted when the ship is destroyed

# === Window ===

set title: 'Ruby 2D ▸ Examples ▸ Asteroids', width: WIDTH, height: HEIGHT, background: '#050816'
set close_on_esc: true

# === Game-object structs ===
#
# Plain values held in arrays and updated each frame. Sparks back both the
# ship's thrust trail and the victory fireworks; an optional `hue` lets
# fireworks override the default fire colors.

Asteroid = Struct.new(:x, :y, :vx, :vy, :radius, :points)
Bullet = Struct.new(:x, :y, :vx, :vy)
Spark = Struct.new(:x, :y, :vx, :vy, :life, :max_life, :hue)

# Build a jagged closed shape by sampling 10 angles around a circle and
# jittering each radius. Points are stored in the asteroid's local space
# and offset by `a.x, a.y` at draw time.
def make_asteroid(x = rand(WIDTH), y = rand(HEIGHT), radius = 42)
  points = 10.times.map do |i|
    angle = i / 10.0 * Math::PI * 2
    r = radius * (0.72 + rand * 0.45)
    [Math.cos(angle) * r, Math.sin(angle) * r]
  end
  Asteroid.new(x, y, rand(-156.0..156.0), rand(-156.0..156.0), radius, points)
end

# === Mutable state ===
#
# Plain locals; the `update` and `render` blocks below close over them.
# All time-bearing quantities are in wall-clock seconds.

ship_x = WIDTH / 2.0
ship_y = HEIGHT / 2.0
ship_vx = 0.0
ship_vy = 0.0
ship_angle = -Math::PI / 2  # facing up (-y)
left = false
right = false
thrust = false
firing = false
cooldown = 0           # seconds until the next bullet may fire
score = 0
bullets = []
asteroids = []
sparks = []
respawn_timer = 0      # > 0 (seconds) while the ship is dead
invuln_timer = 0       # > 0 (seconds) just after respawn; collisions ignored
firework_timer = 0     # seconds until the next victory firework
thrust_spark_accum = 0.0  # fractional carry for rate-based thrust emitter

# Pre-baked starfield: each entry is [x, y, radius, alpha].
stars = Array.new(70) { [rand(WIDTH), rand(HEIGHT), rand(0.4..1.3), 0.25 + rand * 0.55] }

# Firework palette as RGB triples; alpha is filled in at render time.
FIREWORK_HUES = [[1.0, 0.3, 0.4], [0.4, 0.7, 1.0], [0.5, 1.0, 0.5],
                 [1.0, 0.85, 0.3], [0.95, 0.55, 1.0], [0.4, 1.0, 0.95]]

# === HUD ===

score_text = Text.new('Score: 0', x: 16, y: 12, size: 18, color: '#e5e7eb')

# Cleared banner: hidden until the player wins. `x: :center` re-resolves at
# draw time against the live viewport, so the banner stays centered even if
# the window resizes.
cleared_title = Text.new('Asteroids Cleared!', x: :center, y: HEIGHT / 2 - 56,
                         size: 40, color: '#fde047', visible: false)
cleared_subtitle = Text.new('Press R to restart', x: :center, y: HEIGHT / 2 + 4,
                            size: 20, color: '#e5e7eb', visible: false)

# Captured as a lambda so it can rebuild state both at startup and on `r`.
reset = lambda do
  ship_x = WIDTH / 2.0
  ship_y = HEIGHT / 2.0
  ship_vx = 0.0
  ship_vy = 0.0
  ship_angle = -Math::PI / 2
  cooldown = 0
  score = 0
  respawn_timer = 0
  invuln_timer = 1.5  # grace period at game start matches the post-death grace
  firework_timer = 0
  bullets.clear
  sparks.clear
  asteroids.replace(Array.new(6) { make_asteroid })
  score_text.content = 'Score: 0'
  cleared_title.hide
  cleared_subtitle.hide
end

reset.call

# === Input ===
#
# Hold-to-repeat keys (left/right/up/space) flip booleans the update loop
# reads each frame. The fire `cooldown` paces space-held auto-fire.

on :key_down do |event|
  case event.key
  when :left
    left = true
  when :right
    right = true
  when :up
    thrust = true
  when :space
    firing = true
  when :r
    reset.call
  end
end

on :key_up do |event|
  left = false if event.key? :left
  right = false if event.key? :right
  thrust = false if event.key? :up
  firing = false if event.key? :space
end

# Gamepad: dpad left/right/up mirror the rotation and thrust keys; any button fires.
on :gamepad_button_down do |_pad, button|
  case button
  when :dpad_left  then left = true
  when :dpad_right then right = true
  when :dpad_up    then thrust = true
  end
  firing = true
end

on :gamepad_button_up do |pad, button|
  case button
  when :dpad_left  then left = false
  when :dpad_right then right = false
  when :dpad_up    then thrust = false
  end
  firing = false if pad.buttons_held.empty?
end

# === Per-frame update ===
#
# Ruby 2D calls this block once per rendered frame and passes `dt` — wall-clock
# seconds since the previous update. All rates below are in per-second units
# (velocities in px/sec, accelerations in px/sec², drag as a per-second decay
# rate `vx *= Math.exp(-rate * dt)`), so feel is identical at any refresh rate.

update do |dt|
  # Ship state machine: respawning, otherwise alive and being driven.
  if respawn_timer.positive?
    respawn_timer -= dt
    if respawn_timer <= 0
      respawn_timer = 0
      ship_x = WIDTH / 2.0
      ship_y = HEIGHT / 2.0
      ship_vx = 0.0
      ship_vy = 0.0
      ship_angle = -Math::PI / 2
      invuln_timer = 1.5  # 1.5s of grace, fading from translucent to solid
    end
  else
    ship_angle -= 7.2 * dt if left   # 7.2 rad/sec turn rate
    ship_angle += 7.2 * dt if right
    if thrust
      ship_vx += Math.cos(ship_angle) * THRUST * dt
      ship_vy += Math.sin(ship_angle) * THRUST * dt
    end
    drag = Math.exp(-0.964 * dt)  # mild drag so the ship eventually slows
    ship_vx *= drag
    ship_vy *= drag
    # Toroidal wrap: drift off one edge, reappear on the opposite side.
    ship_x = (ship_x + ship_vx * dt) % WIDTH
    ship_y = (ship_y + ship_vy * dt) % HEIGHT
    cooldown -= dt if cooldown.positive?

    # Auto-fire while space is held; `cooldown` paces it.
    if firing && cooldown <= 0
      bullets << Bullet.new(ship_x + Math.cos(ship_angle) * SHIP_R,
                            ship_y + Math.sin(ship_angle) * SHIP_R,
                            Math.cos(ship_angle) * 840 + ship_vx,  # 840 px/sec muzzle speed
                            Math.sin(ship_angle) * 840 + ship_vy)
      cooldown = 0.1  # seconds between auto-fire shots
    end

    # Spawn thrust sparks behind the ship while accelerating. Rate-based: ~240
    # sparks/sec on average. The accumulator carries the fractional part so
    # high refresh rates don't drop sparks and low ones don't pile them up.
    if thrust
      thrust_spark_accum += 240 * dt
      count = thrust_spark_accum.to_i
      thrust_spark_accum -= count
      count.times do
        back = ship_angle + Math::PI + (rand - 0.5) * 0.7
        speed = 192 + rand * 216  # 192–408 px/sec
        life = 0.12 + rand * 0.08  # 0.12–0.20 sec
        sparks << Spark.new(ship_x - Math.cos(ship_angle) * SHIP_R * 0.45,
                            ship_y - Math.sin(ship_angle) * SHIP_R * 0.45,
                            Math.cos(back) * speed + ship_vx * 0.5,
                            Math.sin(back) * speed + ship_vy * 0.5,
                            life, life)
      end
    end
  end
  invuln_timer -= dt if invuln_timer.positive?
  invuln_timer = 0 if invuln_timer.negative?

  # Particle update: drift, decay, prune dead ones.
  spark_drag = Math.exp(-7.43 * dt)
  sparks.each do |s|
    s.x += s.vx * dt
    s.y += s.vy * dt
    s.vx *= spark_drag
    s.vy *= spark_drag
    s.life -= dt
  end
  sparks.reject! { |s| s.life <= 0 }

  # Bullets fly straight and disappear when they leave the window.
  bullets.each do |b|
    b.x += b.vx * dt
    b.y += b.vy * dt
  end
  bullets.reject! { |b| b.x < 0 || b.x > WIDTH || b.y < 0 || b.y > HEIGHT }

  # Asteroids drift and wrap.
  asteroids.each do |a|
    a.x = (a.x + a.vx * dt) % WIDTH
    a.y = (a.y + a.vy * dt) % HEIGHT
  end

  # Bullet vs. asteroid: simple circle test. `bullets.dup` lets us mutate
  # the original array safely while iterating. A hit awards more for small
  # asteroids and splits big ones into two smaller children at the same
  # spot; asteroids below radius 20 don't split further.
  bullets.dup.each do |b|
    hit = asteroids.find do |a|
      dx = b.x - a.x
      dy = b.y - a.y
      dx * dx + dy * dy < a.radius * a.radius
    end
    next unless hit

    bullets.delete(b)
    asteroids.delete(hit)
    score += hit.radius < 25 ? 200 : 100
    score_text.content = "Score: #{score}"
    # Debris burst in the asteroid's slate color. Count and speed scale with
    # size so big rocks pop harder than little chips.
    burst = (hit.radius * 0.5).to_i + 8
    burst.times do
      angle = rand * Math::PI * 2
      speed = 72 + rand * (144 + hit.radius * 7.2)  # px/sec
      life = 0.17 + rand * 0.17  # 0.17–0.33 sec
      sparks << Spark.new(hit.x, hit.y,
                          Math.cos(angle) * speed, Math.sin(angle) * speed,
                          life, life, [0.75, 0.82, 0.9])
    end
    if hit.radius > 20
      2.times { asteroids << make_asteroid(hit.x, hit.y, hit.radius * 0.58) }
    end
  end

  # Ship vs. asteroid. The `((d + size/2) % size) - size/2` trick gives the
  # shortest distance across the toroidal screen, so an asteroid poking
  # through one edge can still hit a ship hugging the opposite edge.
  if respawn_timer.zero? && invuln_timer.zero?
    ship_hit = asteroids.any? do |a|
      dx = ((ship_x - a.x + WIDTH / 2) % WIDTH) - WIDTH / 2
      dy = ((ship_y - a.y + HEIGHT / 2) % HEIGHT) - HEIGHT / 2
      dx * dx + dy * dy < (a.radius + SHIP_R) ** 2
    end
    if ship_hit
      # Burst a ring of sparks for the explosion.
      25.times do
        angle = rand * Math::PI * 2
        speed = 96 + rand * 408  # px/sec
        life = 0.25 + rand * 0.17  # 0.25–0.42 sec
        sparks << Spark.new(ship_x, ship_y,
                            Math.cos(angle) * speed, Math.sin(angle) * speed,
                            life, life)
      end
      score = [score - HIT_PENALTY, 0].max
      score_text.content = "Score: #{score}"
      respawn_timer = 1.0  # 1 second dead before the ship reappears
    end
  end

  # All asteroids destroyed: show the cleared banner and keep launching
  # colored fireworks at random spots.
  if asteroids.empty? && respawn_timer.zero?
    cleared_title.show
    cleared_subtitle.show
    firework_timer -= dt
    if firework_timer <= 0
      fx = 80 + rand(WIDTH - 160)
      fy = 80 + rand((HEIGHT - 200))
      hue = FIREWORK_HUES.sample
      28.times do |i|
        angle = i / 28.0 * Math::PI * 2 + (rand - 0.5) * 0.2
        speed = 144 + rand * 312  # px/sec
        life = 0.29 + rand * 0.21  # 0.29–0.50 sec
        sparks << Spark.new(fx, fy, Math.cos(angle) * speed, Math.sin(angle) * speed,
                            life, life, hue)
      end
      firework_timer = 0.21 + rand * 0.17  # 0.21–0.38 sec between fireworks
    end
  else
    cleared_title.hide
    cleared_subtitle.hide
    firework_timer = 0
  end
end

# === Render ===
#
# Draw order is back to front: stars, particles, ship, bullets, asteroids.
# `Foo.render(...)` is the immediate-mode form: cheap to call every frame
# and doesn't allocate a persistent object.

# The whole game draws behind the HUD (z: :background), so the score and the
# cleared banner always stay on top.
render z: :background do
  # Background stars.
  stars.each do |sx, sy, sr, sa|
    Circle.render(x: sx, y: sy, radius: sr, color: [1.0, 1.0, 1.0, sa])
  end

  # Sparks fade with their remaining life. Fireworks keep their hue;
  # thrust particles cool from yellow toward red as they age.
  sparks.each do |s|
    t = s.life.to_f / s.max_life
    color = if s.hue
              [s.hue[0], s.hue[1], s.hue[2], t]
            else
              [1.0, 0.35 + t * 0.55, 0.1 * t, t]
            end
    Circle.render(x: s.x, y: s.y, radius: 0.8 + t * 1.8, color: color)
  end

  # Ship: hidden while respawning; fades up from translucent to solid
  # during the invulnerability window.
  if respawn_timer.zero?
    ship_alpha = invuln_timer.positive? ? 0.25 + 0.75 * (1.0 - invuln_timer / 1.5) : 1.0
    # Local-space layout (nose at +x), rotated into world space:
    #   wx = ship_x + px*cos - py*sin
    #   wy = ship_y + px*sin + py*cos
    ship_pts = [[SHIP_R, 0], [-SHIP_R * 0.8, -SHIP_R * 0.65], [-SHIP_R * 0.45, 0],
                [-SHIP_R * 0.8, SHIP_R * 0.65]].map do |px, py|
      c = Math.cos(ship_angle)
      s = Math.sin(ship_angle)
      [ship_x + px * c - py * s, ship_y + px * s + py * c]
    end
    if thrust
      # Flame triangle behind the ship, flickering via random length offsets.
      outer = 22 + rand * 14
      inner = 8 + rand * 4
      flame = [
        ship_pts[2],
        [ship_x - Math.cos(ship_angle) * outer, ship_y - Math.sin(ship_angle) * outer],
        [ship_x - Math.cos(ship_angle) * inner, ship_y - Math.sin(ship_angle) * inner]
      ]
      Triangle.render(x1: flame[0][0], y1: flame[0][1], x2: flame[1][0], y2: flame[1][1],
                      x3: flame[2][0], y3: flame[2][1],
                      color: ['#fde047', '#f97316', '#fbbf24'], opacity: ship_alpha)
    end
    Polyline.render(points: ship_pts, closed: true, stroke_width: 2,
                    color: '#e5e7eb', opacity: ship_alpha)
  end

  bullets.each do |b|
    Circle.render(x: b.x, y: b.y, radius: 3, color: '#facc15')
  end

  asteroids.each do |a|
    pts = a.points.map { |px, py| [a.x + px, a.y + py] }
    Polyline.render(points: pts, closed: true, stroke_width: 2, color: '#94a3b8')
  end
end

show
