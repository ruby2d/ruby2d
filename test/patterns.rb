
#############################
# Pattern 1 — DSL

require 'ruby2d'

update do
  puts Time.now.to_f
end

show

#############################
# Pattern 2 — Singleton

require 'ruby2d'

Window.update do
  puts Time.now.to_f
end

Window.show

#############################
# Pattern 3 — Instance

require 'ruby2d'

game_window = Window.new

game_window.update do
  puts Time.now.to_f
end

game_window.show

#############################
# Pattern 4 — Class

require 'ruby2d'

class GameWindow < Ruby2D::Window
  def initialize
    super
  end

  def update
    puts Time.now.to_f
  end
end

GameWindow.new.show
