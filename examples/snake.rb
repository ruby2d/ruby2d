# Snake
# Classic snake — steer with arrow keys, eat to grow, don't cross yourself.
#
# Eat the red square to grow longer and earn a point. Every five points
# the snake speeds up. The world wraps at the edges, but the snake dies
# if it crosses itself. Press `r` at any time to start a new game.

require 'ruby2d'

# === Tunables ===

WIDTH = 640                # window width in pixels
HEIGHT = 480               # window height in pixels
GRID = 20                  # cell size in pixels (smaller = bigger play area)
START_INTERVAL = 0.067     # seconds between moves at game start
MIN_INTERVAL = 0.025       # fastest cadence the snake will reach (seconds)
INTERVAL_STEP = 0.0083     # seconds shaved off the move interval per speedup
SPEEDUP_EVERY = 5          # speed up every N points
GROWTH = 2                 # segments added to the snake per apple eaten

COLS = WIDTH / GRID
ROWS = HEIGHT / GRID

SNAKE_COLOR = '#06d6a0'
FOOD_COLOR  = '#e94560'

# === Window ===

set title: 'Ruby 2D ▸ Examples ▸ Snake', width: WIDTH, height: HEIGHT, background: '#1b1b2f'
set close_on_esc: true

# === Helpers ===

def place_food(snake)
  pos = [rand(COLS), rand(ROWS)]
  pos = [rand(COLS), rand(ROWS)] while snake.include?(pos)
  pos
end

# === Mutable state ===

snake = []
segments = []
dir = [1, 0]
next_dir = [1, 0]
food = [0, 0]
score = 0
interval = START_INTERVAL  # current seconds between moves
move_timer = 0             # seconds until the next move
grow = 0
alive = true

# === HUD ===

label = Text.new('Score: 0', x: 10, y: 8, size: 18, color: '#f9fafb', z: 10)
food_sq = Square.new(size: GRID - 4, color: FOOD_COLOR)

reset = lambda do
  segments.each(&:remove)
  segments.clear

  snake.replace([[COLS / 2, ROWS / 2]])
  segments << Square.new(
    x: snake[0][0] * GRID + 1, y: snake[0][1] * GRID + 1,
    size: GRID - 2, color: SNAKE_COLOR
  )

  dir = [1, 0]
  next_dir = [1, 0]
  food = place_food(snake)
  food_sq.x = food[0] * GRID + 2
  food_sq.y = food[1] * GRID + 2
  score = 0
  interval = START_INTERVAL
  move_timer = 0  # first move runs immediately on next frame
  grow = 0
  alive = true
  label.content = 'Score: 0'
end

reset.call

# === Input ===

on :key_down do |event|
  case event.key
  when 'up'    then next_dir = [0, -1] unless dir == [0,  1]
  when 'down'  then next_dir = [0,  1] unless dir == [0, -1]
  when 'left'  then next_dir = [-1, 0] unless dir == [1,  0]
  when 'right' then next_dir = [1,  0] unless dir == [-1, 0]
  when 'r'     then reset.call
  end
end

# === Per-frame update ===

update do |dt|
  next unless alive

  move_timer -= dt
  next if move_timer > 0

  dir = next_dir
  head = [(snake[0][0] + dir[0]) % COLS, (snake[0][1] + dir[1]) % ROWS]

  if snake.include?(head)
    alive = false
    label.content = "Game Over!  Score: #{score}  ▸  press r to restart"
    next
  end

  snake.unshift(head)
  segments.unshift(
    Square.new(x: head[0] * GRID + 1, y: head[1] * GRID + 1,
               size: GRID - 2, color: SNAKE_COLOR)
  )

  if head == food
    score += 1
    label.content = "Score: #{score}"
    interval = [MIN_INTERVAL, interval - INTERVAL_STEP].max if score % SPEEDUP_EVERY == 0
    grow += GROWTH
    food = place_food(snake)
    food_sq.x = food[0] * GRID + 2
    food_sq.y = food[1] * GRID + 2
  end

  if grow > 0
    grow -= 1
  else
    snake.pop
    segments.last.remove
    segments.pop
  end

  segments.each_with_index do |s, i|
    g = i.to_f / [segments.size - 1, 1].max
    s.color = [0.02 + 0.04 * g, 0.84 - 0.5 * g, 0.63 - 0.3 * g, 1]
  end

  move_timer = interval
end

show
