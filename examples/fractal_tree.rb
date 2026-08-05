# Fractal tree
# A recursive tree grows, then leafs through the seasons in a procedural breeze.
#
# The tree unfurls trunk-to-canopy, bare at first, then the seasons cycle on
# their own — spring blossoms, summer green, autumn gold, back to bare — fading
# gradually from one to the next, with petals drifting down from the canopy.
# Click along the ground to regrow the tree at that spot, press R to regrow at
# the center, or S to skip ahead a season.

require 'ruby2d'

# === Tunables ===

WIDTH = 800              # window width in pixels
HEIGHT = 600             # window height in pixels
TRUNK_LENGTH = 150       # initial trunk length in pixels (scales the whole tree)
DEPTH = 7                # recursion depth (drives density and cost)
BRANCH_RATIO = 0.72      # length scaling per level
TRUNK_THICKNESS = 14     # trunk stroke width in pixels
BRANCH_TAPER = 0.8       # each branch's width as a fraction of its parent's
ANGLE_SPREAD = 0.45      # base child branch angle in radians (~26°)
ANGLE_JITTER = 0.15      # random angle variation per branch
THIRD_BRANCH_PROB = 0.35 # chance of an extra middle branch
WIND_AMPLITUDE = 0.05    # per-branch wind sway in radians
WIND_SPEED = 1.2         # wind oscillation rate (rad/sec)
GROW_TIME = 0.16         # seconds for each level to extend (trunk → canopy)
SEASON_TIME = 4.0        # seconds each season holds before the next
SEASON_FADE = 1.6        # seconds to cross-fade the canopy color between seasons
CANOPY_TAU = 0.4         # leaf-in / leaf-out smoothing constant (sec)
GROUND_TAU = 0.9         # ground color smoothing constant (sec)
LEAF_DEPTH = 2           # foliage sits on branches at this depth or shallower
LEAF_RADIUS = 6          # base foliage radius in pixels (varied per leaf)
PETAL_COUNT = 70         # drifting petals in the air
PETAL_FALL = 45          # petal fall speed (px/sec)
GROUND_H = 36            # ground band height in pixels

TWO_PI = Math::PI * 2
ROOT_X = WIDTH / 2.0
ROOT_Y = HEIGHT - 24

SKY_TOP    = '#6c9bd6'   # sky gradient, top of the window
SKY_BOTTOM = '#cfe2f5'   # sky gradient, down at the horizon

# Seasons cycle in order, starting bare. An empty list means "none" — winter
# drops all leaves, summer keeps its leaves but sheds no petals.
SEASONS = [
  { leaves: [],                                            petals: [] },                       # winter
  { leaves: ['#f9a8d4', '#fbcfe8', '#fde68a', '#ffffff'], petals: ['#f9a8d4', '#fbcfe8'] },   # spring
  { leaves: ['#4ade80', '#22c55e', '#16a34a', '#86efac'], petals: [] },                       # summer
  { leaves: ['#f59e0b', '#ef4444', '#fb923c', '#fcd34d'], petals: ['#f59e0b', '#fb923c'] }    # autumn
].freeze

# Ground gradient (top, bottom) per season, parallel to SEASONS.
GROUND_SEASONS = [
  ['#d8e2e0', '#aeb9b4'],  # winter — frosty pale
  ['#86c34a', '#4f7a2c'],  # spring — fresh green
  ['#5f8f33', '#37571f'],  # summer — deep green
  ['#9c7d3a', '#5a4620']   # autumn — golden brown
].freeze

# Parse the hex palettes into [r, g, b] triples once, for color interpolation.
LEAF_RGB = SEASONS.map { |s| s[:leaves].map { |hex| c = Color.new(hex); [c.r, c.g, c.b] } }
GROUND_RGB = GROUND_SEASONS.map { |pair| pair.map { |hex| c = Color.new(hex); [c.r, c.g, c.b] } }

# === Window ===

set title: 'Ruby 2D ▸ Examples ▸ Fractal tree', width: WIDTH, height: HEIGHT, background: SKY_BOTTOM
set close_on_esc: true

# === Structs and helpers ===

Branch = Struct.new(:parent_idx, :base_angle, :length, :depth, :phase,
                    :line, :tip_x, :tip_y, :leaf, :hue, :leaf_size)
Petal = Struct.new(:x, :y, :speed, :phase, :amp, :circle)

def lerp(a, b, t)
  a + (b - a) * t
end

# Smoothstep on a clamped 0..1 ramp, used to ease branch growth and the
# canopy color cross-fade in and out.
def ease(x)
  t = x.clamp(0.0, 1.0)
  t * t * (3 - 2 * t)
end

# Recursively grow the branch list. Each branch starts as a zero-length Line
# (the update loop extends it) and is a fixed fraction thinner than its parent
# (BRANCH_TAPER), so a branch stays close to the trunk's width where it forks
# and thins gradually toward the canopy. Canopy branches also get a Circle
# leaf the season cycle fades in and out.
def build_tree(branches, base_angle, length, thickness, depth, parent_idx)
  return if depth == 0 || length < 2

  level = DEPTH - depth
  frac = level / (DEPTH - 1).to_f
  color = [lerp(0.26, 0.46, frac), lerp(0.17, 0.32, frac), lerp(0.09, 0.18, frac), 1]
  line = Line.new(x1: 0, y1: 0, x2: 0, y2: 0,
                  stroke_width: thickness.clamp(1.0, TRUNK_THICKNESS), color: color, z: 1)

  leaf = nil
  leaf_size = 0.0
  if depth <= LEAF_DEPTH
    leaf = Circle.new(x: 0, y: 0, radius: 1, sectors: 7, color: '#ffffff', z: 2, visible: false)
    leaf_size = LEAF_RADIUS * (0.7 + rand * 0.7)
  end

  phase = rand * TWO_PI
  this_idx = branches.size
  branches << Branch.new(parent_idx, base_angle, length, depth, phase,
                         line, 0.0, 0.0, leaf, rand, leaf_size)

  child_len = length * BRANCH_RATIO
  child_thick = thickness * BRANCH_TAPER
  third = rand < THIRD_BRANCH_PROB

  child_l = base_angle + ANGLE_SPREAD + (rand - 0.5) * ANGLE_JITTER
  child_r = base_angle - ANGLE_SPREAD + (rand - 0.5) * ANGLE_JITTER
  build_tree(branches, child_l, child_len, child_thick, depth - 1, this_idx)
  build_tree(branches, child_r, child_len, child_thick, depth - 1, this_idx)
  if third
    child_c = base_angle + (rand - 0.5) * ANGLE_JITTER
    build_tree(branches, child_c, child_len, child_thick, depth - 1, this_idx)
  end
end

# === State ===

branches = []
leaf_branches = []   # subset of `branches` carrying a leaf (the canopy)
root_x = ROOT_X
root_y = ROOT_Y
grow_age = 0.0       # seconds since the current tree was planted
season_idx = 0       # starts on winter (bare)
season_timer = 0.0
canopy = 0.0         # 0 bare … 1 full; eases toward the season's leafiness
blend = 1.0          # canopy color cross-fade, 0 → 1 (1 = settled on season)
from_season = 0      # season the cross-fade is coming from
reseed_petals = false
ground_top = GROUND_RGB[0][0].dup   # current ground colors, eased per season
ground_bot = GROUND_RGB[0][1].dup

# === Scenery and petals (persistent, drawn behind the tree) ===

Quad.new(x1: 0, y1: 0, x2: WIDTH, y2: 0, x3: WIDTH, y3: HEIGHT, x4: 0, y4: HEIGHT,
         color: [SKY_TOP, SKY_TOP, SKY_BOTTOM, SKY_BOTTOM], z: -20)
GROUND_Y = HEIGHT - GROUND_H
ground = Quad.new(x1: 0, y1: GROUND_Y, x2: WIDTH, y2: GROUND_Y, x3: WIDTH, y3: HEIGHT, x4: 0, y4: HEIGHT,
                  color: [GROUND_SEASONS[0][0], GROUND_SEASONS[0][0],
                          GROUND_SEASONS[0][1], GROUND_SEASONS[0][1]], z: -10)

petals = Array.new(PETAL_COUNT) do
  Petal.new(rand * WIDTH, rand * HEIGHT, PETAL_FALL * (0.6 + rand * 0.8),
            rand * TWO_PI, 10 + rand * 26,
            Circle.new(x: 0, y: 0, radius: 3 + rand * 2, sectors: 6,
                       color: '#f9a8d4', z: 3, visible: false))
end

# === Season + planting ===

# Advance to the next season. Petals recolor instantly (they were hidden in
# between); the canopy either snaps to the new palette while it is hidden, or
# cross-fades from the season it is leaving when the leaves are on show.
next_season = lambda do
  prev = season_idx
  season_idx = (season_idx + 1) % SEASONS.length

  petal_palette = SEASONS[season_idx][:petals]
  petals.each_with_index { |p, i| p.circle.color = petal_palette[i % petal_palette.size] } unless petal_palette.empty?

  leaf_palette = LEAF_RGB[season_idx]
  if leaf_palette.empty?
    blend = 1.0
  elsif canopy < 0.1 || SEASONS[prev][:leaves].empty?
    blend = 1.0
    branches.each do |b|
      next unless b.leaf

      c = leaf_palette[(b.hue * leaf_palette.size).to_i]
      b.leaf.color = [c[0], c[1], c[2], 1]
    end
  else
    from_season = prev
    blend = 0.0
  end
end

# Plant a fresh tree at (x, y): rebuild the branches, reset the growth and
# season cycle to the start (bare), and ask the petals to reseed from the
# new canopy on the next frame.
plant = lambda do |x, y|
  branches.each do |b|
    b.line.remove
    b.leaf.remove if b.leaf
  end
  branches.clear
  root_x = x
  root_y = y
  grow_age = 0.0
  season_idx = 0
  season_timer = 0.0
  canopy = 0.0
  blend = 1.0
  build_tree(branches, 0.0, TRUNK_LENGTH, TRUNK_THICKNESS, DEPTH, -1)
  leaf_branches = branches.select { |b| b.leaf }
  reseed_petals = true
end

plant.call(root_x, root_y)

# === Input ===

# Click regrows the tree at the cursor's x, but always rooted on the ground.
on :mouse_down do |event|
  plant.call(event.x.to_f, ROOT_Y)
end

on(key_down: :r) { plant.call(ROOT_X, ROOT_Y) }

on(key_down: :s) do
  season_timer = 0.0
  next_season.call
end

# === Per-frame update ===

update do |dt|
  t = elapsed
  grow_age += dt

  # Advance the season on its own timer.
  season_timer += dt
  if season_timer >= SEASON_TIME
    season_timer -= SEASON_TIME
    next_season.call
  end

  petals_on = !SEASONS[season_idx][:petals].empty?
  canopy_target = SEASONS[season_idx][:leaves].empty? ? 0.0 : 1.0
  canopy += (canopy_target - canopy) * (1 - Math.exp(-dt / CANOPY_TAU))

  # Ease the ground gradient toward the current season's colors.
  gt = GROUND_RGB[season_idx][0]
  gb = GROUND_RGB[season_idx][1]
  gk = 1 - Math.exp(-dt / GROUND_TAU)
  3.times do |i|
    ground_top[i] += (gt[i] - ground_top[i]) * gk
    ground_bot[i] += (gb[i] - ground_bot[i]) * gk
  end
  top_color = [ground_top[0], ground_top[1], ground_top[2], 1]
  bot_color = [ground_bot[0], ground_bot[1], ground_bot[2], 1]
  ground.color = [top_color, top_color, bot_color, bot_color]

  # Cross-fade the canopy color only while a leafy→leafy transition runs.
  blending = blend < 1.0
  if blending
    blend = [blend + dt / SEASON_FADE, 1.0].min
    blend_e = ease(blend)
    from_pal = LEAF_RGB[from_season]
    to_pal = LEAF_RGB[season_idx]
  end

  branches.each do |b|
    wind = Math.sin(t * WIND_SPEED + b.phase) * WIND_AMPLITUDE
    angle = b.base_angle + wind
    # Each level starts extending only after its parent has finished, so
    # the tree unfurls from the trunk outward.
    grow = ease((grow_age - (DEPTH - b.depth) * GROW_TIME) / GROW_TIME)

    if b.parent_idx == -1
      base_x = root_x
      base_y = root_y
    else
      parent = branches[b.parent_idx]
      base_x = parent.tip_x
      base_y = parent.tip_y
    end

    eff_len = b.length * grow
    b.tip_x = base_x + Math.sin(angle) * eff_len
    b.tip_y = base_y - Math.cos(angle) * eff_len
    b.line.x1 = base_x
    b.line.y1 = base_y
    b.line.x2 = b.tip_x
    b.line.y2 = b.tip_y
    b.line.visible = grow > 0.0

    next unless b.leaf

    b.leaf.x = b.tip_x
    b.leaf.y = b.tip_y
    b.leaf.radius = b.leaf_size * canopy
    b.leaf.visible = canopy > 0.02 && grow > 0.5
    next unless blending

    fc = from_pal[(b.hue * from_pal.size).to_i]
    tc = to_pal[(b.hue * to_pal.size).to_i]
    b.leaf.color = [lerp(fc[0], tc[0], blend_e), lerp(fc[1], tc[1], blend_e),
                    lerp(fc[2], tc[2], blend_e), 1]
  end

  # Petals fall from the canopy: each one (re)spawns at a random leaf tip and
  # drifts down on the wind. The reseed pass snaps them to a freshly planted
  # canopy once its tips exist.
  n_leaves = leaf_branches.length
  petals.each do |p|
    if reseed_petals && n_leaves > 0
      lb = leaf_branches[rand(n_leaves)]
      p.x = lb.tip_x
      p.y = lb.tip_y + rand * (HEIGHT - lb.tip_y)
    else
      p.y += p.speed * dt
      if p.y > HEIGHT + 12 && n_leaves > 0
        lb = leaf_branches[rand(n_leaves)]
        p.x = lb.tip_x
        p.y = lb.tip_y
      end
    end
    p.circle.x = p.x + Math.sin(t * 0.9 + p.phase) * p.amp
    p.circle.y = p.y
    p.circle.visible = petals_on
  end
  reseed_petals = false
end

show
