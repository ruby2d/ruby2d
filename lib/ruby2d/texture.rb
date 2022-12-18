# frozen_string_literal: true

# Ruby2D::Texture

module Ruby2D
  # This internal class is used to hold raw pixel data which in turn is used to
  # render textures via openGL rendering code.
  class Texture
    attr_reader :width, :height, :texture_id

    WHITE_OPAQUE_AR = [1.0, 1.0, 1.0, 1.0].freeze

    def initialize(pixel_data, width, height)
      @pixel_data = pixel_data
      @width = width
      @height = height
      @texture_id = 0
    end

    # Draw the texture
    # @param coordinates [Array(x1, y1, x2, y2, x3, y3, x4, y4)] Destination coordinates
    # @param texture_coordinates [Array(tx1, ty1, tx2, ty2, tx3, ty3, tx1, ty3)] Source (texture) coordinates
    # @param color [Ruby2D::Color] Tint/blend the texture when it's drawn
    def draw(coordinates, texture_coordinates, color = nil)
      if @texture_id.zero?
        @texture_id = ext_create(@pixel_data, @width, @height)
        @pixel_data = nil
      end

      color = color.nil? ? WHITE_OPAQUE_AR : [color.r, color.g, color.b, color.a]
      ext_draw(coordinates, texture_coordinates, color, @texture_id)
    end

    def delete
      ext_delete(@texture_id)
    end
  end
end
