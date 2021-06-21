require 'ruby2d'

set width: 1000, height: 675

fps = Text.new 'fps'

update do
  fps.text = Window.fps
end

render do

  # 39,500 squares drawn at ~30 fps
  # MacBook Pro, 6-Core Intel Core i9 2.9 GHz, Radeon Pro Vega 20
  250.times do |i|
    158.times do |j|
      Pixel.draw(x: i*4, y: j*4 + 26, size: 4, color: [rand, rand, rand, 1.0])
    end
  end

end

show
