# Ruby2D::Ellipse

module Ruby2D
  # An ellipse
  class Ellipse
    include Renderable

    attr_accessor :xradius, :yradius, :sectors, :rotate, :fill, :stroke_width
    attr_reader :x, :y, :stroke_color
    alias_method :stroke_colour, :stroke_color

    # Set the x position (the center). Pass a symbol (`:left`, `:center`,
    # `:right`) to set alignment intent — resolved at draw time against the
    # window, with the ellipse's bounding box hugging the chosen edge.
    def x=(value)
      return self.x_align = value if value.is_a?(Symbol)
      @x_align = nil unless @_resolving_alignment
      @x = value
    end

    # Set the y position (the center). Pass a symbol (`:top`, `:center`,
    # `:bottom`) to set alignment intent.
    def y=(value)
      return self.y_align = value if value.is_a?(Symbol)
      @y_align = nil unless @_resolving_alignment
      @y = value
    end

    # Create an ellipse
    def initialize(x: 0, y: 0, z: 0, xradius: 50, yradius: 30, sectors: 30,
                   rotate: 0, rx: nil, ry: nil,
                   color: nil, colour: nil, opacity: nil,
                   fill: true, stroke_width: 0, stroke_color: nil, stroke_colour: nil,
                   add: true, visible: true,
                   padding: nil, padding_top: nil, padding_right: nil,
                   padding_bottom: nil, padding_left: nil)
      x, y = _extract_alignment(x, y)
      _apply_padding(padding, padding_top, padding_right, padding_bottom, padding_left)
      _validate_dimensions(xradius: xradius, yradius: yradius)
      @x = x
      @y = y
      @z = z
      @xradius = xradius
      @yradius = yradius
      @sectors = sectors
      @rotate = rotate
      @_user_rx = rx
      @_user_ry = ry
      self.color = color || colour || 'white'
      self.opacity = opacity unless opacity.nil?
      @fill = fill
      @stroke_width = stroke_width
      self.stroke_color = stroke_color || stroke_colour || (color || colour)
      self.stroke_color.opacity = opacity unless opacity.nil?
      @visible = visible
      self.add if add
    end

    # Get the rotation center x coordinate
    def rx
      @_user_rx.nil? ? @x : @_user_rx
    end

    # Get the rotation center y coordinate
    def ry
      @_user_ry.nil? ? @y : @_user_ry
    end

    # Set the rotation center x coordinate
    def rx=(val)
      @_user_rx = val
    end

    # Set the rotation center y coordinate
    def ry=(val)
      @_user_ry = val
    end

    # Bounding-box width and height (the axis diameters)
    def width
      @xradius * 2
    end

    def height
      @yradius * 2
    end

    # Set the fill color. Single-color only — a per-vertex color array is
    # rejected with a clear message rather than a generic "not a valid color".
    def color=(color)
      c = Color.set(color)
      if c.is_a?(Color::Set)
        raise ArgumentError, "`#{self.class}` does not support per-vertex colors; pass a single color"
      end

      @color = c
      @_cc = nil
    end

    # Set the stroke color. Single-color only — a per-vertex array is rejected.
    def stroke_color=(c)
      resolved = c.nil? ? nil : Color.set(c)
      if resolved.is_a?(Color::Set)
        raise ArgumentError, "`#{self.class}` does not support per-vertex stroke colors; pass a single color"
      end

      @stroke_color = resolved || Color.new('white')
      @_stroke_cc = nil
    end
    alias_method :stroke_colour=, :stroke_color=

    # Check if the ellipse contains the given point
    def contains?(x, y)
      x, y = _unrotate(x, y)
      dx = x - @x
      dy = y - @y
      rx = @xradius.to_f
      ry = @yradius.to_f
      # A zero radius collapses the ellipse on that axis, so the point must lie
      # exactly on it — mirrors Circle, which is "inside" only at the center
      # when radius is 0. (The plain formula would divide by zero here.)
      return false if rx == 0 && dx != 0
      return false if ry == 0 && dy != 0
      tx = rx == 0 ? 0.0 : (dx * dx) / (rx * rx)
      ty = ry == 0 ? 0.0 : (dy * dy) / (ry * ry)
      tx + ty <= 1.0
    end

    # Render an ellipse without creating an instance
    def self.render(x: 0, y: 0, xradius: 50, yradius: 30, sectors: 30, rotate: 0,
                    rx: nil, ry: nil, color: nil, colour: nil, opacity: nil,
                    fill: true, stroke_width: 0, stroke_color: nil, stroke_colour: nil)
      fill_input = color || colour
      explicit_stroke = stroke_color || stroke_colour
      stroke_input = explicit_stroke || fill_input
      # Reject a per-vertex stroke color, matching the instance setter — ellipses
      # have a single stroke color. Only check when the stroke is drawn or an
      # explicit stroke color was given, so an invalid one still raises.
      if (stroke_width > 0 || !explicit_stroke.nil?) && !stroke_input.nil? &&
         Color.set(stroke_input).is_a?(Color::Set)
        raise ArgumentError, "`#{self}` does not support per-vertex stroke colors; pass a single color"
      end

      Window.render_ready_check
      c = Renderable.flatten_color(fill_input, 1, opacity)

      # `rotate` (degrees) tilts the ellipse and, given a pivot other than the
      # center, orbits its center around that pivot — matching Quad/Triangle.
      # `rad` is passed to the draw so the rim itself tilts.
      rad = rotate * Math::PI / 180.0
      if rotate != 0
        cx = rx || x
        cy = ry || y
        sa = Math.sin(rad); ca = Math.cos(rad)
        dx = x - cx; dy = y - cy
        x = dx * ca - dy * sa + cx
        y = dx * sa + dy * ca + cy
      end

      Ext.draw_ellipse(x, y, xradius, yradius, rad, sectors, c[0], c[1], c[2], c[3]) if fill
      # Resolve the stroke color only when actually stroking.
      if stroke_width > 0
        sc = Renderable.resolve_single_color(stroke_input) || Color.new('white')
        sc = Color.new(sc)
        sc.opacity = opacity if opacity
        Ext.stroke_ellipse(x, y, xradius, yradius, rad, sectors, stroke_width, sc.r, sc.g, sc.b, sc.a)
      end
    end

    private

    # Ellipse is center-anchored, so shift the alignment resolver's bounding-box
    # top-left result by each radius to land on the center.
    def _alignment_anchor_dx
      @xradius
    end

    def _alignment_anchor_dy
      @yradius
    end

    def render
      _resolve_alignment
      ensure_cc
      ensure_scc if @stroke_width && @stroke_width > 0

      x = @x; y = @y

      rad = @rotate * Math::PI / 180.0
      if @rotate != 0
        cx = rx; cy = ry
        sa = Math.sin(rad); ca = Math.cos(rad)
        dx = x - cx; dy = y - cy
        x = dx * ca - dy * sa + cx
        y = dx * sa + dy * ca + cy
      end

      if @fill
        cc = @_cc
        Ext.draw_ellipse(x, y, @xradius, @yradius, rad, @sectors, cc[0], cc[1], cc[2], cc[3])
      end

      if @stroke_width && @stroke_width > 0
        scc = @_stroke_cc
        Ext.stroke_ellipse(x, y, @xradius, @yradius, rad, @sectors, @stroke_width,
                           scc[0], scc[1], scc[2], scc[3])
      end
    end

    # Scene-graph draw hook (see Renderable#_render_scene). Ellipse's `render` is
    # already zero-arg, so the hook is the same method under the scene name.
    alias_method :_render_scene, :render
    public :_render_scene

    def ensure_cc
      if @_cc.nil? || @_cc[0] != @color.r || @_cc[1] != @color.g || @_cc[2] != @color.b || @_cc[3] != @color.a
        @_cc = [@color.r, @color.g, @color.b, @color.a]
      end
    end

    def ensure_scc
      c = @stroke_color
      if @_stroke_cc.nil? || @_stroke_cc[0] != c.r || @_stroke_cc[1] != c.g || @_stroke_cc[2] != c.b || @_stroke_cc[3] != c.a
        @_stroke_cc = [c.r, c.g, c.b, c.a]
      end
    end
  end
end
