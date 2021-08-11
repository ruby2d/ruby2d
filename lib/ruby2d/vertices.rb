# Ruby2D::Vertices

# This class generates a vertices array which are passed to the openGL rendering code.
# The vertices array is split up into 4 groups (1 - top left, 2 - top right, 3 - bottom right, 4 - bottom left)
# This class is responsible for transforming textures, it can scale / crop / rotate and flip textures

module Ruby2D
  class Vertices
    def initialize(x, y, width, height, rotate, crop: nil, flip: nil)
      @flip = flip
      @x = x
      @y = y
      @width = width.to_f
      @height = height.to_f

      if @flip == :horizontal || @flip == :both
        @x = @x + @width
        @width = -@width
      end

      if @flip == :vertical || @flip == :both
        @y = y + @height
        @height = -@height
      end

      @rotate = rotate
      @rx = @x + (@width / 2.0)
      @ry = @y + (@height / 2.0)
      @crop = crop
    end

    def coordinates
      x1, y1 = rotate(@x,          @y);           # Top left
      x2, y2 = rotate(@x + @width, @y);           # Top right
      x3, y3 = rotate(@x + @width, @y + @height); # Bottom right
      x4, y4 = rotate(@x,          @y + @height); # Bottom left

      [ x1, y1, x2, y2, x3, y3, x4, y4 ]
    end

    def texture_coordinates
      if @crop.nil?
        tx1 = 0.0; ty1 = 0.0 # Top left
        tx2 = 1.0; ty2 = 0.0 # Top right
        tx3 = 1.0; ty3 = 1.0 # Bottom right
        tx4 = 0.0; ty4 = 1.0 # Bottom left
      else
        tx1 = @crop[:x] / @crop[:image_width].to_f; ty1 = @crop[:y] / @crop[:image_height].to_f # Top left
        tx2 = tx1 + (@crop[:width] / @crop[:image_width].to_f); ty2 = ty1                       # Top right
        tx3 = tx2; ty3 = ty1 + (@crop[:height] / @crop[:image_height].to_f)                     # Botttom right
        tx4 = tx1; ty4 = ty3                                                                    # Bottom left
      end

      [ tx1, ty1, tx2, ty2, tx3, ty3, tx4, ty4 ]
    end

    private

    def rotate(x, y)
      return [x, y] if @rotate == 0

      # Convert from degrees to radians
      angle = @rotate * Math::PI / 180.0

      # Get the sine and cosine of the angle
      sa = Math.sin(angle)
      ca = Math.cos(angle)

      # Translate point to origin
      x -= @rx
      y -= @ry

      # Rotate point
      xnew = x * ca - y * sa;
      ynew = x * sa + y * ca;

      # Translate point back
      x = xnew + @rx;
      y = ynew + @ry;

      [x, y]
    end
  end
end
