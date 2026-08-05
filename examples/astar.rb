# A* pathfinding
# Paint walls, then watch A*'s frontier fill in and trace the optimal path.
#
# Click and drag to paint walls; click and drag the green start or red
# goal to move them. Press SPACE to run A* — the search frontier fills
# in cell by cell, then the optimal path is highlighted in yellow. C
# clears the search overlay; R clears the grid back to empty.

require 'ruby2d'

# === Tunables ===

WIDTH = 800              # window width in pixels
HEIGHT = 600             # window height in pixels
HEADER = 40              # HUD strip height in pixels
CELL = 16                # rendered cell size in pixels
REVEAL_PER_FRAME = 14    # cells revealed per frame during the playback

GRID_TOP = HEADER
GRID_H   = HEIGHT - GRID_TOP
COLS = WIDTH  / CELL     # 50
ROWS = GRID_H / CELL     # 35

C_EMPTY  = [0.06, 0.08, 0.13, 1].freeze
C_WALL   = [0.50, 0.52, 0.62, 1].freeze
C_CLOSED = [0.18, 0.32, 0.55, 1].freeze
C_PATH   = [0.99, 0.86, 0.32, 1].freeze
C_START  = [0.32, 0.85, 0.40, 1].freeze
C_GOAL   = [0.95, 0.30, 0.30, 1].freeze

HEADER_BG   = '#131c2e'  # HUD strip background
HEADER_RULE = '#1f2a40'  # rule line under the HUD strip
HINT_COLOR  = '#cbd5e1'  # controls hint text
DIM_COLOR   = '#94a3b8'  # status label and counter
WARN_COLOR  = '#fbbf24'  # "no path" indicator

# === Window ===

set title: 'Ruby 2D ▸ Examples ▸ A* pathfinding',
    width: WIDTH, height: HEIGHT, background: '#0b1220'
set close_on_esc: true

# === HUD ===

canvas = Canvas.new(x: 0, y: GRID_TOP, width: WIDTH, height: GRID_H, fill: C_EMPTY)
Rectangle.new(x: 0, y: 0, width: WIDTH, height: HEADER, color: HEADER_BG)
Line.new(x1: 0, y1: HEADER, x2: WIDTH, y2: HEADER, stroke_width: 1, color: HEADER_RULE)

Text.new('CLICK paint  ·  DRAG start/goal  ·  SPACE run  ·  C clear  ·  R reset',
         x: 14, y: 13, size: 14, color: HINT_COLOR)
no_path_text = Text.new('no path', x: WIDTH - 230, y: 13, size: 14, color: WARN_COLOR, visible: false)
Text.new('Explored', x: WIDTH - 160, y: 13, size: 14, color: DIM_COLOR)
explored_number = Text.new('0', x: WIDTH - 70, y: 13, size: 14, color: DIM_COLOR)

# === Helpers ===

def manhattan(a, b)
  (a[0] - b[0]).abs + (a[1] - b[1]).abs
end

# === State ===

walls = Array.new(ROWS) { Array.new(COLS, false) }
start_cell = [3, ROWS / 2]
goal_cell  = [COLS - 4, ROWS / 2]
closed_order = []        # cells closed by A*, in order
path = []                # final reconstructed path
reveal_idx = 0           # how many of `closed_order` have been drawn so far
mouse_mode = :none
dirty = true

# === Operations ===

clear_search = lambda do
  closed_order.clear
  path.clear
  reveal_idx = 0
  dirty = true
end

# Standard A* with Manhattan heuristic and 4-connected moves. Uses
# `min_by` for the priority pick — O(n²) over the search but fine at
# this grid size, and it keeps the example free of an external heap.
run_astar = lambda do
  clear_search.call
  open = [start_cell.dup]
  open_set = { start_cell => true }
  came_from = {}
  g_score = { start_cell => 0 }
  f_score = { start_cell => manhattan(start_cell, goal_cell) }
  closed = {}

  until open.empty?
    current = open.min_by { |c| f_score[c] }
    open.delete(current)
    open_set.delete(current)
    closed[current] = true
    closed_order << current

    if current == goal_cell
      n = current
      while n
        path.unshift(n)
        n = came_from[n]
      end
      dirty = true
      return
    end

    [[1, 0], [-1, 0], [0, 1], [0, -1]].each do |dx, dy|
      nx = current[0] + dx
      ny = current[1] + dy
      next if nx < 0 || nx >= COLS || ny < 0 || ny >= ROWS
      next if walls[ny][nx]

      neighbor = [nx, ny]
      next if closed[neighbor]

      tentative_g = g_score[current] + 1
      next if g_score[neighbor] && tentative_g >= g_score[neighbor]

      came_from[neighbor] = current
      g_score[neighbor] = tentative_g
      f_score[neighbor] = tentative_g + manhattan(neighbor, goal_cell)
      unless open_set[neighbor]
        open << neighbor
        open_set[neighbor] = true
      end
    end
  end
  dirty = true
end

# === Input ===

on :mouse_down do |event|
  next if event.y < GRID_TOP

  cx = event.x / CELL
  cy = (event.y - GRID_TOP) / CELL
  next if cx < 0 || cx >= COLS || cy < 0 || cy >= ROWS

  cell = [cx, cy]
  mouse_mode = if cell == start_cell
                 :move_start
               elsif cell == goal_cell
                 :move_goal
               elsif walls[cy][cx]
                 walls[cy][cx] = false
                 clear_search.call
                 :erase
               else
                 walls[cy][cx] = true
                 clear_search.call
                 :paint
               end
end

on :mouse_up do
  mouse_mode = :none
end

on :mouse_move do |event|
  next if mouse_mode == :none
  next if event.y < GRID_TOP

  cx = event.x / CELL
  cy = (event.y - GRID_TOP) / CELL
  next if cx < 0 || cx >= COLS || cy < 0 || cy >= ROWS

  case mouse_mode
  when :paint
    unless walls[cy][cx]
      walls[cy][cx] = true
      clear_search.call
    end
  when :erase
    if walls[cy][cx]
      walls[cy][cx] = false
      clear_search.call
    end
  when :move_start
    if [cx, cy] != start_cell
      start_cell[0] = cx
      start_cell[1] = cy
      walls[cy][cx] = false
      clear_search.call
    end
  when :move_goal
    if [cx, cy] != goal_cell
      goal_cell[0] = cx
      goal_cell[1] = cy
      walls[cy][cx] = false
      clear_search.call
    end
  end
end

on key_down: :space do
  run_astar.call
end

on key_down: :r do
  walls.each { |row| row.fill(false) }
  clear_search.call
end

on key_down: :c do
  clear_search.call
end

# === Per-frame update ===

# The grid only needs a redraw when something has changed (mouse paint,
# search complete, animation step). Marking `dirty` lets the rest of
# the time skip the bucketing + canvas calls entirely.
update do
  if reveal_idx < closed_order.length
    reveal_idx += REVEAL_PER_FRAME
    reveal_idx = closed_order.length if reveal_idx > closed_order.length
    dirty = true
  end

  next unless dirty

  canvas.clear
  wall_rects = []
  ROWS.times do |r|
    row = walls[r]
    COLS.times do |c|
      wall_rects << [c * CELL, r * CELL, CELL, CELL] if row[c]
    end
  end
  canvas.fill_rectangles(rectangles: wall_rects, color: C_WALL) unless wall_rects.empty?

  closed_rects = []
  i = 0
  while i < reveal_idx
    cell = closed_order[i]
    closed_rects << [cell[0] * CELL, cell[1] * CELL, CELL, CELL] unless cell == start_cell || cell == goal_cell
    i += 1
  end
  canvas.fill_rectangles(rectangles: closed_rects, color: C_CLOSED) unless closed_rects.empty?

  if reveal_idx >= closed_order.length && !path.empty?
    path_rects = []
    path.each do |cell|
      next if cell == start_cell || cell == goal_cell

      path_rects << [cell[0] * CELL, cell[1] * CELL, CELL, CELL]
    end
    canvas.fill_rectangles(rectangles: path_rects, color: C_PATH) unless path_rects.empty?
  end

  canvas.fill_rectangle(x: start_cell[0] * CELL, y: start_cell[1] * CELL,
                        width: CELL, height: CELL, color: C_START)
  canvas.fill_rectangle(x: goal_cell[0] * CELL, y: goal_cell[1] * CELL,
                        width: CELL, height: CELL, color: C_GOAL)

  # HUD readout: cells explored so far (ticks up during playback), plus a
  # "no path" flag once an exhausted search reveals no route to the goal.
  count = reveal_idx.to_s
  explored_number.content = count unless explored_number.content == count
  no_path_text.visible = closed_order.any? && reveal_idx >= closed_order.length && path.empty?

  dirty = false
end

show
