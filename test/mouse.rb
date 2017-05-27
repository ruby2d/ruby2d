require 'ruby2d'

set title: "Ruby 2D — Mouse", width: 400, height: 300

on :mouse do |event|
  puts event
end

s1 = Square.new(x: 5,   y: 5,   size: 25, color: [1, 1, 0, 1]) # mouse down square
s2 = Square.new(x: 188, y: 10,  size: 25)                      # mouse scroll square
s3 = Square.new(x: 188, y: 137, size: 25)                      # mouse move delta square
s4 = Square.new(x: 35,  y: 5,   size: 10)                      # mouse move position square

on :mouse_down do |event|
  case event.button
  when :left
    s1.color = [1, 0, 0, 1]
  when :middle
    s1.color = [0, 0, 1, 1]
  when :right
    s1.color = [0, 1, 0, 1]
  end
  s1.x = event.x
  s1.y = event.y
end

on :mouse_up do |event|
  s1.color = [1, 1, 0, 1]
  s1.x = event.x
  s1.y = event.y
end

on :mouse_scroll do |event|
  s2.x = s2.x + event.delta_x
  s2.y = s2.y + event.delta_y
end

on :mouse_move do |event|
  s3.x = 188 + event.delta_x
  s3.y = 137 + event.delta_y
  s4.x = event.x - 5
  s4.y = event.y - 5
end

# Crosshairs
Rectangle.new(x: 199, y: 0,   width: 2,   height: 300, color: [1, 0, 0, 1])
Rectangle.new(x: 0,   y: 149, width: 400, height: 2,   color: [1, 0, 0, 1])

on :key_down do |event|
  close if event.key == 'escape'
end

show
