require 'ruby2d'

set width: 1000, height: 500

fps = Text.new 'fps'

update do
  fps.text = Window.fps
end

render do

  # 31,250 squares drawn at ~38 fps
  250.times do |i|
    125.times do |j|
      Pixel.draw(x: i*4, y: j*4 + 26, size: 4, color: [rand, rand, rand, 1.0])
    end
  end

end

show
