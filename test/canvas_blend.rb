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

#
# Currently fat lines don't blend so we don't get the
# same effect ... yet.
(1..3).each do |ix|
  canvas.draw_line(
    x1: 10,
    y1: 75 + (ix * 15),
    x2: 310,
    y2: 420 + (ix * 15),
    width: 30,
    color: Color.new([0.5 + (ix * 0.1), 0.5 + (ix * 0.1), 1, 0.5])
  )
end

update do
  canvas.update
end

on :key_down do |event|
  close if event.key == 'escape'
  canvas.update
end

show
