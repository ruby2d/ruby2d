# Benchmark — Mixed scene
#
# A representative 2D game scene combining the primitives users actually
# mix: a retained background image, animated sprites that bounce around,
# retained UI rectangles, static and dynamic text labels, and immediate-
# mode particles in a render block.
#
# Why it matters: the single-primitive benchmarks above each isolate one
# code path. Real apps don't — they juggle the scene graph, an update loop
# that mutates objects, dynamic text content, and an immediate-mode render
# block all at once. Regressions caused by interactions between those
# paths (cache thrashing, GC patterns triggered by one path slowing
# another) only show up here.

require 'ruby2d'
require 'ruby2d/benchmark'

W = 1280
H = 720

SPRITE_SIZE = 32
SPRITE_COUNT = 60
RECT_COUNT = 20
LABEL_COUNT = 10
DYNAMIC_LABEL_COUNT = 10
PARTICLE_COUNT = 150

Ruby2D::Benchmark.run('Mixed Scene') do
  set title: 'Ruby 2D Benchmark — Mixed Scene', width: W, height: H

  srand(42)

  # Background image stretched to full window
  Image.new("#{Ruby2D.test_images}/image.png", x: 0, y: 0, width: W, height: H)

  # Animated sprites that bounce around. Uses `colors.png` clipped into four
  # 25-px frames as a stand-in sprite sheet (see sprites.rb).
  sprite_path = "#{Ruby2D.test_images}/colors.png"
  sprites = []
  sprite_vels = []
  SPRITE_COUNT.times do
    sp = Sprite.new(sprite_path,
                    x: rand(W - SPRITE_SIZE), y: rand(H - SPRITE_SIZE),
                    width: SPRITE_SIZE, height: SPRITE_SIZE,
                    clip_width: 25, clip_height: 25,
                    time: 100)
    sp.play(loop: true)
    sprites << sp
    sprite_vels << [rand(-3.0..3.0), rand(-3.0..3.0)]
  end

  # UI rectangles (e.g. health bars, panels)
  ui_colors = %w[red green blue yellow purple]
  RECT_COUNT.times do |i|
    Rectangle.new(x: 20 + i * 60, y: 20,
                  width: 50, height: 12,
                  color: ui_colors[i % ui_colors.length])
  end

  # Static text labels (e.g. captions, player names)
  LABEL_COUNT.times do |i|
    Text.new("Label #{i}", size: 14,
             x: 20 + i * 120, y: 690, color: 'white')
  end

  # Dynamic text labels (e.g. score, FPS, frame counters)
  dynamic_labels = []
  DYNAMIC_LABEL_COUNT.times do |i|
    dynamic_labels << Text.new('0', size: 16,
                               x: 20 + i * 120, y: 50, color: 'yellow')
  end

  # Particles drawn each frame in immediate mode
  particle_colors = [
    [1.0, 0.4, 0.3, 0.8],
    [0.3, 0.7, 1.0, 0.8],
    [0.4, 1.0, 0.5, 0.8],
    [1.0, 0.8, 0.2, 0.8]
  ]
  particles = []
  PARTICLE_COUNT.times do
    particles << {
      x: rand(W).to_f, y: rand(H).to_f,
      vx: rand(-2.0..2.0), vy: rand(-2.0..2.0),
      r: rand(2.0..6.0),
      color: particle_colors.sample
    }
  end

  frame = 0

  update do
    frame += 1

    sprites.each_with_index do |sp, idx|
      vel = sprite_vels[idx]
      sp.x += vel[0]
      sp.y += vel[1]
      vel[0] = -vel[0] if sp.x < 0 || sp.x > W - SPRITE_SIZE
      vel[1] = -vel[1] if sp.y < 0 || sp.y > H - SPRITE_SIZE
    end

    dynamic_labels.each_with_index do |t, idx|
      t.content = "#{idx}: #{frame}"
    end

    particles.each do |p|
      p[:x] += p[:vx]
      p[:y] += p[:vy]
      p[:vx] = -p[:vx] if p[:x] < 0 || p[:x] > W
      p[:vy] = -p[:vy] if p[:y] < 0 || p[:y] > H
    end
  end

  render do
    particles.each do |p|
      Circle.render(x: p[:x], y: p[:y], radius: p[:r],
                    sectors: 16, color: p[:color])
    end
  end
end
