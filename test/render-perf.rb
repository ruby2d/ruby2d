require 'ruby2d'

set width: 1280, height: 770

# # 9,600 objects, Runs at 11 fps (30 with VBO)
# 128.times do |i|
#   75.times do |j|
#     Square.new(x: i*10, y: j*10 + 20, size: 10, color: 'random')
#   end
# end

# # Runs at 27 fps and takes about 6 seconds to start up
# 10000.times do
#   Quad.new(x1: 50, y1: 50)
# end

fps = Text.new 'fps'

update do
  fps.text = Window.fps
end

render do

  # 9,600 objects, runs at 60 fps
  128.times do |i|
    75.times do |j|
      Quad.draw(i*10, j*10 + 20, rand)
    end
  end

  # # Runs at 60 fps, max objects before dip
  # 50000.times do
  #   Quad.draw(50, 50, 1)
  # end

end

show
