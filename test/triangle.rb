require 'ruby2d'

# set title: "Hello Triangle"
#
# Triangle.new(
#   x1: 320, y1:  50,
#   x2: 540, y2: 430,
#   x3: 100, y3: 430,
#   color: ['red', 'green', 'blue']
# )

set width: 1280, height: 770

# # Runs at 6 fps
# 120.times do |i|
#   160.times do |j|
#     s = Square.new(x: j*10, y: i*10, size: 10, color: 'random')
#   end
# end

# Runs at 11 fps
# 128.times do |i|
#   77.times do |j|
#     s = Square.new(x: i*10, y: j*10, size: 10, color: 'random')
#   end
# end

fps = Text.new 'fps'

update do
  fps.text = Window.fps
end

render do
#   # 120.times do |i|
#   #   160.times do |j|
#   #     Quad.draw(j*10, i*10)
#   #   end
#   # end
#
#   # 19200.times do
#   #   Quad.draw(0, 0)
#   # end
#
#   120.times do |i|
#     20.times do |j|
#       Quad.draw(j*10, i*10 + 20, rand)
#     end
#   end
#

  128.times do |i|
    77.times do |j|
      Quad.draw(i*10, j*10 + 20, rand)
    end
  end

end

show
