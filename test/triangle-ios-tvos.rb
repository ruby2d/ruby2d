require 'ruby2d'

set title: "Hello Triangle",
    width: get(:display_width), height: get(:display_height),
    borderless: true

Rectangle.new(
  x: 0, y: 0,
  width: get(:width), height: get(:height),
  color: [[1, 0, 1, 1], [0, 1, 0, 1], [0, 0, 1, 1], [0, 1, 1, 1]]
)

Triangle.new(
  x1: get(:width) / 2, y1: get(:height) / 5,
  x2: get(:width),     y2: get(:height) / 1.5,
  x3: 0,               y3: get(:height) / 1.5,
  color: [[1, 0, 0, 1], [0, 1, 0, 1], [0, 0, 1, 1]]
)

show
