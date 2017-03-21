require 'ruby2d'

if RUBY_ENGINE == 'opal'
  media = "../test/media"
  font = "sans-serif"
else
  media = "media"
  font = "#{media}/bitstream_vera/vera.ttf"
end

set diagnostics: true

set width: 700, height: 500, title: "Ruby 2D — Test Card"

# Read window attributes
puts "=== Window Attributes ===
Title: #{get :title}
Background: #{get :background}
Width:  #{get :width}
Height: #{get :height}
Window: #{get :window}\n\n"

# Primary colors
Rectangle.new(0, 0, 50, 100,   [1, 0, 0, 1])
Rectangle.new(50, 0, 50, 100,  [0, 1, 0, 1])
Rectangle.new(100, 0, 50, 100, [0, 0, 1, 1])

# Color strings
Square.new(   150, 0, 50,      'teal')
Square.new(   200, 0, 50,      'gray')
Square.new(   250, 0, 50,      'silver')
Square.new(   300, 0, 50,      'white')
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
  [1.0, 0, 0, 1],
  'green',
  [0.0, 0, 1, 1.0],
  'yellow'
])
Rectangle.new(600, 50, 50, 50, 'random')
Rectangle.new(650, 50, 50, 50, 'random')

# White to black gradient
Rectangle.new(0, 100, 700, 25,
[
  [1.0, 1.0, 1.0, 1.0],
  [0.0, 0.0, 0.0, 0.0],
  [0.0, 0.0, 0.0, 0.0],
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
Triangle.new(25, 200, 50, 250, 0, 250,     [1.0,   0,   0, 1.0])
Triangle.new(75, 200, 100, 250, 50, 250,   [  0, 1.0,   0, 1.0])
Triangle.new(125, 200, 150, 250, 100, 250, [  0,   0, 1.0, 1.0])
Triangle.new(175, 200, 200, 250, 150, 250,
[
  [1.0, 0, 0, 1.0],
  [0, 1.0, 0, 1.0],
  [0, 0, 1.0, 1.0]
])
Rectangle.new(200, 200, 50, 50, [0.5, 0.5, 0.5, 1.0])  # add background for transparancy
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
Image.new(590, 180, "#{media}/image.png")
Image.new(590, 290, "#{media}/image.jpg")
Image.new(590, 400, "#{media}/image.bmp")
img_r = Image.new(350, 200, "#{media}/colors.png")
img_r.width, img_r.height = 50, 50
img_r.color = [1.0, 0.3, 0.3, 1.0]
img_g = Image.new(400, 200, "#{media}/colors.png")
img_g.width, img_g.height = 50, 50
img_g.color = [0.3, 1.0, 0.3, 1.0]
img_b = Image.new(450, 200, "#{media}/colors.png")
img_b.width, img_b.height = 50, 50
img_b.color = [0.3, 0.3, 1.0, 1.0]

# Text
txt_r = Text.new( 44, 202, "R", 20, font)
txt_r.color = [1.0, 0.0, 0.0, 1.0]
txt_g = Text.new( 92, 202, "G", 20, font)
txt_g.color = [0.0, 1.0, 0.0, 1.0]
txt_b = Text.new(144, 202, "B", 20, font)
txt_b.color = [0.0, 0.0, 1.0, 1.0]

# Frames per second
fps = Text.new(10, 470, "", 20, font)

# Sprites
s1 = Sprite.new(500, 200, "#{media}/sprite_sheet.png")
s1.add(forwards: [
  [  0, 0, 50, 50, 30],
  [ 50, 0, 50, 50, 40],
  [100, 0, 50, 50, 50],
  [150, 0, 50, 50, 60]
])

# Pointer for mouse
pointer = Square.new(0, 0, 10, [1, 1, 1, 1])
pointer_outline = Square.new(0, 0, 18, [0, 1, 0, 0])
flash = 0

# Updating opacity
opacity_square = Square.new(500, 255, 50, ["red", "green", "blue", "yellow"])
time_start     = Time.now

on key: 'escape' do
  close
end

on mouse: 'any' do |x, y|
  puts "Mouse down at: #{x}, #{y}"
  pointer_outline.x = (get :mouse_x) - 9
  pointer_outline.y = (get :mouse_y) - 11
  flash = 2
end

update do
  pointer.x = (get :mouse_x) - 5
  pointer.y = (get :mouse_y) - 7
  
  if flash > 0
    pointer_outline.color = [0, 1, 0, 1]
    flash -= 1
  else
    pointer_outline.color = [0, 1, 0, 0]
  end
  
  s1.animate(:forwards)
  
  if (get :frames) % 20 == 0
    fps.text = "FPS: #{(get :fps).round(3)}"
  end

  elapsed_time = Time.now - time_start
  opacity = Math.sin(3 * elapsed_time.to_f).abs
  opacity_square.color.opacity = opacity
end

show
