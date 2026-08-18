# Falling sand
# A cellular-automaton sandbox where sand piles, water flows, and stone holds.
#
# Click and drag in the world to drop the selected material. Click
# swatches in the toolbar to switch materials, or use 1/2/3 keys. Press
# `r` to clear the world. Under the hood it uses the classic
# sandbox-engine tricks: the world is one flat row-major array, rows
# where nothing moved are put to sleep, and only cells that changed get
# repainted — so a settled world costs almost nothing to run.

require 'ruby2d'

# === Tunables ===

WIDTH = 800              # window width in pixels
HEIGHT = 600             # window height in pixels
TOOLBAR_H = 60           # toolbar height in pixels
CELL = 4                 # cell size in pixels (smaller = finer simulation)
BRUSH_RADIUS = 3         # cells around the cursor that get filled
SIM_RATE = 120           # simulation steps per second

COLS = WIDTH / CELL
ROWS = (HEIGHT - TOOLBAR_H) / CELL

EMPTY = 0
SAND  = 1
WATER = 2
STONE = 3

COLORS = {
  EMPTY => [0.04, 0.05, 0.08, 1],
  SAND  => [0.95, 0.78, 0.42, 1],
  WATER => [0.30, 0.55, 0.90, 1],
  STONE => [0.50, 0.50, 0.55, 1]
}

# === Window ===

set title: 'Ruby 2D ▸ Examples ▸ Falling sand', width: WIDTH, height: HEIGHT
set close_on_esc: true

# === Toolbar ===

toolbar = Canvas.new(
  x: 0, y: 0, width: WIDTH, height: TOOLBAR_H,
  fill: [0.12, 0.12, 0.18, 1], z: 10
)

# World canvas (below the toolbar)
canvas = Canvas.new(
  x: 0, y: TOOLBAR_H, width: WIDTH, height: HEIGHT - TOOLBAR_H,
  fill: COLORS[EMPTY]
)

MATERIALS = [SAND, WATER, STONE]
SWATCH_X0  = 12
SWATCH_Y   = 12
SWATCH_SZ  = 36
SWATCH_GAP = 8

def draw_toolbar(toolbar, current_material)
  toolbar.clear
  toolbar.fill_rectangle(
    x: 0, y: TOOLBAR_H - 3, width: WIDTH, height: 3,
    color: [0.3, 0.3, 0.4, 1]
  )
  MATERIALS.each_with_index do |mat, i|
    sx = SWATCH_X0 + i * (SWATCH_SZ + SWATCH_GAP)
    border = mat == current_material ? [1.0, 1.0, 1.0, 1.0] : [0.3, 0.3, 0.4, 1]
    toolbar.fill_rectangle(
      x: sx - 3, y: SWATCH_Y - 3,
      width: SWATCH_SZ + 6, height: SWATCH_SZ + 6, color: border
    )
    toolbar.fill_rectangle(
      x: sx, y: SWATCH_Y, width: SWATCH_SZ, height: SWATCH_SZ,
      color: COLORS[mat]
    )
  end
end

# Stamp a disc of material around the cursor, then wake the affected rows
# (plus one row either side) so the sleeping sim picks the new cells up.
def paint(grid, active, dirty, mx, my, mat)
  cx = mx / CELL
  cy = my / CELL
  (-BRUSH_RADIUS..BRUSH_RADIUS).each do |dy|
    (-BRUSH_RADIUS..BRUSH_RADIUS).each do |dx|
      next if dx * dx + dy * dy > BRUSH_RADIUS * BRUSH_RADIUS
      r = cy + dy
      c = cx + dx
      next unless r.between?(0, ROWS - 1) && c.between?(0, COLS - 1)
      i = r * COLS + c
      grid[i] = mat
      dirty << i
    end
  end
  ((cy - BRUSH_RADIUS - 1)..(cy + BRUSH_RADIUS + 1)).each do |r|
    active[r] = true if r.between?(0, ROWS - 1)
  end
end

# One simulation step, bottom-up. This is the hot loop — it can run SIM_RATE
# times a second — so it breaks with the usual Ruby style on purpose: `while`
# instead of block iterators (no block dispatch per cell) and nothing
# allocated inside. Rows are visited only if something moved in or next to
# them last step (`active`); every cell that changes lands in `dirty` so the
# render pass repaints just those.
def step(grid, active, next_active, dirty)
  next_active.fill(false)
  r = ROWS - 2
  while r >= 0
    unless active[r]
      r -= 1
      next
    end
    row_moved = false
    base = r * COLS
    # Scan alternating directions at random so piles don't lean one way
    if rand < 0.5
      c = 0; last_c = COLS; c_step = 1
    else
      c = COLS - 1; last_c = -1; c_step = -1
    end
    while c != last_c
      i = base + c
      cell = grid[i]
      if cell == SAND || cell == WATER
        bi = i + COLS
        below = grid[bi]

        # Fall straight down into empty or (sand only) sink through water
        if below == EMPTY || (cell == SAND && below == WATER)
          grid[bi] = cell
          grid[i] = below
          dirty << i << bi
          row_moved = true
        else
          # Try sliding diagonally down, in a random order
          d = rand < 0.5 ? -1 : 1
          moved = false
          tries = 0
          while tries < 2
            nc = c + d
            if nc >= 0 && nc < COLS
              target = grid[bi + d]
              if target == EMPTY || (cell == SAND && target == WATER)
                grid[bi + d] = cell
                grid[i] = target
                dirty << i << (bi + d)
                moved = true
                row_moved = true
                break
              end
            end
            d = -d
            tries += 1
          end

          # Water spreads horizontally if it can't fall
          if !moved && cell == WATER
            tries = 0
            while tries < 2
              nc = c + d
              if nc >= 0 && nc < COLS && grid[base + nc] == EMPTY
                grid[base + nc] = WATER
                grid[i] = EMPTY
                dirty << i << (base + nc)
                row_moved = true
                break
              end
              d = -d
              tries += 1
            end
          end
        end
      end
      c += c_step
    end
    # A move can unblock the row above and feed the arrivals' own row below
    if row_moved
      next_active[r] = true
      next_active[r - 1] = true if r > 0
      next_active[r + 1] = true
    end
    r -= 1
  end
  active.replace(next_active)
end

# === World state ===

# Flat row-major grids: cell (r, c) lives at index r * COLS + c
grid = Array.new(ROWS * COLS, EMPTY)
painted = Array.new(ROWS * COLS, EMPTY)  # what's on the canvas, per cell
active = Array.new(ROWS, false)          # rows the sim will visit this step
next_active = Array.new(ROWS, false)
dirty = []                               # cell indices touched since last repaint

material = SAND
mouse_held = false
brush_x = -1
brush_y = -1
sim_accum = 0.0

# One rect batch per material (indexed by cell value), reused every frame —
# repainting via a few fill_rectangles calls instead of one fill_rectangle
# per cell keeps the per-call dispatch overhead off the hot path.
batches = Array.new(COLORS.length) { [] }

draw_toolbar(toolbar, material)

# Toolbar click hit areas — visual-less Buttons (nothing drawn) over the swatches
MATERIALS.each_with_index do |mat, i|
  sx = SWATCH_X0 + i * (SWATCH_SZ + SWATCH_GAP)
  Button.new(x: sx, y: SWATCH_Y, width: SWATCH_SZ, height: SWATCH_SZ, z: 11) do
    material = mat
    draw_toolbar(toolbar, material)
  end
end

# === Input ===

on :mouse_down do |event|
  next if event.y < TOOLBAR_H
  mouse_held = true
  brush_x = event.x
  brush_y = event.y - TOOLBAR_H
end

on :mouse_up do
  mouse_held = false
end

on :mouse_move do |event|
  brush_x = event.x
  brush_y = event.y - TOOLBAR_H
end

on :key_down do |event|
  case event.key
  when :digit_1
    material = SAND
    draw_toolbar(toolbar, material)
  when :digit_2
    material = WATER
    draw_toolbar(toolbar, material)
  when :digit_3
    material = STONE
    draw_toolbar(toolbar, material)
  when :r
    grid.fill(EMPTY)
    painted.fill(EMPTY)
    active.fill(false)
    dirty.clear
    canvas.clear
  end
end

# === Per-frame update ===

update do |dt|
  dt = [dt, 1.0 / 30].min  # cap to bound sim catchup on lag spikes
  paint(grid, active, dirty, brush_x, brush_y, material) if mouse_held && brush_y >= 0

  sim_accum += SIM_RATE * dt
  count = sim_accum.to_i
  sim_accum -= count
  count.times { step(grid, active, next_active, dirty) }

  # Repaint only cells the sim or brush touched; `painted` skips duplicates
  # and cells that ended a frame back where they started
  k = 0
  while k < dirty.length
    i = dirty[k]
    cell = grid[i]
    if cell != painted[i]
      painted[i] = cell
      batches[cell] << [(i % COLS) * CELL, (i / COLS) * CELL, CELL, CELL]
    end
    k += 1
  end
  dirty.clear

  batches.each_with_index do |rects, mat|
    next if rects.empty?
    canvas.fill_rectangles(rectangles: rects, color: COLORS[mat])
    rects.clear
  end
end

show
