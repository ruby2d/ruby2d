require 'ruby2d'

set title: "Ruby 2D — Contains", height: 350

font = "#{Ruby2D.test_media}/bitstream_vera/vera.ttf"

objects = []
objects.push Square.new(x: 50, y: 50, size: 100)
objects.push Rectangle.new(x: 200, y: 50, width: 100, height: 75)
objects.push Quad.new(x1: 350, y1: 50, x2: 500, y2: 75, x3: 450, y3: 150, x4: 375, y4: 125)
objects.push Triangle.new(x1: 550, y1: 50, x2: 600, y2: 125, x3: 500, y3: 150)
objects.push Line.new(x1: 225, y1: 175, x2: 375, y2: 225, width: 20)
objects.push Circle.new(x: 225, y: 275, radius: 50)
objects.push Image.new("#{Ruby2D.test_media}/colors.png", x: 50, y: 200)
objects.push Text.new('Hello', x: 450, y: 200, size: 50, font: font)

on :key_down do |event|
  close if event.key == 'escape'
end

update do
  objects.each do |o|
    o.contains?(get(:mouse_x), get(:mouse_y)) ? o.opacity = 1.0 : o.opacity = 0.5
  end
end

show
