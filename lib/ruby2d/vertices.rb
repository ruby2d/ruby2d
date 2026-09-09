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

    # Create a vertex set for a tile placement. A flip mirrors the texture
    # coordinates, not the quad: mirroring the quad by negating an extent
    # reverses its winding, and SDL's software renderer drops half of a
    # reversed quad's texture detail when it's also rotated a quarter turn.
    # Every quad therefore keeps the same corner order, and the UVs carry the
    # flip. Each corner still maps to the same texel as before; only the
    # diagonal the quad is split along changes, so a flipped tile now rounds
    # at a texel seam exactly like its unflipped self.
    def initialize(x, y, width, height, rotate, crop: nil, flip: nil)
      @x = x
      @y = y
      @width = width.to_f
      @height = height.to_f
      @rotate = rotate
      @crop = crop
      @flip = flip
      @rx = @x + (@width / 2.0)
      @ry = @y + (@height / 2.0)
    end

    # Get the quad corner coordinates as a flat array
    def coordinates
      @coordinates ||= @rotate.zero? ? unrotated_coordinates : rotated_coordinates
    end

    # Get the texture UV coordinates as a flat array
    def texture_coordinates
      @texture_coordinates ||=
        if @crop || @flip
          build_texture_coordinates
        else
          TEX_UNCROPPED_COORDS
        end
    end

    # The axis-aligned box enclosing the quad, as `[left, top, right, bottom]`
    def bounds
      @bounds ||= begin
        c = coordinates
        xs = [c[0], c[2], c[4], c[6]]
        ys = [c[1], c[3], c[5], c[7]]
        [xs.min, ys.min, xs.max, ys.max]
      end
    end

    # Hit-test the drawn quad. The point is rotated back about the tile's
    # center, then tested against the unrotated box, half-open like
    # `Renderable#contains?` so a point on the right or bottom edge is outside.
    # Runs on every mouse move for every placed tile, so the rotation is
    # inlined rather than going through the array-returning `rotate_point`.
    def contains?(px, py)
      unless @rotate.zero?
        @inverse ||= begin
          angle = -@rotate * Math::PI / 180.0
          [Math.sin(angle), Math.cos(angle)]
        end
        sa = @inverse[0]
        ca = @inverse[1]
        dx = px - @rx
        dy = py - @ry
        px = dx * ca - dy * sa + @rx
        py = dx * sa + dy * ca + @ry
      end
      px >= @x && px < @x + @width && py >= @y && py < @y + @height
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

    # The crop's UV rectangle (the whole texture without one), mirrored per
    # axis for the flip, in the same corner order as `coordinates`
    def build_texture_coordinates
      if @crop
        img_w = @crop[:image_width].to_f
        img_h = @crop[:image_height].to_f

        left   = @crop[:x] / img_w
        top    = @crop[:y] / img_h
        right  = left + (@crop[:width] / img_w)
        bottom = top + (@crop[:height] / img_h)
      else
        left, top, right, bottom = 0.0, 0.0, 1.0, 1.0
      end

      left, right = right, left if @flip == :horizontal || @flip == :both
      top, bottom = bottom, top if @flip == :vertical || @flip == :both

      [
        left,  top,    # top left
        right, top,    # top right
        right, bottom, # bottom right
        left,  bottom  # bottom left
      ]
    end
  end
end
