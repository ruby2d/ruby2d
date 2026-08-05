# Benchmark — Retained mutation
#
# Adds 3,600 squares to the window and updates each square's x and y every
# frame inside an update block. Counterpart to retained.rb — the diff
# isolates the cost of attribute setters from steady-state render throughput.
#
# Why it matters: every moving object in a real game (player, projectiles,
# enemies, particles) hits this path on every frame. If x= and y= allocate
# or do redundant work, an otherwise idle retained-mode app will burn CPU
# and trigger GC pauses.

require 'ruby2d'
require 'ruby2d/benchmark'

COLS = 80  # 1280 / 16
ROWS = 45  # 720 / 16
SIZE = 16
MAX_X = 1280 - SIZE
MAX_Y = 720 - SIZE

Ruby2D::Benchmark.run('Retained (Mutation)') do
  set title: 'Ruby 2D Benchmark — Retained (Mutation)', width: 1280, height: 720

  colors = %w[red blue green yellow purple orange white aqua]
  squares = []
  velocities = []

  srand(42)

  COLS.times do |i|
    ROWS.times do |j|
      squares << Square.new(x: i * SIZE, y: j * SIZE, size: SIZE,
                            color: colors[(i + j) % colors.length])
      velocities << [rand(-2.0..2.0), rand(-2.0..2.0)]
    end
  end

  update do
    squares.each_with_index do |sq, idx|
      vel = velocities[idx]

      nx = sq.x + vel[0]
      ny = sq.y + vel[1]

      if nx < 0 || nx > MAX_X
        vel[0] = -vel[0]
        nx = sq.x + vel[0]
      end
      if ny < 0 || ny > MAX_Y
        vel[1] = -vel[1]
        ny = sq.y + vel[1]
      end

      sq.x = nx
      sq.y = ny
    end
  end
end
