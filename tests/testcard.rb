require 'ruby2d'

set width: 700, height: 500, title: "Ruby 2D – Testcard"

# Read window attributes
puts "
=== Window Attributes ===
Title:  #{get :title}
Width:  #{get :width}
Height: #{get :height}
FPS:    #{get :fps}
Self:   #{get :window}\n\n"

# Primary colors
Rectangle.new(0, 0, 50, 100,   [1.0, 0, 0, 1.0])
Rectangle.new(50, 0, 50, 100,  [0, 1.0, 0, 1.0])
Rectangle.new(100, 0, 50, 100, [0, 0, 1.0, 1.0])

# Color strings
Rectangle.new(150, 0, 50, 50,  'black')
Rectangle.new(200, 0, 50, 50,  'gray')
Rectangle.new(250, 0, 50, 50,  'silver')
Rectangle.new(300, 0, 50, 50,  'white')
Rectangle.new(350, 0, 50, 50,  'navy')
Rectangle.new(400, 0, 50, 50,  'blue')
Rectangle.new(450, 0, 50, 50,  'aqua')
Rectangle.new(500, 0, 50, 50,  'teal')
Rectangle.new(550, 0, 50, 50,  'olive')

Rectangle.new(150, 50, 50, 50, 'green')
Rectangle.new(200, 50, 50, 50, 'lime')
Rectangle.new(250, 50, 50, 50, 'yellow')
Rectangle.new(300, 50, 50, 50, 'orange')
Rectangle.new(350, 50, 50, 50, 'red')
Rectangle.new(400, 50, 50, 50, 'maroon')
Rectangle.new(450, 50, 50, 50, 'fuchsia')
Rectangle.new(500, 50, 50, 50, 'purple')
Rectangle.new(550, 50, 50, 50, 'brown')

# Mix of named colors and numbers
Rectangle.new(600, 0, 50, 50,
[
  'red',
  'green',
  'blue',
  'yellow'
])
Rectangle.new(650, 0, 50, 50,
[
  [1.0, 0, 0, 255],
  'green',
  [0.0, 0, 255, 1.0],
  'yellow'
])
Rectangle.new(600, 50, 50, 50, 'random')
Rectangle.new(650, 50, 50, 50, 'random')


# White to black gradient
Rectangle.new(0, 100, 700, 25,
[
  [1.0, 1.0, 1.0, 1.0],
  [0.0, 0.0, 0.0, 0.0],  # testing Float
  [  0,   0,   0,   0],  # testing Fixnum
  [1.0, 1.0, 1.0, 1.0]
])

# Color gradient
Rectangle.new(0, 125, 700, 50,
[
  [1.0, 0.0, 0.0, 1.0],
  [0.0, 1.0, 0.0, 1.0],
  [0.0, 0.0, 1.0, 1.0],
  [1.0, 1.0, 0.0, 1.0]
])

# Transparancy
Rectangle.new(0, 165, 700, 35,
[
  [1.0, 1.0, 1.0, 0.0],
  [1.0, 1.0, 1.0, 1.0],
  [1.0, 1.0, 1.0, 1.0],
  [1.0, 1.0, 1.0, 0.0]
])

# Triangles
Triangle.new(25, 200, 50, 250, 0, 250,     [1.0, 0, 0, 1.0])
Triangle.new(75, 200, 100, 250, 50, 250,   [0, 1.0, 1, 1.0])
Triangle.new(125, 200, 150, 250, 100, 250, [0, 0, 1.0, 1.0])
Triangle.new(175, 200, 200, 250, 150, 250,
[
  [1.0, 0, 0, 1.0],
  [0, 1.0, 0, 1.0],
  [0, 0, 1.0, 1.0]
])
Rectangle.new(200, 200, 50, 50, 'gray')  # add background for transparancy
Triangle.new(225, 200, 250, 250, 200, 250,
[
  [1.0, 1.0, 1.0, 1.0],
  [0.0, 0.0, 0.0, 1.0],
  [1.0, 1.0, 1.0, 0.0]
])

# Quadrilaterals
Quad.new(
  300, 200,
  350, 200,
  300, 250,
  250, 250,
  [
    [1.0, 0.0, 0.0, 1.0],
    [0.0, 1.0, 0.0, 1.0],
    [0.0, 0.0, 1.0, 1.0],
    [1.0, 1.0, 0.0, 1.0]
  ]
)

Quad.new(
  250, 200,
  300, 200,
  350, 250,
  300, 250,
  [
    [1.0, 1.0, 1.0, 0.0],
    [1.0, 1.0, 1.0, 0.0],
    [1.0, 1.0, 1.0, 1.0],
    [1.0, 1.0, 1.0, 0.0]
  ]
)

# Images
Image.new(580, 180, "media/image.png")
Image.new(580, 290, "media/image.jpg")
Image.new(580, 400, "media/image.bmp")

# Text
Text.new(0, 250)  # Default message
t = Text.new(0, 275, 30, "Hello Ruby 2D!")  # Custom message
t.color = 'red'
fps = Text.new(0, 325, 20)

# Pointer for mouse
pointer = Square.new(0, 0, 10, 'white')

update do
  pointer.x = (get :mouse_x) - 5
  pointer.y = (get :mouse_y) - 7
  
  fps.text = "FPS: #{get :fps}"
end

show
