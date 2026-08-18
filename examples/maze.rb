# Maze generator
# Recursive backtracking carves a perfect maze, then you steer through it.
#
# The orange dot is the algorithm's frontier; watch it wander through the
# grid until every cell has been visited. Once the maze is complete, steer
# the red player from the upper-left corner to the green goal in the
# bottom-right with the arrow keys — or press `s` to auto-solve and watch
# the path trace itself. Reach the goal and every wall pulses through a
# rainbow. Press `r` for a fresh maze.

require 'ruby2d'

# === Tunables ===

WIDTH = 800           # window width in pixels
HEIGHT = 600          # window height in pixels
COLS = 40             # grid columns
ROWS = 30             # grid rows
CELL = WIDTH / COLS   # cell size in pixels
GOAL_C = COLS - 1     # goal cell column (bottom-right)
GOAL_R = ROWS - 1     # goal cell row
STEPS_PER_SEC = 240   # DFS steps per second during generation
SOLVE_SPEED = 30      # cells per second the auto-solver traces the path
RAINBOW_SPEED = 0.35  # rainbow cycles per second during the victory pulse
RAINBOW_SCALE = 0.03  # hue shift per cell along the diagonal rainbow wave
RAINBOW_SAT = 0.85    # saturation of the pulse (0 = white, 1 = pure hue)

# === Window ===

set title: 'Ruby 2D ▸ Examples ▸ Maze generator', width: WIDTH, height: HEIGHT, background: [0.04, 0.06, 0.10, 1]
set close_on_esc: true

WALL_COLOR = [0.85, 0.9, 1.0, 1]
HEAD_COLOR = [1.0, 0.8, 0.3, 1]
PLAYER_COLOR = [0.95, 0.45, 0.30, 1]
GOAL_COLOR = [0.4, 0.85, 0.4, 1]
TRACE_COLOR = [0.45, 0.9, 1.0, 0.85]   # auto-solver's path trace

NORTH = 1
EAST  = 2
SOUTH = 4
WEST  = 8
ALL_WALLS = NORTH | EAST | SOUTH | WEST
DELTA = { NORTH => [0, -1], EAST => [1, 0], SOUTH => [0, 1], WEST => [-1, 0] }
OPPOSITE = { NORTH => SOUTH, EAST => WEST, SOUTH => NORTH, WEST => EAST }
DIRS = [NORTH, EAST, SOUTH, WEST]

# Pre-create wall lines. h_walls[er][c] is the horizontal segment at row-edge
# `er` and column `c`. v_walls[r][ec] is the vertical segment at row `r` and
# column-edge `ec`. Knocking down a wall hides its line.
h_walls = Array.new(ROWS + 1) do |er|
  Array.new(COLS) do |c|
    Line.new(x1: c * CELL, y1: er * CELL,
             x2: (c + 1) * CELL, y2: er * CELL,
             stroke_width: 2, color: WALL_COLOR, z: 2)
  end
end
v_walls = Array.new(ROWS) do |r|
  Array.new(COLS + 1) do |ec|
    Line.new(x1: ec * CELL, y1: r * CELL,
             x2: ec * CELL, y2: (r + 1) * CELL,
             stroke_width: 2, color: WALL_COLOR, z: 2)
  end
end

head = Circle.new(x: CELL / 2.0, y: CELL / 2.0,
                  radius: CELL * 0.35, color: HEAD_COLOR, z: 5)
player = Circle.new(x: CELL / 2.0, y: CELL / 2.0,
                    radius: CELL * 0.35, color: PLAYER_COLOR, z: 5, visible: false)
Circle.new(x: (GOAL_C + 0.5) * CELL, y: (GOAL_R + 0.5) * CELL,
           radius: CELL * 0.4, color: GOAL_COLOR, z: 4)

# === Mutable state ===

walls_intact = nil
visited = nil
stack = nil
generating = true
player_c = 0
player_r = 0
step_accum = 0.0
solving = false        # auto-solver is animating the trace
solved = false         # goal reached — the rainbow pulse is running
solution = nil         # list of [c, r] cells from the player to the goal
solve_index = 0        # how far along `solution` the trace has drawn
solve_accum = 0.0      # fractional cells owed to the trace this frame
celebrate_t = 0.0      # seconds elapsed into the victory pulse
trace = []             # Line segments drawn along the solved path

def hide_wall(h_walls, v_walls, r, c, side)
  case side
  when NORTH then h_walls[r][c].visible = false
  when SOUTH then h_walls[r + 1][c].visible = false
  when EAST  then v_walls[r][c + 1].visible = false
  when WEST  then v_walls[r][c].visible = false
  end
end

def reset_walls(h_walls, v_walls)
  h_walls.each { |row| row.each { |w| w.visible = true; w.color = WALL_COLOR } }
  v_walls.each { |row| row.each { |w| w.visible = true; w.color = WALL_COLOR } }
end

def step_dfs(walls_intact, visited, stack, h_walls, v_walls)
  c, r = stack.last
  unvisited = DIRS.select do |d|
    dc, dr = DELTA[d]
    nc = c + dc
    nr = r + dr
    nc.between?(0, COLS - 1) && nr.between?(0, ROWS - 1) && !visited[nr][nc]
  end
  if unvisited.empty?
    stack.pop
  else
    d = unvisited.sample
    dc, dr = DELTA[d]
    nc = c + dc
    nr = r + dr
    walls_intact[r][c] &= ~d
    walls_intact[nr][nc] &= ~OPPOSITE[d]
    hide_wall(h_walls, v_walls, r, c, d)
    visited[nr][nc] = true
    stack.push([nc, nr])
  end
end

# Breadth-first search from (start_c, start_r) to the goal, returning the
# path as a list of [c, r] cells. The maze is perfect (exactly one route
# between any two cells), so that path is unique. `from[r][c]` records the
# direction stepping back toward the start, walked in reverse to rebuild it.
def solve_path(walls_intact, start_c, start_r)
  from = Array.new(ROWS) { Array.new(COLS) }
  seen = Array.new(ROWS) { Array.new(COLS, false) }
  seen[start_r][start_c] = true
  queue = [[start_c, start_r]]
  until queue.empty?
    c, r = queue.shift
    break if c == GOAL_C && r == GOAL_R
    DIRS.each do |d|
      next unless (walls_intact[r][c] & d) == 0
      dc, dr = DELTA[d]
      nc = c + dc
      nr = r + dr
      next if seen[nr][nc]
      seen[nr][nc] = true
      from[nr][nc] = OPPOSITE[d]
      queue.push([nc, nr])
    end
  end
  path = []
  c = GOAL_C
  r = GOAL_R
  loop do
    path.unshift([c, r])
    break if c == start_c && r == start_r
    back = from[r][c]
    break unless back
    dc, dr = DELTA[back]
    c += dc
    r += dr
  end
  path
end

# Write an HSV color (fixed saturation and value) straight into an existing
# Color's channels — no allocation, so recoloring every wall each frame
# during the victory pulse stays cheap. `hue` may be any value; only its
# fractional position within each unit interval picks the color.
def paint_hue(color, hue)
  h = hue - hue.floor
  i = (h * 6).to_i
  f = h * 6 - i
  min = 1.0 - RAINBOW_SAT          # the two non-peak channels bottom out here
  down = 1.0 - f * RAINBOW_SAT
  up   = 1.0 - (1.0 - f) * RAINBOW_SAT
  case i % 6
  when 0 then color.r = 1.0; color.g = up;  color.b = min
  when 1 then color.r = down; color.g = 1.0; color.b = min
  when 2 then color.r = min; color.g = 1.0; color.b = up
  when 3 then color.r = min; color.g = down; color.b = 1.0
  when 4 then color.r = up;  color.g = min; color.b = 1.0
  else        color.r = 1.0; color.g = min; color.b = down
  end
end

reset = lambda do
  walls_intact = Array.new(ROWS) { Array.new(COLS, ALL_WALLS) }
  visited = Array.new(ROWS) { Array.new(COLS, false) }
  visited[0][0] = true
  stack = [[0, 0]]
  reset_walls(h_walls, v_walls)
  generating = true
  solving = false
  solved = false
  solution = nil
  solve_index = 0
  solve_accum = 0.0
  celebrate_t = 0.0
  trace.each(&:remove)
  trace.clear
  player_c = 0
  player_r = 0
  step_accum = 0.0
  player.x = CELL / 2.0
  player.y = CELL / 2.0
  player.visible = false
  head.x = CELL / 2.0
  head.y = CELL / 2.0
  head.visible = true
end

# Kick off the auto-solver from the player's current cell. Ignored while the
# maze is still being carved or a solve/celebration is already under way.
start_solve = lambda do
  next if generating || solving || solved
  solution = solve_path(walls_intact, player_c, player_r)
  solve_index = 0
  solve_accum = 0.0
  solving = true
end

# Enter the solved state: stop the solver and start the rainbow pulse.
mark_solved = lambda do
  solving = false
  solved = true
  celebrate_t = 0.0
end

reset.call

# === Input ===

on :key_down do |event|
  if event.key? :r
    reset.call
    next
  end
  if event.key? :s
    start_solve.call
    next
  end
  next if generating || solving || solved
  move = case event.key
         when :up    then NORTH
         when :down  then SOUTH
         when :left  then WEST
         when :right then EAST
         end
  next unless move
  if (walls_intact[player_r][player_c] & move) == 0
    dc, dr = DELTA[move]
    player_c += dc
    player_r += dr
    player.x = (player_c + 0.5) * CELL
    player.y = (player_r + 0.5) * CELL
    mark_solved.call if player_c == GOAL_C && player_r == GOAL_R
  end
end

# === Per-frame update ===

update do |dt|
  if generating
    step_accum += STEPS_PER_SEC * dt
    count = step_accum.to_i
    step_accum -= count
    count.times do
      if stack.empty?
        generating = false
        head.visible = false
        player.visible = true
        break
      end
      step_dfs(walls_intact, visited, stack, h_walls, v_walls)
    end
    if generating && !stack.empty?
      c, r = stack.last
      head.x = (c + 0.5) * CELL
      head.y = (r + 0.5) * CELL
    end
    next
  end

  # Auto-solver: advance along the solution, laying a trace segment between
  # each pair of cells and walking the player forward as it goes.
  if solving
    solve_accum += SOLVE_SPEED * dt
    while solve_accum >= 1.0 && solve_index < solution.length - 1
      solve_accum -= 1.0
      solve_index += 1
      pc, pr = solution[solve_index - 1]
      nc, nr = solution[solve_index]
      trace << Line.new(x1: (pc + 0.5) * CELL, y1: (pr + 0.5) * CELL,
                        x2: (nc + 0.5) * CELL, y2: (nr + 0.5) * CELL,
                        stroke_width: 4, color: TRACE_COLOR, z: 3)
      player_c = nc
      player_r = nr
      player.x = (nc + 0.5) * CELL
      player.y = (nr + 0.5) * CELL
    end
    mark_solved.call if solve_index >= solution.length - 1
    next
  end

  # Victory pulse: sweep a diagonal rainbow wave across the standing walls by
  # rewriting each wall's color in place (see `paint_hue`).
  if solved
    celebrate_t += dt
    phase = celebrate_t * RAINBOW_SPEED
    h_walls.each_with_index do |row, er|
      row.each_with_index do |w, c|
        paint_hue(w.color, (er + c) * RAINBOW_SCALE + phase) if w.visible
      end
    end
    v_walls.each_with_index do |row, r|
      row.each_with_index do |w, ec|
        paint_hue(w.color, (r + ec) * RAINBOW_SCALE + phase) if w.visible
      end
    end
  end
end

show
