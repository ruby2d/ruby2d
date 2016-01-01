require 'ruby2d'

set width: 200, height: 100, title: "Ruby 2D – Input"

on key: 'a' do
  puts "a key"
end

on key_down: 's' do
  puts "s key down"
end

on mouse: 'left' do
  puts "mouse left"
end

on mouse: 'right' do
  puts "mouse right"
end

on mouse: 'down' do
  puts "mouse down"
end

on mouse: 'up' do
  puts "mouse up"
end

on mouse: 'any' do
  puts "mouse any"
end

show
