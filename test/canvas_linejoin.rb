require 'ruby2d'

set width: 800
set height: 600

Square.new(size: 500, color: 'red')

# Canvas options:
#  x, y, z, width, height, rotate, fill, color, update
# If `update: false` is set, `canvas.update` must be manually called to update the rendered texture
canvas = Canvas.new(x: 50, y: 50, width: Window.width - 100, height: Window.height - 100, fill: [1, 1, 1, 0.5])

points = [
  { x: 300, y: 300 },
  { x: 550, y: 200 },
  { x: 500, y: 450 }
]
control_index = 2

update do
  canvas.clear

  points[control_index][:x] = Window.mouse_x - 50
  points[control_index][:y] = Window.mouse_y - 50

  canvas.draw_polyline3 x1: points[0][:x], y1: points[0][:y],
                        x2: points[1][:x], y2: points[1][:y],
                        x3: points[2][:x], y3: points[2][:y],
                        pen_width: 20,
                        color: [1, 1, 1, 0.5]

  canvas.draw_polyline3 x1: points[0][:x], y1: points[0][:y],
                        x2: points[1][:x], y2: points[1][:y],
                        x3: points[2][:x], y3: points[2][:y],
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
  when '0', '1', '2'
    control_index = event.key.to_i
  end
end

puts '
Press Esc to exit.
Press 0 to select the first point to manipulate
Press 1 to select second (middle) point
Press 2 to select third (last) point <-- default
'

show
