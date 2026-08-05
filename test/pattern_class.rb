# Class pattern
#
# Demonstrates using Ruby 2D by subclassing `Ruby2D::Window`. Update, render,
# and event handlers are defined as instance methods (or registered in
# `initialize`). Draws a scene-graph square and a render-method square,
# increments an on-screen counter from `#update`, and logs key presses to
# stdout.

require 'ruby2d'

class App < Ruby2D::Window
  def initialize
    super

    set title: 'Ruby 2D — Class Pattern'
    set close_on_esc: true

    # Scene-graph object
    Square.new(x: 450, y: 300, size: 80, color: 'orange')

    # Update-driven counter (state held on the instance)
    @update_count = 0
    @update_label = Text.new('updates: 0', x: 10, y: 10, size: 12, color: 'white')

    # Event handler
    on :key_down do |e|
      puts "#{e.key} was pressed!"
    end
  end

  def update
    @update_count += 1
    @update_label.content = "updates: #{@update_count}"
  end

  def render
    # Render-method object
    Square.render(x: 150, y: 50, size: 80, color: 'red')
  end
end

App.new.show
