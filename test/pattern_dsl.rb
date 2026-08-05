# DSL pattern
#
# Demonstrates using Ruby 2D via the top-level DSL — `set`, `update`, `render`,
# `on`, and `show` are mixed into `main` by `require 'ruby2d'`. Draws a
# scene-graph square and a render-block quad, increments an on-screen counter
# from the update block, and logs key presses to stdout.

require 'ruby2d'

set title: 'Ruby 2D — DSL Pattern'
set close_on_esc: true

# Scene-graph object
Square.new(x: 450, y: 300, size: 80, color: 'orange')

# Update-driven counter
update_count = 0
update_label = Text.new('updates: 0', x: 10, y: 10, size: 12, color: 'white')

update do
  update_count += 1
  update_label.content = "updates: #{update_count}"
end

# Render-block object
render do
  Square.render(x: 150, y: 50, size: 80, color: 'red')
end

# Event handler
on :key_down do |e|
  puts "#{e.key} was pressed!"
end

show
