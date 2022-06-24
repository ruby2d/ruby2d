# frozen_string_literal: true

# Ruby2D::Pixel

module Ruby2D
  # Draw a single pixel by calling +Pixel.draw(...)+
  class Pixel
    def self.draw(x:, y:, size:, color:)
      color = color.to_a if color.is_a? Color

      ext_draw([x, y,
                x + size, y,
                x + size, y + size,
                x, y + size,
                color[0], color[1], color[2], color[3]])
    end
  end
end
