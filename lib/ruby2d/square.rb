# frozen_string_literal: true

# Ruby2D::Square

module Ruby2D
  # A square
  class Square < Rectangle
    attr_reader :size

    # Create an square
    # @param [Numeric] x
    # @param [Numeric] y
    # @param [Numeric] size is width and height
    # @param [Numeric] z
    # @param [String, Array] color A single colour or an array of exactly 4 colours
    # @param [Numeric] opacity Opacity of the image when rendering
    # @raise [ArgumentError] if an array of colours does not have 4 entries
    def initialize(x: 0, y: 0, size: 100, z: 0, color: nil, colour: nil, opacity: nil)
      @size = size
      super(x: x, y: y, width: size, height: size, z: z,
            color: color, colour: colour, opacity: opacity)
    end

    # Set the size of the square
    def size=(size)
      self.width = self.height = @size = size
    end

    def self.draw(x:, y:, size:, color:)
      super(x: x, y: y,
            width: size, height: size,
            color: color)
    end

    # Make the inherited width and height attribute accessors private
    private :width=, :height=
  end
end
