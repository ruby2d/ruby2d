require 'ruby2d'

set width: 800
set height: 600

Square.new(size: 500, color: 'red')

# Canvas options:
#  x, y, z, width, height, rotate, fill, color, update
# If `update: false` is set, `canvas.update` must be manually called to update the rendered texture
canvas = Canvas.new(x: 50, y: 50, width: Window.width - 100, height: Window.height - 100, fill: [1, 1, 1, 0.5])

update do
  canvas.draw_rectangle(
    Window.mouse_x - 50, Window.mouse_y - 50,
    50, 50,
    rand(0.0..1.0), rand(0.0..1.0), rand(0.0..1.0), 1
  )

  canvas.draw_line(
    0, 0, Window.mouse_x - 50, Window.mouse_y - 50, 1,
    rand(0.0..1.0), rand(0.0..1.0), rand(0.0..1.0), 1
  )
end

on :key_down do |event|
  close if event.key == 'escape'
  canvas.update
end

show
