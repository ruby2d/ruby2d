require 'ruby2d'

set width: 200, height: 100, title: "Ruby 2D – Input"

on key: 'a' do
  puts "on key: 'a'"
end

on key_up: 's' do
  puts "on key_up: 's'"
end

on key_down: 'd' do
  puts "on key_down: 'd'"
end

on key: 'any' do
  puts "on key: 'any'"
end

on key_down: 'any' do
 puts "on key_down: 'any'"
end

on key_up: 'any' do
  puts "on key_up: 'any'"
end

on_key do |key|
  puts "on_key: #{key}"
end

on_controller do |which, is_axis, axis, val, is_btn, btn|
  puts "=== Controller Pressed ===",
       "which: which",
       "is_axis: #{is_axis}",
       "axis: #{axis}",
       "val: #{val}",
       "is_btn: #{is_btn}",
       "btn: #{btn}"
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
