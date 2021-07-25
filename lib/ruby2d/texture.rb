# Ruby2D::Text

module Ruby2D
    class Texture
      attr_reader :width, :height, :texture_id

      def initialize(texture_id, width, height)
        @texture_id = texture_id
        @width = width
        @height = height
      end
    end
end