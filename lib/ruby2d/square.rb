# Ruby2D::Square

module Ruby2D
  # A square
  class Square < Rectangle
    attr_reader :size

    # Create a square
    def initialize(x: 0, y: 0, size: 100, z: 0, rotate: 0,
                   rx: nil, ry: nil, color: nil, colour: nil, opacity: nil,
                   fill: true, stroke_width: 0, stroke_color: nil, stroke_colour: nil,
                   add: true, visible: true,
                   padding: nil, padding_top: nil, padding_right: nil,
                   padding_bottom: nil, padding_left: nil)
      _validate_dimensions(size: size)
      @size = size
      super(x: x, y: y, width: size, height: size, z: z, rotate: rotate,
            rx: rx, ry: ry,
            color: color, colour: colour, opacity: opacity,
            fill: fill, stroke_width: stroke_width,
            stroke_color: stroke_color, stroke_colour: stroke_colour,
            add: add, visible: visible,
            padding: padding, padding_top: padding_top, padding_right: padding_right,
            padding_bottom: padding_bottom, padding_left: padding_left)
    end

    # Set the size of the square
    def size=(size)
      self.width = self.height = @size = size
    end

    # Render a square without creating an instance
    # Render a square without creating an instance. Calls the positional
    # internal directly rather than `super` — see `Quad.draw_immediate`.
    def self.render(x: 0, y: 0, size: 100, rotate: 0,
                    rx: nil, ry: nil, color: nil, colour: nil, opacity: nil,
                    fill: true, stroke_width: 0, stroke_color: nil, stroke_colour: nil)
      draw_immediate(x, y,
                     x + size, y,
                     x + size, y + size,
                     x, y + size,
                     rotate, rx || x + size / 2.0, ry || y + size / 2.0,
                     color || colour, opacity, fill, stroke_width,
                     stroke_color || stroke_colour)
    end

    # Make the inherited width and height attribute accessors private
    private :width=, :height=
  end
end
