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
end

canvas.fill_circle(
  x: 300, y: 300, radius: 200,
  color: [0.9, 0.9, 0.9, 0.3]
)

(1..3).each do |ix|
  # thick line
  canvas.draw_line(
    x1: 10,
    y1: 75 + (ix * 15),
    x2: 310,
    y2: 420 + (ix * 15),
    width: 30,
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

update do
  canvas.update
end

on :key_down do |event|
  close if event.key == 'escape'
  canvas.update
end

show
