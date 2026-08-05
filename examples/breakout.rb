# Breakout
# Classic brick breaker — bounce the ball into the wall and clear the board.
#
# Move the paddle with the mouse, arrow keys, or the gamepad dpad, and
# press space (or the south button) to launch. Press `r` to reset.

require 'ruby2d'

# === Tunables ===

WIDTH = 800              # window width in pixels
HEIGHT = 600             # window height in pixels
PADDLE_W = 110           # paddle width in pixels
PADDLE_H = 16            # paddle height in pixels
PADDLE_SPEED = 840       # paddle keyboard speed (px/sec)
BALL_R = 8               # ball radius in pixels
BALL_VX_INIT = 480       # initial ball horizontal velocity (px/sec)
BALL_VY_INIT = -600      # initial ball vertical velocity (px/sec)
BOUNCE_HIT_SCALE = 720   # paddle-bounce horizontal velocity scale (px/sec)
BRICK_ROWS = 6           # number of brick rows
BRICK_COLS = 10          # number of brick columns
BRICK_W = 68             # brick width in pixels
BRICK_H = 24             # brick height in pixels
BRICK_GAP = 6            # gap between bricks in pixels

# === Window ===

set title: 'Ruby 2D ▸ Examples ▸ Breakout', width: WIDTH, height: HEIGHT, background: '#101828'
set close_on_esc: true
set cursor: :hidden

# === Helpers ===

Brick = Struct.new(:shape, :alive)

def circle_hits_rect?(circle, rect)
  closest_x = circle.x.clamp(rect.x, rect.x + rect.width)
  closest_y = circle.y.clamp(rect.y, rect.y + rect.height)
  dx = circle.x - closest_x
  dy = circle.y - closest_y
  dx * dx + dy * dy <= circle.radius * circle.radius
end

# === Persistent renderables ===

score_text = Text.new('Score: 0', x: 16, y: 12, size: 18, color: '#e5e7eb')
status_text = Text.new('Press SPACE to launch', x: 285, y: 12, size: 18, color: '#9ca3af')

paddle = Rectangle.new(x: WIDTH / 2 - PADDLE_W / 2, y: HEIGHT - 48,
                       width: PADDLE_W, height: PADDLE_H, color: '#38bdf8')
ball = Circle.new(x: WIDTH / 2, y: paddle.y - BALL_R - 2,
                  radius: BALL_R, color: '#f8fafc')

bricks = []
colors = ['#ef4444', '#f97316', '#facc15', '#22c55e', '#06b6d4', '#8b5cf6']
start_x = (WIDTH - BRICK_COLS * BRICK_W - (BRICK_COLS - 1) * BRICK_GAP) / 2

BRICK_ROWS.times do |row|
  BRICK_COLS.times do |col|
    bricks << Brick.new(
      Rectangle.new(
        x: start_x + col * (BRICK_W + BRICK_GAP),
        y: 70 + row * (BRICK_H + BRICK_GAP),
        width: BRICK_W, height: BRICK_H,
        color: colors[row]
      ),
      true
    )
  end
end

# === Mutable state ===

ball_vx = BALL_VX_INIT
ball_vy = BALL_VY_INIT
launched = false
score = 0
left_down = false
right_down = false

reset = lambda do
  score = 0
  score_text.content = 'Score: 0'
  status_text.content = 'Press SPACE to launch'
  paddle.x = WIDTH / 2 - PADDLE_W / 2
  ball.x = WIDTH / 2
  ball.y = paddle.y - BALL_R - 2
  ball_vx = BALL_VX_INIT
  ball_vy = BALL_VY_INIT
  launched = false
  bricks.each do |brick|
    brick.alive = true
    brick.shape.add
  end
end

# === Input ===

on :mouse_move do |event|
  paddle.x = (event.x - PADDLE_W / 2).clamp(0, WIDTH - PADDLE_W)
end

on key_down: :left do
  left_down = true
end

on key_down: :right do
  right_down = true
end

on key_up: :left do
  left_down = false
end

on key_up: :right do
  right_down = false
end

on key_down: :space, gamepad_button_down: :south do
  launched = true
  status_text.content = ''
end

on key_down: :r do
  reset.call
end

# === Per-frame update ===

update do |dt|
  # Combine keyboard with the dpad held state across all connected pads,
  # so either input drives the paddle and they don't fight each other.
  go_left  = left_down  || gamepads.any? { |p| p.held?(:dpad_left) }
  go_right = right_down || gamepads.any? { |p| p.held?(:dpad_right) }

  paddle.x -= PADDLE_SPEED * dt if go_left
  paddle.x += PADDLE_SPEED * dt if go_right
  paddle.x = paddle.x.clamp(0, WIDTH - PADDLE_W)

  unless launched
    ball.x = paddle.x + PADDLE_W / 2
    ball.y = paddle.y - BALL_R - 2
    next
  end

  ball.x += ball_vx * dt
  ball.y += ball_vy * dt

  if ball.x - BALL_R < 0 || ball.x + BALL_R > WIDTH
    ball_vx *= -1
    ball.x = ball.x.clamp(BALL_R, WIDTH - BALL_R)
  end

  if ball.y - BALL_R < 0
    ball_vy = ball_vy.abs
    ball.y = BALL_R
  elsif ball.y - BALL_R > HEIGHT
    launched = false
    status_text.content = 'Missed · Press SPACE to relaunch'
  end

  if ball_vy > 0 && circle_hits_rect?(ball, paddle)
    hit = ((ball.x - paddle.x) / PADDLE_W - 0.5) * 2.0
    ball_vx = hit * BOUNCE_HIT_SCALE
    ball_vy = -ball_vy.abs
    ball.y = paddle.y - BALL_R
  end

  bricks.each do |brick|
    next unless brick.alive && circle_hits_rect?(ball, brick.shape)

    brick.alive = false
    brick.shape.remove
    ball_vy *= -1
    score += 10
    score_text.content = "Score: #{score}"
    break
  end

  if bricks.none?(&:alive)
    launched = false
    status_text.content = 'Cleared · Press R to play again'
  end
end

show
