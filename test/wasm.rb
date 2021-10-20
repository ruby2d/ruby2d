require 'ruby2d'

set diagnostics: true

puts "Hello Ruby 2D!"

set title: "Hello Triangle"

t = Triangle.new(
  x1: 320, y1:  50,
  x2: 540, y2: 430,
  x3: 100, y3: 430,
  color: ['red', 'green', 'blue']
)

update do
  t.x1 = get :mouse_x
  t.y1 = get :mouse_y
end

show
