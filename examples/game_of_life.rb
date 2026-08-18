# Conway's Game of Life
# Paint live cells and watch Conway's classic cellular automaton unfold.
#
# Drag to paint live cells; right-click and drag to erase.
# Space pauses, n steps one generation, r randomizes, c clears.
# The world wraps at the edges, so gliders sail forever.

require 'ruby2d'

# === Tunables ===

WIDTH = 800                # window width in pixels
HEIGHT = 600               # window height in pixels
HEADER = 40                # HUD strip height in pixels
CELL = 10                  # cell size in pixels
COLS = WIDTH / CELL        # grid columns
ROWS = (HEIGHT - HEADER) / CELL  # grid rows
STEP_INTERVAL = 0.083      # seconds between generations
RANDOM_DENSITY = 0.2       # fraction of cells alive on randomize

ALIVE_COLOR = [0.25, 0.9, 0.65, 1]
DEAD_COLOR  = [0.04, 0.06, 0.1, 1]
HEADER_BG   = '#131c2e'
HEADER_RULE = '#1f2a40'
HINT_COLOR  = '#cbd5e1'
DIM_COLOR   = '#94a3b8'
PAUSE_COLOR = '#fbbf24'

# === Window ===

set title: "Ruby 2D ▸ Examples ▸ Conway's Game of Life", width: WIDTH, height: HEIGHT, background: '#0f172a'
set close_on_esc: true

# === HUD ===

canvas = Canvas.new(x: 0, y: HEADER, width: WIDTH, height: HEIGHT - HEADER, fill: DEAD_COLOR)
Rectangle.new(x: 0, y: 0, width: WIDTH, height: HEADER, color: HEADER_BG)
Line.new(x1: 0, y1: HEADER, x2: WIDTH, y2: HEADER, stroke_width: 1, color: HEADER_RULE)

Text.new('DRAG paint  ·  R-DRAG erase  ·  SPACE pause  ·  N step  ·  R random  ·  C clear',
         x: 14, y: 13, size: 14, color: HINT_COLOR)
paused_text = Text.new('paused', x: WIDTH - 230, y: 13, size: 14, color: PAUSE_COLOR, visible: false)
Text.new('Generation', x: WIDTH - 160, y: 13, size: 14, color: DIM_COLOR)
gen_number = Text.new('0', x: WIDTH - 70, y: 13, size: 14, color: DIM_COLOR)

# === Mutable state ===

grid = Array.new(ROWS) { Array.new(COLS) { rand < RANDOM_DENSITY ? 1 : 0 } }
next_grid = Array.new(ROWS) { Array.new(COLS, 0) }

paused = false
step_timer = STEP_INTERVAL
generation = 0
mouse_held = false
mouse_paint = 1
mouse_x = -1
mouse_y = -1

paint = lambda do |mx, my, value|
  return if my < HEADER

  c = mx / CELL
  r = (my - HEADER) / CELL
  grid[r][c] = value if r.between?(0, ROWS - 1) && c.between?(0, COLS - 1)
end

step = lambda do
  ROWS.times do |r|
    rm1 = (r - 1) % ROWS
    rp1 = (r + 1) % ROWS
    COLS.times do |c|
      cm1 = (c - 1) % COLS
      cp1 = (c + 1) % COLS
      n = grid[rm1][cm1] + grid[rm1][c] + grid[rm1][cp1] +
          grid[r][cm1]                  + grid[r][cp1] +
          grid[rp1][cm1] + grid[rp1][c] + grid[rp1][cp1]
      cell = grid[r][c]
      next_grid[r][c] = (cell == 1 && (n == 2 || n == 3)) || (cell == 0 && n == 3) ? 1 : 0
    end
  end
  grid, next_grid = next_grid, grid
  generation += 1
end

# === Input ===

on :mouse_down do |event|
  mouse_held = true
  mouse_paint = event.button?(:right) ? 0 : 1
  mouse_x = event.x
  mouse_y = event.y
end

on :mouse_up do
  mouse_held = false
end

on :mouse_move do |event|
  mouse_x = event.x
  mouse_y = event.y
end

on :key_down do |event|
  case event.key
  when :space
    paused = !paused
  when :n
    step.call
  when :r
    grid.each { |row| row.map! { rand < RANDOM_DENSITY ? 1 : 0 } }
    generation = 0
    step_timer = STEP_INTERVAL
  when :c
    grid.each { |row| row.fill(0) }
    generation = 0
    step_timer = STEP_INTERVAL
  end
end

# === Per-frame update ===

update do |dt|
  paint.call(mouse_x, mouse_y, mouse_paint) if mouse_held

  unless paused
    step_timer -= dt
    if step_timer <= 0
      step.call
      step_timer = STEP_INTERVAL
    end
  end

  gen_number.content = generation.to_s
  paused_text.visible = paused

  canvas.clear
  ROWS.times do |r|
    COLS.times do |c|
      next unless grid[r][c] == 1

      canvas.fill_rectangle(x: c * CELL, y: r * CELL,
                            width: CELL - 1, height: CELL - 1,
                            color: ALIVE_COLOR)
    end
  end
end

show
