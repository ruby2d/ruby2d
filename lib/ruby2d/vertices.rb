# Ruby2D::Vertices

module Ruby2D
  # Vertex and texture coordinates for tile placements
  class Vertices
    # Texture coordinates for an uncropped quad (full image)
    TEX_UNCROPPED_COORDS = [
      0.0, 0.0, # top left
      1.0, 0.0, # top right
      1.0, 1.0, # bottom right
      0.0, 1.0  # bottom left
    ].freeze

    # Create a vertex set for a tile placement
    def initialize(x, y, width, height, rotate, crop: nil, flip: nil)
      @x = x
      @y = y
      @width = width.to_f
      @height = height.to_f
      @rotate = rotate
      @crop = crop
      apply_flip(flip)
      @rx = @x + (@width / 2.0)
      @ry = @y + (@height / 2.0)
    end

    # Get the quad corner coordinates as a flat array
    def coordinates
      @coordinates ||= @rotate.zero? ? unrotated_coordinates : rotated_coordinates
    end

    # Get the texture UV coordinates as a flat array
    def texture_coordinates
      @texture_coordinates ||= @crop ? cropped_texture_coordinates : TEX_UNCROPPED_COORDS
    end

    private

    def unrotated_coordinates
      [
        @x,          @y,           # top left
        @x + @width, @y,           # top right
        @x + @width, @y + @height, # bottom right
        @x,          @y + @height  # bottom left
      ]
    end

    def rotated_coordinates
      angle = @rotate * Math::PI / 180.0
      sa = Math.sin(angle)
      ca = Math.cos(angle)

      [
        *rotate_point(@x,          @y,           sa, ca), # top left
        *rotate_point(@x + @width, @y,           sa, ca), # top right
        *rotate_point(@x + @width, @y + @height, sa, ca), # bottom right
        *rotate_point(@x,          @y + @height, sa, ca)  # bottom left
      ]
    end

    # Rotate a point around the center of the quad, given the precomputed sine
    # and cosine of the rotation angle
    def rotate_point(x, y, sa, ca)
      dx = x - @rx
      dy = y - @ry

      [dx * ca - dy * sa + @rx,
       dx * sa + dy * ca + @ry]
    end

    def cropped_texture_coordinates
      img_w = @crop[:image_width].to_f
      img_h = @crop[:image_height].to_f

      left   = @crop[:x] / img_w
      top    = @crop[:y] / img_h
      right  = left + (@crop[:width] / img_w)
      bottom = top + (@crop[:height] / img_h)

      [
        left,  top,    # top left
        right, top,    # top right
        right, bottom, # bottom right
        left,  bottom  # bottom left
      ]
    end

    def apply_flip(flip)
      return unless flip

      if flip == :horizontal || flip == :both
        @x += @width
        @width = -@width
      end

      if flip == :vertical || flip == :both
        @y += @height
        @height = -@height
      end
    end
  end
end
