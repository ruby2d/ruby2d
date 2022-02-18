require 'ruby2d'

set diagnostics: true

set width: 700, height: 500, title: "Ruby 2D — Test Card"

font = "#{Ruby2D.test_media}/bitstream_vera/vera.ttf"

# Read window attributes
puts "=== Window Attributes ===
Title: #{get :title}
Background: #{get :background}
Width:  #{get :width}
Height: #{get :height}
Window: #{get :window}\n\n"

# Primary colors
Rectangle.new(x: 0,   width: 50, color: [1, 0, 0, 1])
Rectangle.new(x: 50,  width: 50, color: [0, 1, 0, 1])
Rectangle.new(x: 100, width: 50, color: [0, 0, 1, 1])

# Color strings
Square.new(x: 150, size: 50, color: 'teal')
Square.new(x: 200, size: 50, color: 'gray')
Square.new(x: 250, size: 50, color: 'silver')
Square.new(x: 300, size: 50, color: 'white')
Rectangle.new(x: 350, width: 50, height: 50, color: 'navy')
Rectangle.new(x: 400, width: 50, height: 50, color: 'blue')
Rectangle.new(x: 450, width: 50, height: 50, color: 'aqua')
Rectangle.new(x: 500, width: 50, height: 50, color: 'teal')
Rectangle.new(x: 550, width: 50, height: 50, color: 'olive')
Rectangle.new(x: 150, y: 50, width: 50, height: 50, color: 'green')
Rectangle.new(x: 200, y: 50, width: 50, height: 50, color: 'lime')
Rectangle.new(x: 250, y: 50, width: 50, height: 50, color: 'yellow')
Rectangle.new(x: 300, y: 50, width: 50, height: 50, color: 'orange')
Rectangle.new(x: 350, y: 50, width: 50, height: 50, color: 'red')
Rectangle.new(x: 400, y: 50, width: 50, height: 50, color: 'maroon')
Rectangle.new(x: 450, y: 50, width: 50, height: 50, color: 'fuchsia')
Rectangle.new(x: 500, y: 50, width: 50, height: 50, color: 'purple')
Rectangle.new(x: 550, y: 50, width: 50, height: 50, color: 'brown')

# Mix of named colors and numbers
Rectangle.new(
  x: 600,
  y: 0,
  width: 50,
  height: 50,
  color: [
    [1.0, 0, 0, 1],
    'green',
    [0.0, 0, 1, 1.0],
    'yellow'
  ]
)

# Check opacity
opacity_square = Square.new(
  x: 650,
  y: 0,
  size: 50,
  color: ['red', 'green', 'blue', 'yellow']
)

# Fill remaining area with random colors
Rectangle.new(x: 600, y: 50, width: 50, height: 50, color: 'random')
Square.new(x: 650, y: 50, size: 50, color: 'random')

# White to black gradient
Rectangle.new(
  x: 0,
  y: 100,
  width: 700,
  height: 25,
  color: [
    [1.0, 1.0, 1.0, 1.0],
    [0.0, 0.0, 0.0, 0.0],
    [0.0, 0.0, 0.0, 0.0],
    [1.0, 1.0, 1.0, 1.0]
  ]
)

# Color gradient
Rectangle.new(
  x: 0,
  y: 125,
  width: 700,
  height: 50,
  color: [
    [1.0, 0.0, 0.0, 1.0],
    [0.0, 1.0, 0.0, 1.0],
    [0.0, 0.0, 1.0, 1.0],
    [1.0, 1.0, 0.0, 1.0]
  ]
)

# Transparancy
Rectangle.new(
  x: 0,
  y: 165,
  width: 700,
  height: 35,
  color: [
    [1.0, 1.0, 1.0, 0.0],
    [1.0, 1.0, 1.0, 1.0],
    [1.0, 1.0, 1.0, 1.0],
    [1.0, 1.0, 1.0, 0.0]
  ]
)

# Triangles
Triangle.new(x1: 25,  y1: 200, x2: 50,  y2: 250, x3: 0,   y3: 250, color: [1.0,   0,   0, 1.0])
Triangle.new(x1: 75,  y1: 200, x2: 100, y2: 250, x3: 50,  y3: 250, color: [  0, 1.0,   0, 1.0])
Triangle.new(x1: 125, y1: 200, x2: 150, y2: 250, x3: 100, y3: 250, color: [  0,   0, 1.0, 1.0])
Triangle.new(x1: 175, y1: 200, x2: 200, y2: 250, x3: 150, y3: 250,
  color: [
    [1.0, 0, 0, 1.0],
    [0, 1.0, 0, 1.0],
    [0, 0, 1.0, 1.0]
  ]
)
Rectangle.new(
  x: 200,
  y: 200,
  width: 50,
  height: 50,
  color: [0.5, 0.5, 0.5, 1.0]
)  # add background for transparancy
Triangle.new(
  x1: 225,
  y1: 200,
  x2: 250,
  y2: 250,
  x3: 200,
  y3: 250,
  color: [
    [1.0, 1.0, 1.0, 1.0],
    [0.0, 0.0, 0.0, 1.0],
    [1.0, 1.0, 1.0, 0.0]
  ]
)

# Quadrilaterals
Quad.new(
  x1: 300, y1: 200,
  x2: 350, y2: 200,
  x3: 300, y3: 250,
  x4: 250, y4: 250,
  color: [
    [1.0, 0.0, 0.0, 1.0],
    [0.0, 1.0, 0.0, 1.0],
    [0.0, 0.0, 1.0, 1.0],
    [1.0, 1.0, 0.0, 1.0]
  ]
)

Quad.new(
  x1: 250, y1: 200,
  x2: 300, y2: 200,
  x3: 350, y3: 250,
  x4: 300, y4: 250,
  color: [
    [1.0, 1.0, 1.0, 0.0],
    [1.0, 1.0, 1.0, 0.0],
    [1.0, 1.0, 1.0, 1.0],
    [1.0, 1.0, 1.0, 0.0]
  ]
)

# Lines
Line.new(
  x1: 354, y1: 204,
  x2: 397, y2: 247,
  width: 11,
  color: [
    [1, 1, 1, 1],
    [1, 1, 1, 1],
    [1, 1, 1, 1],
    [1, 1, 1, 1]
  ]
);

Line.new(
  x1: 395, y1: 205,
  x2: 355, y2: 245,
  width: 15,
  color: [
    [1, 0, 0, 0.5],
    [0, 1, 0, 0.5],
    [0, 0, 1, 0.5],
    [1, 0, 1, 0.5]
  ]
);

# Circles

Circle.new(x: 525, y: 225, radius: 25, color: [1.0, 0.2, 0.2, 1.0])
Circle.new(x: 575, y: 225, radius: 25, sectors:  8, color: [0.2, 1.0, 0.2, 1.0])
Circle.new(x: 575, y: 225, radius: 17, sectors: 16, color: [0, 0, 0, 0.6])

rotate = false

# Images
img_png = Image.new("#{Ruby2D.test_media}/image.png", x: 600, y: 180)
img_jpg = Image.new("#{Ruby2D.test_media}/image.jpg", x: 600, y: 290)
img_bmp = Image.new("#{Ruby2D.test_media}/image.bmp", x: 600, y: 400)
img_r = Image.new("#{Ruby2D.test_media}/colors.png",  x: 400, y: 200, width: 50, height: 25)
img_r.color = [1.0, 0.3, 0.3, 1.0]
img_g = Image.new("#{Ruby2D.test_media}/colors.png", x: 400, y: 225)
img_g.width, img_g.height = 25, 25
img_g.color = [0.3, 1.0, 0.3, 1.0]
img_b = Image.new("#{Ruby2D.test_media}/colors.png", x: 425, y: 225)
img_b.width, img_b.height = 25, 25
img_b.color = [0.3, 0.3, 1.0, 1.0]

# Text
txt_r = Text.new("R", x:  44, y: 202, font: font, color: [1.0, 0.0, 0.0, 1.0])
txt_b = Text.new("G", x:  92, y: 202, font: font, color: [0.0, 1.0, 0.0, 1.0])
txt_g = Text.new("B", x: 144, y: 202, font: font, color: [0.0, 0.0, 1.0, 1.0])

# Frames per second
fps = Text.new("", x: 10, y: 470, font: font)

# Sprites
spr = Sprite.new(
  "#{Ruby2D.test_media}/sprite_sheet.png",
  x: 450, y: 200,
  clip_width: 50,
  time: 500,
  loop: true
)
spr.play

# Pointer for mouse
pointer = Square.new(size: 10)
pointer_outline = Square.new(size: 18, color: [0, 1, 0, 0])
flash = 0

time_start = Time.now

# Default font for text
Text.new("Default font", x: 150, y: 470, size: 20)

# Text size
created_text = Text.new("Created text", x: 10, y: 270, font: font)
created_text_background = Rectangle.new(
  x: created_text.x - 10,
  y: created_text.y - 10,
  width: created_text.width + 20,
  height: created_text.height + 20,
  color: 'red'
)
created_text.remove
created_text.add

updated_text = Text.new(
  "Updated text",
  x: 20 + created_text_background.x2,
  y: 270,
  font: font
)
updated_text_background = Rectangle.new(
  x: updated_text.x - 10,
  y: updated_text.y - 10,
  width: updated_text.width + 20,
  height: updated_text.height + 20,
  color: 'blue'
)
updated_text.remove
updated_text.add
UPDATED_TEXT_OPTIONS = "of various size".split(" ")

on :key_down do |event|
  close if event.key == 'escape'

  if event.key == 'r'
    rotate = rotate ? false : true;
  end

  if event.key == 's'
    puts "Taking screenshots..."
    get :screenshot
    get :screenshot, './screenshot-get.png'
    Window.screenshot
    Window.screenshot './screenshot-window.png'
  end
end

on :mouse_down do
  pointer_outline.x = (get :mouse_x) - 9
  pointer_outline.y = (get :mouse_y) - 11
  flash = 2
end

update do
  pointer.x = (get :mouse_x) - 5
  pointer.y = (get :mouse_y) - 7

  if rotate
    img_png.x = get :mouse_x
    img_png.y = get :mouse_y
    angle = (get :frames).to_f
    img_png.rotate = angle
    img_jpg.rotate = angle
    img_bmp.rotate = angle
    img_r.rotate = angle
    img_g.rotate = angle
    img_b.rotate = angle
    spr.rotate = angle
    txt_r.rotate = angle
    txt_g.rotate = angle
    txt_b.rotate = angle
    fps.rotate = angle
  end

  if flash > 0
    pointer_outline.color = [0, 1, 0, 1]
    flash -= 1
  else
    pointer_outline.color = [0, 1, 0, 0]
  end

  if (get :frames) % 20 == 0
    fps.text = "FPS: #{(get :fps).round(3)}"
  end

  elapsed_time = Time.now - time_start
  opacity = Math.sin(3 * elapsed_time.to_f).abs
  opacity_square.color.opacity = opacity

  if (get :frames) % 60 == 0
    updated_text.text = "Updated text " + UPDATED_TEXT_OPTIONS[Time.now.to_i % UPDATED_TEXT_OPTIONS.length]
    updated_text_background.width = updated_text.width + 20
  end
end

show
