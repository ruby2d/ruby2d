# Ruby2D::Vertices

# This class generates a vertices array which are passed to the openGL rendering code.
# The vertices array is split up into 4 groups of 8 values, a group for each corner of the texture to be drawn
#
# The values for each corner are: x, y, red, green, blue, alpha, texture x and texture y.
#
# x: the x position to draw the texture on the window
# y: the y position to draw the texture on the window
# red: the color to apply to the texture (from 0.0 - 1.0)
# green: the green component of the color to apply to the texture (from 0.0 - 1.0)
# blue: the blue component of color to apply to the texture (from 0.0 - 1.0)
# alpha: the transparency component of the color to apply to the texture (from 0.0 - 1.0)
# texture x: the point of the texture to read from, scaled from 0.0 - 1.0, 0 represents left, 1 represents right
# texture y: the point of the texture to read from, scaled from 0.0 - 1.0, 0 represents bottom, 1 represents top

module Ruby2D
  class Vertices
    def initialize(x, y, width, height, color, rotate)
      @x = x
      @y = y
      @width = width
      @height = height
      @r = color.r
      @g = color.g
      @b = color.b
      @a = color.a
      @rotate = rotate
    end

    def to_a
      x1, y1 = rotate(@x,          @y);           tx1 = 0.0; ty1 = 0.0
      x2, y2 = rotate(@x + @width, @y);           tx2 = 1.0; ty2 = 0.0
      x3, y3 = rotate(@x + @width, @y + @height); tx3 = 1.0; ty3 = 1.0
      x4, y4 = rotate(@x,          @y + @height); tx4 = 0.0; ty4 = 1.0

      [
        x1, y1, @r, @g, @b, @a, tx1, ty1, # Top left
        x2, y2, @r, @g, @b, @a, tx2, ty2, # Top right
        x3, y3, @r, @g, @b, @a, tx3, ty3, # Bottom right
        x4, y4, @r, @g, @b, @a, tx4, ty4  # Bottom left
      ]
    end

    private

    # FIXME: This does not seem to be rotating currently
    def rotate(x, y)
      return [x, y] if @rotate == 0

      rx = x + (@width / 2.0)
      ry = y + (@height / 2.0)

      # Convert from degrees to radians
      angle = @rotate * Math::PI / 180.0

      # Get the sine and cosine of the angle
      sa = Math.sin(angle)
      ca = Math.cos(angle)

      # Translate point to origin
      x -= rx
      y -= ry

      # Rotate point
      xnew = x * ca - y * sa;
      ynew = x * sa + y * ca;

      # Translate point back
      x = xnew + rx;
      y = ynew + ry;

      [x, y]
    end
  end
end