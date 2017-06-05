require 'ruby2d'

set title: "Ruby 2D — Controller", width: 300, height: 200

on :controller do |event|
  puts event
end

on :controller_axis do |event|
  puts "Axis: #{event.axis}, Value: #{event.value}"
end

on :controller_button_down do |event|
  puts "Button down: #{event.button}"
end

on :controller_button_up do |event|
  puts "Button up: #{event.button}"
end

show
