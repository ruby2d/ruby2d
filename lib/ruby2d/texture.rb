# frozen_string_literal: true

# Ruby2D::Texture

module Ruby2D
  # This internal class is used to hold raw pixel data which in turn is used to
  # render textures via openGL rendering code.
  class Texture
    attr_reader :width, :height, :texture_id

    def initialize(pixel_data, width, height)
      @pixel_data = pixel_data
      @width = width
      @height = height
      @texture_id = 0
    end

    def draw(coordinates, texture_coordinates, color)
      if @texture_id.zero?
        @texture_id = ext_create(@pixel_data, @width, @height)
        @pixel_data = nil
      end

      color = [color.r, color.g, color.b, color.a]
      ext_draw(coordinates, texture_coordinates, color, @texture_id)
    end

    def delete
      ext_delete(@texture_id)
    end
  end
end
