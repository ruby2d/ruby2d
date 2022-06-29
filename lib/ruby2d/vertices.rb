# frozen_string_literal: true

# Ruby2D::Vertices

module Ruby2D
  # This internal class generates a vertices array which are passed to the openGL rendering code.
  # The vertices array is split up into 4 groups (1 - top left, 2 - top right, 3 - bottom right, 4 - bottom left)
  # This class is responsible for transforming textures, it can scale / crop / rotate and flip textures
  class Vertices
    def initialize(x, y, width, height, rotate, crop: nil, flip: nil)
      @flip = flip
      @x = x
      @y = y
      @width = width.to_f
      @height = height.to_f
      @rotate = rotate
      @rx = @x + (@width / 2.0)
      @ry = @y + (@height / 2.0)
      @crop = crop
      @coordinates = nil
      @texture_coordinates = nil
      _apply_flip unless @flip.nil?
    end

    def coordinates
      @coordinates ||= if @rotate.zero?
                         _unrotated_coordinates
                       else
                         _calculate_coordinates
                       end
    end

    TEX_UNCROPPED_COORDS = [
      0.0, 0.0, # top left
      1.0, 0.0,   # top right
      1.0, 1.0,   # bottom right
      0.0, 1.0    # bottom left
    ].freeze

    def texture_coordinates
      @texture_coordinates ||= if @crop.nil?
                                 TEX_UNCROPPED_COORDS
                               else
                                 _calculate_texture_coordinates
                               end
    end

    private

    def rotate(x, y)
      # Convert from degrees to radians
      angle = @rotate * Math::PI / 180.0

      # Get the sine and cosine of the angle
      sa = Math.sin(angle)
      ca = Math.cos(angle)

      # Translate point to origin
      x -= @rx
      y -= @ry

      # Rotate point
      xnew = x * ca - y * sa
      ynew = x * sa + y * ca

      # Translate point back
      x = xnew + @rx
      y = ynew + @ry

      [x, y]
    end

    def _unrotated_coordinates
      x1 = @x
      y1 = @y;           # Top left
      x2 = @x + @width
      y2 = @y;           # Top right
      x3 = @x + @width
      y3 = @y + @height; # Bottom right
      x4 = @x
      y4 = @y + @height; # Bottom left
      [x1, y1, x2, y2, x3, y3, x4, y4]
    end

    def _calculate_coordinates
      x1, y1 = rotate(@x,          @y);           # Top left
      x2, y2 = rotate(@x + @width, @y);           # Top right
      x3, y3 = rotate(@x + @width, @y + @height); # Bottom right
      x4, y4 = rotate(@x,          @y + @height); # Bottom left
      [x1, y1, x2, y2, x3, y3, x4, y4]
    end

    def _calculate_texture_coordinates
      img_width = @crop[:image_width].to_f
      img_height = @crop[:image_height].to_f

      # Top left
      tx1 = @crop[:x] / img_width
      ty1 = @crop[:y] / img_height
      # Top right
      tx2 = tx1 + (@crop[:width] / img_width)
      ty2 = ty1
      # Botttom right
      tx3 = tx2
      ty3 = ty1 + (@crop[:height] / img_height)
      # Bottom left
      # tx4 = tx1
      # ty4 = ty3

      [tx1, ty1, tx2, ty2, tx3, ty3, tx1, ty3]
    end

    def _apply_flip
      if @flip == :horizontal || @flip == :both
        @x += @width
        @width = -@width
      end

      return unless @flip == :vertical || @flip == :both

      @y += @height
      @height = -@height
    end
  end
end
