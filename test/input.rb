require 'ruby2d'

set width: 200, height: 100, title: "Ruby 2D — Input"

on key_down: 'a' do
  puts "Key 'a' down"
end

on key: 'b' do
  puts "Key 'b' held down"
end

on key_up: 'c' do
  puts "Key 'c' up"
end

on key_down: 'any' do
  puts "A key was pressed"
end

on_key do |key|
  if key == 'd'
    puts "on_key: #{key}"
  end
end

on mouse: 'any' do |x, y|
  puts "Mouse clicked at: #{x}, #{y}"
end

on key: 'escape' do
  close
end

show
