# Ruby2D::Text

module Ruby2D
    class Texture
      attr_reader :width, :height, :texture_id

      def initialize(texture_id, width, height)
        @texture_id = texture_id
        @width = width
        @height = height
      end

      def self.load_text(font, text)
        Texture.new(*ext_load_text(font.ttf_font, text))
      end
    end
end