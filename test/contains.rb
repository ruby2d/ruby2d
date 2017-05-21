require 'ruby2d'

set title: "Ruby 2D — Contains", height: 350

if RUBY_ENGINE == 'opal'
  media = "../test/media"
  font = "sans-serif"
else
  media = "media"
  font = "#{media}/bitstream_vera/vera.ttf"
end

objects = []
objects.push Square.new(50, 50, 100)
objects.push Rectangle.new(200, 50, 100, 75)
objects.push Quad.new(350, 50, 500, 75, 450, 150, 375, 125)
objects.push Triangle.new(550, 50, 600, 125, 500, 150)
objects.push Line.new(225, 175, 375, 225, 20)
objects.push Image.new(50, 200, "#{media}/colors.png")
objects.push Text.new(450, 200, "Hello", 50, font)

on :key_down do |event|
  close if event.key == 'escape'
end

update do
  objects.each do |o|
    o.contains?(get(:mouse_x), get(:mouse_y)) ? o.opacity = 1.0 : o.opacity = 0.5
  end
end

show
