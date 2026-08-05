# Ray casting maze
# A small pseudo-3D maze rendered from a 2D grid by ray casting.
#
# Use W/S to move and A/D to turn. The top-left mini map shows the player
# and viewing direction. Walls are found with DDA grid traversal: each ray
# hops from grid line to grid line (the only places a wall can begin)
# instead of marching in tiny steps, so a frame's ray casting stays cheap —
# around ten steps per ray. Everything on screen is a persistent shape
# created once and mutated in place each frame, which is far cheaper than
# redrawing from scratch — especially on the web build.

require 'ruby2d'

# === Tunables ===

WIDTH = 800             # window width in pixels
HEIGHT = 500            # window height in pixels
FOV = Math::PI / 3      # horizontal field of view (radians)
RAYS = 160              # number of rays cast across the view (column count)
MAX_DIST = 12.0         # maximum ray distance in grid units before giving up
TURN_RATE = 3.3         # turn speed in rad/sec
MOVE_SPEED = 3.6        # forward/back speed in grid units/sec
MAP_SCALE = 16          # mini-map pixels per grid cell

# === Window ===

set title: 'Ruby 2D ▸ Examples ▸ Ray casting maze', width: WIDTH, height: HEIGHT, background: '#0f172a'
set close_on_esc: true

# === Map ===

MAP = [
  '##########',
  '#........#',
  '#..##....#',
  '#.....#..#',
  '#.##.....#',
  '#....##..#',
  '#........#',
  '##########'
].map(&:chars)

# Wall lookup as booleans — the ray march tests cells thousands of times per
# frame, so precompute instead of comparing map characters in the hot loop.
SOLID = MAP.map { |row| row.map { |cell| cell == '#' } }

# === State ===

# Start tucked in the top-left corner facing diagonally into the maze, so the
# open space ahead reads as somewhere to go rather than a wall in your face.
px = 1.5
py = 1.5
angle = Math::PI / 4
keys = {}

wall_at = lambda do |x, y|
  return true if x < 0 || y < 0 || y >= SOLID.length || x >= SOLID[0].length

  SOLID[y][x]
end

# === Persistent shapes ===
# Created once in back-to-front order (equal z draws in creation order):
# sky and floor, then the wall columns over them, then the mini map on top.

Rectangle.new(x: 0, y: 0, width: WIDTH, height: HEIGHT / 2, color: '#1e293b')
Rectangle.new(x: 0, y: HEIGHT / 2, width: WIDTH, height: HEIGHT / 2, color: '#111827')

# One column per ray. The x position and width never change; each frame the
# update block reshapes y/height and dims the color by distance in place.
col_w = WIDTH / RAYS.to_f + 1
columns = Array.new(RAYS) do |i|
  Rectangle.new(x: i * WIDTH / RAYS.to_f, y: HEIGHT / 2, width: col_w, height: 0,
                color: [0.25, 0.55, 0.95, 1])
end

# The mini map never changes; only the player marker on it moves.
MAP.each_with_index do |row, y|
  row.each_with_index do |cell, x|
    Rectangle.new(x: 14 + x * MAP_SCALE, y: 14 + y * MAP_SCALE,
                  width: MAP_SCALE - 1, height: MAP_SCALE - 1,
                  color: cell == '#' ? '#e5e7eb' : '#334155')
  end
end

player_dot = Circle.new(x: 0, y: 0, radius: 4, color: '#f97316')
player_dir = Line.new(x1: 0, y1: 0, x2: 0, y2: 0, stroke_width: 2, color: '#f97316')

# === Input ===

on :key_down do |event|
  keys[event.key] = true
end

on :key_up do |event|
  keys[event.key] = false
end

# === Per-frame update ===

update do |dt|
  angle -= TURN_RATE * dt if keys['a'] || keys['left']
  angle += TURN_RATE * dt if keys['d'] || keys['right']

  move = 0
  move += MOVE_SPEED * dt if keys['w'] || keys['up']
  move -= MOVE_SPEED * dt if keys['s'] || keys['down']
  nx = px + Math.cos(angle) * move
  ny = py + Math.sin(angle) * move
  unless wall_at.call(nx.floor, py.floor)
    px = nx
  end
  unless wall_at.call(px.floor, ny.floor)
    py = ny
  end

  # Cast one ray per wall column and reshape the column to the hit
  RAYS.times do |i|
    ray_angle = angle - FOV / 2 + FOV * i / (RAYS - 1)
    dx = Math.cos(ray_angle)
    dy = Math.sin(ray_angle)

    # DDA setup: `delta_x` is the distance along the ray between two vertical
    # grid lines (`delta_y` between horizontals), and `side_x`/`side_y` are the
    # ray distances from the player to the first of each. An axis-parallel ray
    # never crosses one set of lines — a huge delta keeps it out of the race.
    map_x = px.floor
    map_y = py.floor
    delta_x = dx.abs < 1e-12 ? 1e30 : 1.0 / dx.abs
    delta_y = dy.abs < 1e-12 ? 1e30 : 1.0 / dy.abs
    step_x = dx < 0 ? -1 : 1
    step_y = dy < 0 ? -1 : 1
    side_x = dx < 0 ? (px - map_x) * delta_x : (map_x + 1 - px) * delta_x
    side_y = dy < 0 ? (py - map_y) * delta_y : (map_y + 1 - py) * delta_y

    # Walk the grid: always advance to the nearer of the two upcoming grid
    # lines, entering one new cell per step, until that cell is a wall. The
    # hit distance is exact, unlike a fixed-step march.
    dist = 0.0
    until wall_at.call(map_x, map_y) || dist > MAX_DIST
      if side_x < side_y
        dist = side_x
        side_x += delta_x
        map_x += step_x
      else
        dist = side_y
        side_y += delta_y
        map_y += step_y
      end
    end

    corrected = dist * Math.cos(ray_angle - angle)
    wall_h = (HEIGHT * 0.85 / corrected).clamp(12, HEIGHT)
    shade = (1.0 - corrected / MAX_DIST).clamp(0.12, 1.0)

    # Mutate in place — no new shapes or colors per frame
    column = columns[i]
    column.y = HEIGHT / 2 - wall_h / 2
    column.height = wall_h
    color = column.color
    color.r = 0.25 * shade
    color.g = 0.55 * shade
    color.b = 0.95 * shade
  end

  # Move the player marker on the mini map
  player_dot.x = 14 + px * MAP_SCALE
  player_dot.y = 14 + py * MAP_SCALE
  player_dir.x1 = player_dot.x
  player_dir.y1 = player_dot.y
  player_dir.x2 = 14 + (px + Math.cos(angle) * 0.8) * MAP_SCALE
  player_dir.y2 = 14 + (py + Math.sin(angle) * 0.8) * MAP_SCALE
end

show
