require 'ruby2d'

set width: 800
set height: 600

Square.new(size: 500, color: 'red')

# Canvas options:
#  x, y, z, width, height, rotate, fill, color, update
# If `update: false` is set, `canvas.update` must be manually called to update the rendered texture
canvas = Canvas.new(x: 50, y: 50, width: Window.width - 100, height: Window.height - 100, fill: [1, 1, 1, 0.5])

clear_between_draw = false

update do
  canvas.clear if clear_between_draw

  canvas.draw_rectangle(
    x: Window.mouse_x - 50, y: Window.mouse_y - 50,
    width: 50, height: 50,
    color: [rand, rand, rand, 1]
  )

  canvas.fill_rectangle(
    x: Window.mouse_x - 50 + 5, y: Window.mouse_y - 50 + 5,
    width: 40, height: 40,
    color: [rand, rand, rand, 1]
  )

  canvas.draw_line(
    x1: 0, y1: 0, x2: Window.mouse_x - 50, y2: Window.mouse_y - 50, width: 1,
    color: [rand, rand, rand, 1]
  )
end

on :key_down do |event|
  case event.key
  when 'escape'
    close
  when 'space'
    clear_between_draw = !clear_between_draw
  end
  canvas.update
end

show
