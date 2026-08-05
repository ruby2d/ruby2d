# Travelling salesman (simulated annealing)
# A 2-opt search wrapped in simulated annealing untangles a 60-city tour.
#
# Each step picks two edges, sees what happens if the tour segment
# between them is reversed, and accepts the swap when it shortens the
# tour — or, with probability `exp(-Δ / T)`, even when it lengthens it.
# The temperature `T` cools each step, so late on the search only takes
# the wins. The tangled mess relaxes into a clean closed loop. Press R
# for a fresh set of cities.

require 'ruby2d'

# === Tunables ===

WIDTH = 800              # window width in pixels
HEIGHT = 600             # window height in pixels
HUD_H = 36               # reserved strip at the top for the label
NUM_CITIES = 60          # cities to visit
ITERS_PER_FRAME = 800    # 2-opt proposals attempted each frame
INITIAL_T = 220.0        # starting temperature in distance units
COOLING = 0.99996        # T multiplier per attempt

# === Window ===

set title: 'Ruby 2D ▸ Examples ▸ Travelling salesman (simulated annealing)',
    width: WIDTH, height: HEIGHT, background: '#0a0e1c'
set close_on_esc: true

# === State ===

cities = []          # [x, y] points
tour = []            # permutation of 0...NUM_CITIES
total_length = 0.0   # cached length of the current tour
temperature = 0.0

reset = lambda do
  cities.clear
  NUM_CITIES.times do
    cities << [40 + rand(WIDTH - 80), HUD_H + 20 + rand(HEIGHT - HUD_H - 40)]
  end
  tour.replace((0...NUM_CITIES).to_a.shuffle)
  total_length = 0.0
  NUM_CITIES.times do |k|
    pa = cities[tour[k]]
    pb = cities[tour[(k + 1) % NUM_CITIES]]
    total_length += Math.hypot(pa[0] - pb[0], pa[1] - pb[1])
  end
  temperature = INITIAL_T
end

reset.call

# === Persistent overlays ===

Text.new('Press R for new cities', x: 16, y: 12, size: 16, color: '#cbd5e1', z: 10)

# === Input ===

on key_down: :r do
  reset.call
end

# === Per-frame update ===

# Each step picks i < j inside the tour interior, computes only the
# four edge lengths that change under the reverse, and either commits
# or rolls dice against the Boltzmann factor.
update do
  k = 0
  while k < ITERS_PER_FRAME
    i = rand(NUM_CITIES - 2) + 1
    j = i + 1 + rand(NUM_CITIES - i - 1)

    a = cities[tour[i - 1]]
    b = cities[tour[i]]
    c = cities[tour[j]]
    d = cities[tour[(j + 1) % NUM_CITIES]]

    old_d = Math.hypot(a[0] - b[0], a[1] - b[1]) + Math.hypot(c[0] - d[0], c[1] - d[1])
    new_d = Math.hypot(a[0] - c[0], a[1] - c[1]) + Math.hypot(b[0] - d[0], b[1] - d[1])
    delta = new_d - old_d

    if delta < 0 || rand < Math.exp(-delta / temperature)
      tour[i..j] = tour[i..j].reverse
      total_length += delta
    end

    temperature *= COOLING
    k += 1
  end
end

# === Render ===

render do
  pts = Array.new(NUM_CITIES + 1) { |k| cities[tour[k % NUM_CITIES]] }
  Polyline.render(points: pts, color: '#22d3ee', stroke_width: 1.5)

  cities.each do |cx, cy|
    Circle.render(x: cx, y: cy, radius: 4, color: '#fde047')
  end
end

show
