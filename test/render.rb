require 'ruby2d'


set icon: "#{Ruby2D.test_media}/colors.png"


Quad.new(x3: 125, x4: 25)
Rectangle.new(y: 125)
Square.new(y: 250)
Line.new(x1: 5, y1: 375, x2: 95, y2: 475, width: 5)
Triangle.new(x1: 325, y1: 0, x2: 375, y2: 100, x3: 275, y3: 100)
Circle.new(x: 400, y: 175)
img = Image.new("#{Ruby2D.test_media}/image.png", x: 250, y: 250)
txt = Text.new('Hello', x: 250, y: 375)
spr = Sprite.new(
  "#{Ruby2D.test_media}/coin.png",
  x: 500,
  y: 250,
  width: 84,
  clip_width: 84,
  time: 300,
  loop: true
).play

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

  Rectangle.draw(
    x: 225, y: 125, width: 100, height: 100,
    color: [
      [0.8, 0.3, 0.7, 0.8],
      [0.1, 0.9, 0.1, 1.0],
      [0.8, 0.5, 0.8, 1.0],
      [0.6, 0.4, 0.1, 1.0]
    ]
  )

  Square.draw(
    x: 125, y: 250, size: 100,
    color: [
      [0.8, 0.3, 0.7, 0.8],
      [0.1, 0.9, 0.1, 1.0],
      [0.8, 0.5, 0.8, 1.0],
      [0.6, 0.4, 0.1, 1.0]
    ]
  )

  Line.draw(
    x1: 130, y1: 375, x2: 220, y2: 475, width: 5,
    color: [
      [0.8, 0.3, 0.7, 0.8],
      [0.1, 0.9, 0.1, 1.0],
      [0.8, 0.5, 0.8, 1.0],
      [0.6, 0.4, 0.1, 1.0]
    ]
  )

  Triangle.draw(
    x1: 450, y1: 0, x2: 500, y2: 100, x3: 400, y3: 100,
    color: [
      [0.8, 0.3, 0.7, 0.8],
      [0.1, 0.9, 0.1, 1.0],
      [0.8, 0.5, 0.8, 1.0]
    ]
  )

  Pixel.draw(x: 550, y: 50, size: 10, color: [1.0, 0.0, 0.0, 1.0])

  Circle.draw(
    x: 525, y: 175, radius: 50, sectors: 30,
    color: [0.8, 0.3, 0.7, 0.8]
  )

  img.draw(x: 375, y: 250, width: 90, height: 110, rotate: 10, color: [0.8, 0.5, 0.4, 0.7])

  txt.draw(x: 375, y: 375, rotate: 10, color: [0.8, 0.5, 0.4, 0.7])

  spr.draw(x: 500, y: 350, width: 50, height: 90, rotate: 10, clip_x: 0, clip_y: 0, clip_width: 84, clip_height: 90, color: [0.8, 0.5, 0.4, 0.7])

end

show
