# Ruby2D::Text

module Ruby2D
    class Texture
      attr_reader :width, :height, :texture_id

      def initialize(pixel_data, width, height)
        @pixel_data = pixel_data
        @width = width
        @height = height
        @texture_id = 0
      end

      def self.load_text(font, text)
        Texture.new(*ext_load_text(font.ttf_font, text))
      end

      def draw(coordinates, texture_coordinates, color)
        if @texture_id == 0
          @texture_id = ext_create(@pixel_data, @width, @height)
          @pixel_data = nil
        end

        color = [color.r, color.g, color.b, color.a]
        ext_draw(coordinates, texture_coordinates, color, @texture_id)
      end
    end
end