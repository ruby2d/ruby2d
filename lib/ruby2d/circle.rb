# Ruby2D::Circle

module Ruby2D
  # A circle
  class Circle
    include Renderable

    attr_accessor :radius, :sectors, :rotate, :fill, :stroke_width
    attr_reader :x, :y, :stroke_color
    alias_method :stroke_colour, :stroke_color

    # Set the x position (the center). Pass a symbol (`:left`, `:center`,
    # `:right`) to set alignment intent — resolved at draw time against the
    # window, with the circle's bounding box hugging the chosen edge.
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

    # Create a circle
    def initialize(x: 0, y: 0, z: 0, radius: 50, sectors: 30,
                   rotate: 0, rx: nil, ry: nil,
                   color: nil, colour: nil, opacity: nil,
                   fill: true, stroke_width: 0, stroke_color: nil, stroke_colour: nil,
                   add: true, visible: true,
                   padding: nil, padding_top: nil, padding_right: nil,
                   padding_bottom: nil, padding_left: nil)
      x, y = _extract_alignment(x, y)
      _apply_padding(padding, padding_top, padding_right, padding_bottom, padding_left)
      _validate_dimensions(radius: radius)
      @x = x
      @y = y
      @z = z
      @radius = radius
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

    # Bounding-box width and height (the diameter)
    def width
      @radius * 2
    end

    def height
      @radius * 2
    end

    # Set the color value. Single-color only — a per-vertex color array is
    # rejected with a clear message rather than a generic "not a valid color".
    def color=(color)
      c = Color.set(color)
      if c.is_a?(Color::Set)
        raise ArgumentError, "`#{self.class}` does not support per-vertex colors; pass a single color"
      end

      @color = c
      @_cc = nil # invalidate cached color components
    end

    # Check if the circle contains the given point. Compares squared distance
    # to squared radius to skip the square root on this per-event hit path. A
    # negative radius (reachable via the unguarded runtime setter) contains
    # nothing, matching the old `sqrt(...) <= @radius` behavior the squared form
    # would otherwise lose.
    def contains?(x, y)
      return false if @radius.negative?
      x, y = Renderable._unrotate(self, x, y) if @rotate != 0
      dx = x - @x
      dy = y - @y
      dx * dx + dy * dy <= @radius * @radius
    end

    # Render a circle without creating an instance
    def self.render(x: 0, y: 0, radius: 50, sectors: 30, rotate: 0,
                    rx: nil, ry: nil, color: nil, colour: nil, opacity: nil,
                    fill: true, stroke_width: 0, stroke_color: nil, stroke_colour: nil)
      fill_input = color || colour
      explicit_stroke = stroke_color || stroke_colour
      stroke_input = explicit_stroke || fill_input
      # Reject a per-vertex stroke color, matching the instance setter — circles
      # have a single stroke color. Only check when the stroke is drawn or an
      # explicit stroke color was given, so an invalid one still raises.
      if (stroke_width > 0 || !explicit_stroke.nil?) && !stroke_input.nil? &&
         Color.set(stroke_input).is_a?(Color::Set)
        raise ArgumentError, "`#{self}` does not support per-vertex stroke colors; pass a single color"
      end

      Window.render_ready_check
      # Resolve the fill color once (as Quad#draw_immediate does). The common
      # case — a single Color with scalar opacity — reads the resolved
      # channels directly; only a `Color::Set` or per-vertex opacity array
      # pays for the flattened array (and gets the arity errors it raises).
      # `for_render` returns a shared cached instance — read-only here.
      resolved = Color.for_render(fill_input.nil? ? 'white' : fill_input)
      uniform = !resolved.is_a?(Color::Set) && !opacity.is_a?(Array)
      c = uniform ? nil : Renderable.flatten_resolved_color(resolved, 1, opacity, label: self)

      if rotate != 0
        cx = rx || x
        cy = ry || y
        rad = rotate * Math::PI / 180.0
        sa = Math.sin(rad); ca = Math.cos(rad)
        dx = x - cx; dy = y - cy
        x = dx * ca - dy * sa + cx
        y = dx * sa + dy * ca + cy
      end

      if fill
        if uniform
          Ext.draw_circle(x, y, radius, sectors,
                          resolved.r, resolved.g, resolved.b, opacity || resolved.a)
        else
          Ext.draw_circle(x, y, radius, sectors, c[0], c[1], c[2], c[3])
        end
      end
      # Resolve the stroke color only when actually stroking.
      if stroke_width > 0
        sc = Renderable.resolve_single_color(stroke_input) || Color.new('white')
        sc = Color.new(sc)
        sc.opacity = opacity if opacity
        Ext.stroke_circle(x, y, radius, sectors, stroke_width, sc.r, sc.g, sc.b, sc.a)
      end
    end

    private

    # Circle is center-anchored, so shift the alignment resolver's bounding-box
    # top-left result by the radius to land on the center.
    def _alignment_anchor_dx
      @radius
    end

    def _alignment_anchor_dy
      @radius
    end

    def render
      _resolve_alignment
      ensure_cc
      ensure_scc if @stroke_width && @stroke_width > 0

      x = @x; y = @y

      if @rotate != 0
        cx = rx; cy = ry
        rad = @rotate * Math::PI / 180.0
        sa = Math.sin(rad); ca = Math.cos(rad)
        dx = x - cx; dy = y - cy
        x = dx * ca - dy * sa + cx
        y = dx * sa + dy * ca + cy
      end

      if @fill
        cc = @_cc
        Ext.draw_circle(x, y, @radius, @sectors, cc[0], cc[1], cc[2], cc[3])
      end

      if @stroke_width && @stroke_width > 0
        scc = @_stroke_cc
        Ext.stroke_circle(x, y, @radius, @sectors, @stroke_width, scc[0], scc[1], scc[2], scc[3])
      end
    end

    # Scene-graph draw hook (see Renderable#_render_scene). Circle's `render` is
    # already zero-arg, so the hook is the same method under the scene name.
    alias_method :_render_scene, :render
    public :_render_scene

    # Build/rebuild the flat color cache for the native extension. Rebuilt
    # only when the color's revision changes (see `Color#_rev`); `color=`
    # clears the cache when the object itself is swapped.
    def ensure_cc
      rev = @color._rev
      return if @_cc && @_cc_rev == rev

      @_cc = [@color.r, @color.g, @color.b, @color.a]
      @_cc_rev = rev
    end

    def ensure_scc
      rev = @stroke_color._rev
      return if @_stroke_cc && @_stroke_cc_rev == rev

      @_stroke_cc = [@stroke_color.r, @stroke_color.g, @stroke_color.b, @stroke_color.a]
      @_stroke_cc_rev = rev
    end
  end
end
