# Ruby2D::Line

module Ruby2D
  # A line between two points.
  class Line
    include Renderable

    attr_accessor :x1, :x2, :y1, :y2, :stroke_width, :rotate, :dash, :gap

    # Create a line. Pass `dash:` (and optionally `gap:`) to draw a dashed line.
    # Specify endpoints via `points:` or via `x1:`/`y1:`/`x2:`/`y2:`. `points:`
    # takes precedence if both are given.
    def initialize(x1: 0, y1: 0, x2: 100, y2: 100,
                   points: nil,
                   z: 0,
                   stroke_width: 1, dash: 0, gap: 5,
                   rotate: 0, rx: nil, ry: nil,
                   color: nil, colour: nil, opacity: nil,
                   add: true, visible: true)
      if points
        Line.send(:validate_points, points)
        x1, y1 = points[0]
        x2, y2 = points[1]
      end
      @x1 = x1
      @y1 = y1
      @x2 = x2
      @y2 = y2
      @z = z
      @stroke_width = stroke_width
      @dash = dash
      @gap = gap
      @rotate = rotate
      @_user_rx = rx
      @_user_ry = ry
      self.color = color || colour || 'white'
      self.opacity = opacity unless opacity.nil?
      @visible = visible
      self.add if add
    end

    # Set the color of the line. Accepts a single color or a `Color::Set` of 2
    # (start, end) for a gradient along the length.
    def color=(color)
      color = Color.set(color)

      if color.is_a?(Color::Set) && color.length != 2
        raise ArgumentError,
              "`#{self.class}` requires 2 colors (start, end) for a gradient. #{color.length} were given."
      end

      @color = color
      @_cc = nil
    end

    # Return the length of the line
    def length
      points_distance(@x1, @y1, @x2, @y2)
    end

    # Bounding-box width and height (extent between the two endpoints)
    def width
      (@x1 - @x2).abs
    end

    def height
      (@y1 - @y2).abs
    end

    # Check if the line contains the given point — within half the stroke width
    # of the drawn segment and between its endpoints, so the hit region matches
    # the rendered (butt-capped) rectangle rather than overhanging its ends.
    # Shares the segment test with `Polyline`.
    def contains?(x, y)
      return false if @stroke_width.negative?
      x, y = _unrotate(x, y) if @rotate != 0
      half = @stroke_width / 2.0
      _point_on_segment?(x, y, @x1, @y1, @x2, @y2, half * half)
    end

    # Get the rotation center x coordinate
    def rx
      @_user_rx.nil? ? (@x1 + @x2) / 2.0 : @_user_rx
    end

    # Get the rotation center y coordinate
    def ry
      @_user_ry.nil? ? (@y1 + @y2) / 2.0 : @_user_ry
    end

    # Set the rotation center x coordinate
    def rx=(val)
      @_user_rx = val
    end

    # Set the rotation center y coordinate
    def ry=(val)
      @_user_ry = val
    end

    # Render a line without creating an instance
    def self.render(x1: 0, y1: 0, x2: 100, y2: 100,
                    points: nil,
                    stroke_width: 1, dash: 0, gap: 5,
                    rotate: 0, rx: nil, ry: nil,
                    color: nil, colour: nil, opacity: nil)
      Window.render_ready_check
      if points
        validate_points(points)
        x1, y1 = points[0]
        x2, y2 = points[1]
      end

      input = color || colour
      c = Color.for_render(input.nil? ? 'white' : input)
      if c.is_a?(Color::Set) && c.length != 2
        raise ArgumentError,
              "`#{self}` requires 2 colors (start, end) for a gradient. #{c.length} were given."
      end

      # Expand to 4 vertex colors: start -> both start corners, end -> both end corners
      c0 = c.vertex(0)
      c1 = c.vertex(1)
      c0a = opacity || c0.a
      c1a = opacity || c1.a

      if rotate != 0
        cx = rx || (x1 + x2) / 2.0
        cy = ry || (y1 + y2) / 2.0
        rad = rotate * Math::PI / 180.0
        sa = Math.sin(rad); ca = Math.cos(rad)
        dx = x1 - cx; dy = y1 - cy
        x1 = dx * ca - dy * sa + cx; y1 = dx * sa + dy * ca + cy
        dx = x2 - cx; dy = y2 - cy
        x2 = dx * ca - dy * sa + cx; y2 = dx * sa + dy * ca + cy
      end

      if dash > 0
        Ext.draw_dashed_line(
          x1, y1, x2, y2, stroke_width, dash, gap,
          c0.r, c0.g, c0.b, c0a,
          c0.r, c0.g, c0.b, c0a,
          c1.r, c1.g, c1.b, c1a,
          c1.r, c1.g, c1.b, c1a
        )
      else
        Ext.draw_line(
          x1, y1, x2, y2, stroke_width,
          c0.r, c0.g, c0.b, c0a,
          c0.r, c0.g, c0.b, c0a,
          c1.r, c1.g, c1.b, c1a,
          c1.r, c1.g, c1.b, c1a
        )
      end
    end

    private

    def self.validate_points(points)
      raise ArgumentError, 'Line requires exactly 2 points' unless points.length == 2
      raise ArgumentError, 'points must be an array of [x, y] pairs' \
        unless points.all? { |p| p.is_a?(Array) && p.length == 2 }
    end
    private_class_method :validate_points

    def render
      ensure_cc

      x1 = @x1; y1 = @y1; x2 = @x2; y2 = @y2

      if @rotate != 0
        cx = rx; cy = ry
        rad = @rotate * Math::PI / 180.0
        sa = Math.sin(rad); ca = Math.cos(rad)
        dx = x1 - cx; dy = y1 - cy
        x1 = dx * ca - dy * sa + cx; y1 = dx * sa + dy * ca + cy
        dx = x2 - cx; dy = y2 - cy
        x2 = dx * ca - dy * sa + cx; y2 = dx * sa + dy * ca + cy
      end

      cc = @_cc
      if @dash && @dash > 0
        Ext.draw_dashed_line(
          x1, y1, x2, y2, @stroke_width, @dash, @gap,
          cc[0],  cc[1],  cc[2],  cc[3],
          cc[4],  cc[5],  cc[6],  cc[7],
          cc[8],  cc[9],  cc[10], cc[11],
          cc[12], cc[13], cc[14], cc[15]
        )
      else
        Ext.draw_line(
          x1, y1, x2, y2, @stroke_width,
          cc[0],  cc[1],  cc[2],  cc[3],
          cc[4],  cc[5],  cc[6],  cc[7],
          cc[8],  cc[9],  cc[10], cc[11],
          cc[12], cc[13], cc[14], cc[15]
        )
      end
    end

    # Scene-graph draw hook (see Renderable#_render_scene). Line's `render` is
    # already zero-arg, so the hook is the same method under the scene name.
    alias_method :_render_scene, :render
    public :_render_scene

    # Calculate the distance between two points
    def points_distance(x1, y1, x2, y2)
      dx = x1 - x2
      dy = y1 - y2
      Math.sqrt(dx * dx + dy * dy)
    end

    # Build/rebuild flat color cache for the native extension. Line is a quad
    # internally, so the 2-color gradient (start, end) expands to 4 vertex
    # entries: start→both start corners, end→both end corners.
    def ensure_cc
      if @_cc.nil? || !cc_matches?
        c0 = @color.vertex(0)
        c1 = @color.vertex(1)
        @_cc = [c0.r, c0.g, c0.b, c0.a,
                c0.r, c0.g, c0.b, c0.a,
                c1.r, c1.g, c1.b, c1.a,
                c1.r, c1.g, c1.b, c1.a]
      end
    end

    # Line's 4-vertex expansion is deterministic, so checking the two source
    # entries (start and end) detects any Color::Set mutation.
    def cc_matches?
      c0 = @color.vertex(0)
      c1 = @color.vertex(1)
      return false if @_cc[0] != c0.r || @_cc[1] != c0.g || @_cc[2]  != c0.b || @_cc[3]  != c0.a
      return false if @_cc[8] != c1.r || @_cc[9] != c1.g || @_cc[10] != c1.b || @_cc[11] != c1.a
      true
    end
  end
end
