require 'ruby2d'

set width: 800
set height: 600

Square.new(size: 500, color: 'red')

# Canvas options:
#  x, y, z, width, height, rotate, fill, color, update
# If `update: false` is set, `canvas.update` must be manually called to update the rendered texture
canvas = Canvas.new(x: 50, y: 50, width: Window.width - 100, height: Window.height - 100, fill: [1, 1, 1, 0.5])

points = [
  { x: 200, y: 200 },
  { x: 350, y: 100 },
  { x: 400, y: 250 },
  { x: 350, y: 350 },
  { x: 300, y: 400 }
]
control_index = 2

update do
  canvas.clear

  points[control_index][:x] = Window.mouse_x - 50
  points[control_index][:y] = Window.mouse_y - 50

  polyline = [points[0][:x], points[0][:y],
              points[1][:x], points[1][:y],
              points[2][:x], points[2][:y],
              points[3][:x], points[3][:y],
              points[4][:x], points[4][:y]]

  canvas.draw_polyline coordinates: polyline,
                       pen_width: 20,
                       color: [1, 1, 1, 0.5]

  canvas.draw_polyline coordinates: polyline,
                       pen_width: 1,
                       color: [1, 1, 1, 1]
end

#
# Press space to enable/disable clearing between frame while moving the mouse
# Press s to switch between square and circle
#
on :key_down do |event|
  case event.key
  when 'escape'
    close
  when '1', '2', '3', '4', '5'
    control_index = event.key.to_i - 1
  end
end

puts '
Press Esc to exit.
Press 1, 2, ... to select the first, second ... points to manipulate with the mouse
'

show
