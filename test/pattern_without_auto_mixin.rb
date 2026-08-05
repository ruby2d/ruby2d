# Without auto-mixin invocation
#
# Demonstrates using Ruby 2D without the global DSL mixin — `require
# 'ruby2d/core'` instead of `'ruby2d'`, then explicitly `include Ruby2D` in a
# module to access short names like `Window`, `Square`, `Text`. Draws a
# scene-graph square and a render-block square, increments an on-screen
# counter from the update block, and logs key presses to stdout.

require 'ruby2d/core'

module App
  include Ruby2D

  Window.set title: 'Ruby 2D — Without Auto-Mixin Invocation'
  Window.set close_on_esc: true

  # Scene-graph object
  Square.new(x: 450, y: 300, size: 80, color: 'orange')

  # Update-driven counter
  update_count = 0
  update_label = Text.new('updates: 0', x: 10, y: 10, size: 12, color: 'white')

  Window.update do
    update_count += 1
    update_label.content = "updates: #{update_count}"
  end

  # Render-block object
  Window.render do
    Square.render(x: 150, y: 50, size: 80, color: 'red')
  end

  # Event handler
  Window.on :key_down do |e|
    puts "#{e.key} was pressed!"
  end

  Window.show
end
