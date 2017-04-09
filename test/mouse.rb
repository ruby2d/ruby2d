require 'ruby2d'

set title: "Ruby 2D — Mouse", width: 400, height: 300

on :mouse do |event|
  puts event
end

s1 = Square.new(5, 5, 25, [1, 1, 0, 1])      # mouse down square
s2 = Square.new(188, 10, 25)                 # mouse scroll square
s3 = Square.new(188, 137, 25, [1, 1, 1, 1])  # mouse move delta square
s4 = Square.new(35, 5, 10)                   # mouse move position square

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
Rectangle.new(199, 0, 2, 300, [1, 0, 0, 1])
Rectangle.new(0, 149, 400, 2, [1, 0, 0, 1])

on :key_down do |event|
  close if event.key == 'escape'
end

show
