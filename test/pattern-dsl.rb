# DSL pattern

require 'ruby2d'

update do
  puts Time.now.to_f
end

render do
  Quad.draw(
    x1: 125, y1: 0,
    x2: 225, y2: 0,
    x3: 250, y3: 100,
    x4: 150, y4: 100,
    color: [
      [0.8, 0.3, 0.7, 0.8],
      [0.1, 0.9, 0.1, 1.0],
      [0.8, 0.5, 0.8, 1.0],
      [0.6, 0.4, 0.1, 1.0]
    ]
  )
end

show
