# Class pattern

require 'ruby2d'

class GameWindow < Ruby2D::Window
  def initialize
    super

    on :key_down do |e|
      puts "#{e.key} was pressed!"
    end
  end

  def update
    if key_down 'k'
      puts 'k pressed'
    end

    if key_held 'k'
      puts 'k is held'
    end

    if key_up 'k'
      puts 'k is up'
    end

    if mouse_down :left
      puts "Left mouse button down at #{@mouse_x}, #{@mouse_y}"
    end

    if mouse_down :right
      puts "Right mouse button down at #{@mouse_x}, #{@mouse_y}"
    end

    if mouse_up :left
      puts "Left mouse button up"
    end

    if mouse_scroll
      puts "Mouse scroll: #{@mouse_scroll_direction}, #{@mouse_scroll_delta_x}, #{@mouse_scroll_delta_y}"
    end

    if mouse_move
      puts "Mouse move: #{@mouse_x}, #{@mouse_y}, #{@mouse_move_delta_x}, #{@mouse_move_delta_y}"
    end

    if controller_axis :left_x
      puts "Controller left X axis: #{@controller_axis_left_x}"
    end

    if controller_axis :right_y
      puts "controller right Y axis: #{@controller_axis_right_y}"
    end

    if controller_button_down :a
      puts "Controller button A down..."
    end

    if controller_button_down :x
      puts "Controller button X down..."
    end

    if controller_button_up :a
      puts "Controller button A up..."
    end

    if controller_button_up :x
      puts "Controller button X up..."
    end
  end

  def render

    Quad.draw(
      x1: 125, y1: 0,
      x2: 225, y2: 0,
      x3: 250, y3: 100,
      x4: 150, y4: 100,
      color: [
        [0.8, 0.3, 0.7, 0.8],
        [0.1, 0.9, 0.1, 1.0],
        [0.8, 0.5, 0.8, 1.0],
        [0.6, 0.4, 0.1, 1.0]
      ]
    )

  end
end

GameWindow.new.show
