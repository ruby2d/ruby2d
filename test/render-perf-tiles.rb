require 'ruby2d'

set width: 1000, height: 675

fps = Text.new 'fps'

update do
  fps.text = Window.fps
end

tileset = Tileset.new('media/colors.png', tile_width: 8, tile_height: 8)


100.times do |i|
  100.times do |j|
    tileset.define_tile("#{i}-#{j}", i, j)
  end
end


render do

  tileset.clear_tiles

  # 10,000 squares drawn at ~28 fps
  # Apple M1 8 core CPU / 8 core GPU
  125.times do |i|
    79.times do |j|
      tileset.set_tile("#{rand(100)}-#{rand(100)}", [{x: i*8, y: j*8 + 26}])
    end
  end

end

show
