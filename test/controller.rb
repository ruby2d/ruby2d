require 'ruby2d'

set width: 300, height: 200, title: "Ruby 2D — Controller"

on_controller do |which, is_axis, axis, val, is_btn, btn, pressed|
  puts "=== Controller Pressed ===",
       "which: which",
       "is_axis: #{is_axis}",
       "axis: #{axis}",
       "val: #{val}",
       "is_btn: #{is_btn}",
       "btn: #{btn}",
       "pressed: #{pressed}", ""
end

show
