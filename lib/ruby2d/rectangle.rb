# Ruby2D::Rectangle

module Ruby2D
  # A rectangle
  class Rectangle < Quad
    # Create a rectangle
    def initialize(x: 0, y: 0, width: 200, height: 100, z: 0, rotate: 0,
                   rx: nil, ry: nil, color: nil, colour: nil, opacity: nil,
                   fill: true, stroke_width: 0, stroke_color: nil, stroke_colour: nil,
                   add: true, visible: true,
                   padding: nil, padding_top: nil, padding_right: nil,
                   padding_bottom: nil, padding_left: nil)
      x, y = _extract_alignment(x, y)
      _apply_padding(padding, padding_top, padding_right, padding_bottom, padding_left)
      _validate_dimensions(width: width, height: height)
      @width = width
      @height = height
      super(x1: @x = x, y1: @y = y,
            x2: x + width, y2: y,
            x3: x + width, y3: y + height,
            x4: x, y4: y + height, z: z, rotate: rotate,
            rx: rx, ry: ry,
            color: color, colour: colour, opacity: opacity,
            fill: fill, stroke_width: stroke_width,
            stroke_color: stroke_color, stroke_colour: stroke_colour,
            add: add, visible: visible)
    end

    # The x position (top-left). Rectangles are anchored at their top-left
    # corner, not the centroid like a general Quad.
    def x
      @x1
    end

    # The y position (top-left).
    def y
      @y1
    end

    # Get the rotation center x coordinate
    def rx
      @_user_rx.nil? ? (@x1 + @width / 2.0) : @_user_rx
    end

    # Get the rotation center y coordinate
    def ry
      @_user_ry.nil? ? (@y1 + @height / 2.0) : @_user_ry
    end

    # Set the x position (top-left), updating all four vertices. Pass a
    # symbol (`:left`, `:center`, `:right`) to set alignment intent.
    def x=(x)
      return self.x_align = x if x.is_a?(Symbol)
      @x_align = nil unless @_resolving_alignment
      @x = @x1 = x
      @x2 = x + @width
      @x3 = x + @width
      @x4 = x
    end

    # Set the y position (top-left), updating all four vertices. Pass a
    # symbol (`:top`, `:center`, `:bottom`) to set alignment intent.
    def y=(y)
      return self.y_align = y if y.is_a?(Symbol)
      @y_align = nil unless @_resolving_alignment
      @y = @y1 = y
      @y2 = y
      @y3 = y + @height
      @y4 = y + @height
    end

    # Set the width
    def width=(width)
      @width = width
      @x2 = @x1 + width
      @x3 = @x1 + width
    end

    # Set the height
    def height=(height)
      @height = height
      @y3 = @y1 + height
      @y4 = @y1 + height
    end

    # Render a rectangle without creating an instance. Calls the positional
    # internal directly rather than `super` — see `Quad.draw_immediate`.
    def self.render(x: 0, y: 0, width: 200, height: 100, rotate: 0,
                    rx: nil, ry: nil, color: nil, colour: nil, opacity: nil,
                    fill: true, stroke_width: 0, stroke_color: nil, stroke_colour: nil)
      draw_immediate(x, y,
                     x + width, y,
                     x + width, y + height,
                     x, y + height,
                     rotate, rx || x + width / 2.0, ry || y + height / 2.0,
                     color || colour, opacity, fill, stroke_width,
                     stroke_color || stroke_colour)
    end

    # Check if the rectangle contains the given point
    def contains?(x, y)
      x, y = Renderable._unrotate(self, x, y)
      x >= @x && x <= (@x + @width) && y >= @y && y <= (@y + @height)
    end

    private

    # Resolve symbolic alignment (e.g. `x: :center`) against the window before
    # drawing, then draw via Quad. Rectangle/Square are top-left-anchored and
    # support alignment; a bare Quad (centroid-anchored) does not, so the call
    # lives here rather than in Quad#render.
    def render
      _resolve_alignment
      super
    end

    # Scene-graph draw hook (see Renderable#_render_scene). Re-aliased here so
    # the hook picks up Rectangle's alignment-resolving `render`, not Quad's.
    alias_method :_render_scene, :render
    public :_render_scene
  end
end
