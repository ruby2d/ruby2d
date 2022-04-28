require 'ruby2d'

set width: 800
set height: 600

Square.new(size: 500, color: 'red')

# Canvas options:
#  x, y, z, width, height, rotate, fill, color, update
# If `update: false` is set, `canvas.update` must be manually called to update the rendered texture
canvas = Canvas.new(x: 50, y: 50,
                    width: Window.width - 100,
                    height: Window.height - 100,
                    fill: [1, 1, 1, 0.5],
                    update: false)

(1..10).each do |ix|
  canvas.fill_rectangle(
    x: 10 + ix * 30, y: 10 + ix * 30,
    width: 100, height: 100,
    color: Color.new([0, 1, 0, 0.5])
  )
  canvas.draw_rectangle(
    x: 10 + ix * 30, y: 10 + ix * 30,
    width: 100, height: 100,
    pen_width: 8,
    color: Color.new([0, 0, 1, 0.25])
  )
end

canvas.fill_circle(
  x: 175, y: 350, radius: 150,
  color: [0.9, 0.9, 0.9, 0.3]
)

canvas.fill_ellipse(
  x: 475, y: 50, xradius: 50, yradius: 35,
  color: [0.9, 0.7, 0.5, 0.6]
)

[1, 5, 9].each do |ix|
  canvas.draw_circle(
    x: 175, y: 350, radius: 150 - (ix * ix),
    pen_width: ix > 1 ? ix * 2 : 1, sectors: 50 - ix,
    color: [1, 1, 1, 0.5]
  )
end

[3, 7].each do |ix|
  canvas.draw_ellipse(
    x: 175, y: 350, xradius: 150 - (ix * ix), yradius: 100 - (ix * ix),
    pen_width: ix > 1 ? ix * 2 : 1, sectors: 50 - ix,
    color: [0.8, 1, 0.6, 0.5]
  )
end

(1..3).each do |ix|
  # thick line
  canvas.draw_line(
    x1: 10,
    y1: 75 + (ix * 15),
    x2: 310,
    y2: 420 + (ix * 15),
    pen_width: 30,
    color: Color.new([0.5 + (ix * 0.1), 0.5 + (ix * 0.1), 1, 0.5])
  )
  # thin line along the middle of the thick line
  canvas.draw_line(
    x1: 10,
    y1: 75 + (ix * 15),
    x2: 310,
    y2: 420 + (ix * 15),
    color: 'white'
  )
end

canvas.fill_triangle x1: 100, y1: 100, x2: 200, y2: 150, x3: 150, y3: 400,
                     color: [1, 1, 1, 0.5]
canvas.draw_triangle x1: 100 - 5, y1: 100 - 5, x2: 200 + 5, y2: 150 - 5, x3: 150, y3: 400 + 5,
                     color: [1, 1, 1, 0.75], pen_width: 10

canvas.fill_triangle x1: 250, y1: 100, x2: 350, y2: 150, x3: 300, y3: 400,
                     color: Color::Set.new([[1, 0, 0, 0.5],
                                            [0, 1, 0, 0.5],
                                            [0, 0, 1, 0.5]])

canvas.fill_rectangle(x: 400 - 5, y: 200 - 5, width: 10, height: 10, color: 'white')
canvas.fill_rectangle(x: 450 - 5, y: 150 - 5, width: 10, height: 10, color: 'white')
canvas.fill_rectangle(x: 500 - 5, y: 300 - 5, width: 10, height: 10, color: 'white')
canvas.fill_rectangle(x: 450 - 5, y: 190 - 5, width: 10, height: 10, color: 'white')

canvas.fill_quad x1: 400, y1: 200,
                 x2: 450, y2: 150,
                 x3: 500, y3: 300,
                 x4: 450, y4: 190,
                 color: [0, 0, 1, 0.5]

canvas.fill_circle x: 450, y: 250,
                   radius: 100,
                   color: [0, 0.7, 1, 0.3]

canvas.draw_quad x1: 500 - 5, y1: 200 - 5,
                 x2: 550 + 5, y2: 150 - 5,
                 x3: 600 + 5, y3: 300,
                 x4: 550, y4: 400 + 5,
                 color: [1, 1, 1, 0.75], pen_width: 5

canvas.fill_quad x1: 500, y1: 200,
                 x2: 550, y2: 150,
                 x3: 600, y3: 300,
                 x4: 550, y4: 400,
                 color: Color::Set.new([
                                         [1, 0, 0, 0.5],
                                         [0, 1, 0, 0.5],
                                         [0, 0, 1, 0.5],
                                         [0, 1, 1, 0.5]
                                       ])

polyline = [400, 100,
            500, 200,
            400, 300,
            500, 400,
            600, 100]

canvas.draw_polyline coordinates: polyline,
                     pen_width: 20,
                     color: [1, 1, 1, 0.5]

canvas.draw_polyline coordinates: polyline,
                     pen_width: 1,
                     color: [1, 1, 1, 1]

polygon = [500, 100,
           600, 200,
           500, 300,
           300, 300]

canvas.draw_polyline coordinates: polygon,
                     pen_width: 20, closed: true,
                     color: [0, 1, 1, 0.25]

update do
  canvas.update
end

on :key_down do |event|
  close if event.key == 'escape'
  canvas.update
end

show
