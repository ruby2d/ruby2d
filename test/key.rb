require 'ruby2d'

set title: "Ruby 2D — Key", width: 300, height: 200

s1 = Square.new(5, 5, 50, [1, 1, 1, 1])
s2 = Square.new(60, 5, 50, [1, 1, 1, 1])

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
