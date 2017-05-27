require 'ruby2d'

set title: "Hello z-index"
set width: 500, height: 500

class ZIndexGenerator
  def initialize
    @z_index = 0
  end

  def get
    @z_index += 1
    @z_index
  end
end

@z_index_generator = ZIndexGenerator.new

class Ruby2D::Square
  def contains?(x, y)
    x > @x and x < @x + @width and y > @y and y < @y + @height
  end
end

objects = []
objects << Square.new(
  x: 50,
  y: 50,
  size: 200,
  color: "red",
  z: @z_index_generator.get
)
objects << Square.new(
  x: 100,
  y: 50,
  size: 200,
  color: "blue",
  z: @z_index_generator.get
)

on :mouse_down do |event|
  x = event.x
  y = event.y
  case event.button
  when :left
    # Find square that you clicked, and set it's z-index to highest one in set
    objects.sort!{|a, b| -a.z <=> -b.z }
    first_object = objects.find do |object|
      object.contains?(x, y)
    end
    first_object.z = @z_index_generator.get if first_object
  when :right
    # Add new square with z-index of zero, with the middle at mouse position
    objects << Square.new(
      x: x - 100,
      y: y - 100,
      size: 200,
      color: "random",
      z: -objects.count
    )
  end
end

show
