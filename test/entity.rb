# Entity

require 'ruby2d'

class Player < Ruby2D::Entity
  def update
    puts Time.now.to_f
  end

  def render
    Triangle.draw(x1: 320, y1: 50, x2: 540, y2: 430, x3: 100, y3: 430,
      color: [
        [1.0, 0.3, 0.3, 1.0],
        [0.0, 0.4, 0.8, 1.0],
        [0.2, 0.8, 0.3, 1.0]
      ]
    )
  end
end

player = Player.new


# Using DSL

player.add

show


# Using class pattern

=begin
class GameWindow < Ruby2D::Window
  def initialize
    super
  end

  def update
  end

  def render
  end
end

game_window = GameWindow.new

game_window.add(player)

game_window.show
=end
