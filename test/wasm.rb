require 'ruby2d'

set diagnostics: true

puts 'Hello Ruby 2D!'

set title: 'Hello WebAssembly'

Square.new(size: 500, color: 'red')

canvas = Canvas.new(x: 50, y: 50, width: Window.width - 100, height: Window.height - 100, fill: [1, 1, 1, 0.5])
Canvas.new(x: 25, y: 400, width: 100, height: 100, color: 'blue', fill: [1, 1, 1, 1])

t = Triangle.new(
  x1: 320, y1:  50,
  x2: 540, y2: 430,
  x3: 100, y3: 430,
  color: ['red', 'green', 'blue']
)

Image.new("#{Ruby2D.test_media}/image.png")

font = "#{Ruby2D.test_media}/bitstream_vera/vera.ttf"
Text.new("Hello WASM", x: 100, size: 20, font: font)
Text.new("Default", x: 250, size: 20)

snd = Sound.new("#{Ruby2D.test_media}/sound.wav")
mus = Music.new("#{Ruby2D.test_media}/music.wav")

update do
  t.x1 = get :mouse_x
  t.y1 = get :mouse_y

  canvas.draw_rectangle(
    x: Window.mouse_x - 50, y: Window.mouse_y - 50,
    width: 50, height: 50,
    color: [rand, rand, rand, 1]
  )
end

on :key_down do |e|
  close if e.key == 'escape'
  case e.key
  when 's'
    snd.play
  when 'm'
    mus.play
  end
end

show
