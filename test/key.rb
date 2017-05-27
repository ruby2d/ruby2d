require 'ruby2d'

set title: "Ruby 2D — Key", width: 300, height: 200

s1 = Square.new(
  x: 5,
  y: 5,
  size: 50
)

s2 = Square.new(
  x: 60,
  y: 5,
  size: 50
)

on :key do |event|
  puts event
end

on :key_down do |event|
  s1.color = [1, 0, 0, 1]
end

on :key_held do |event|
  s2.color = [0, 1, 0, 1]
end

on :key_up do |event|
  s1.color = [1, 1, 1, 1]
  s2.color = [1, 1, 1, 1]
end


on :key_down do |event|
  close if event.key == 'escape'
end

show
