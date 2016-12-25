require 'ruby2d'

set width: 200, height: 100, title: "Ruby 2D – Input"

on key_down: 'a' do
  puts "Key 'a' pressed"
end

on key: 'a' do
  puts "Key 'a' held down"
end

on key_up: 'a' do
  puts "Key 'a' released"
end

on key_down: 'any' do
  puts "A key was pressed"
end

on_key do |key|
  puts "on_key: #{key}"
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

on key: 'escape' do
  close
end

show
