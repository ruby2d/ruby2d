# Ruby2D::Triangle

module Ruby2D
  # A triangle
  class Triangle
    include Renderable

    attr_accessor :x1, :y1,
                  :x2, :y2,
                  :x3, :y3,
                  :rotate,
                  :fill, :stroke_width
    attr_reader :color, :stroke_color
    alias_method :stroke_colour, :stroke_color

    # The x coordinate of the centroid
    def x
      (@x1 + @x2 + @x3) / 3.0
    end

    # The y coordinate of the centroid
    def y
      (@y1 + @y2 + @y3) / 3.0
    end

    # Set the x coordinate of the centroid, translating all vertices
    def x=(new_x)
      _require_numeric_position(:x, new_x)
      dx = new_x - x
      @x1 += dx
      @x2 += dx
      @x3 += dx
    end

    # Set the y coordinate of the centroid, translating all vertices
    def y=(new_y)
      _require_numeric_position(:y, new_y)
      dy = new_y - y
      @y1 += dy
      @y2 += dy
      @y3 += dy
    end

    # Bounding-box width and height (extent across the three vertices)
    def width
      xs = [@x1, @x2, @x3]
      xs.max - xs.min
    end

    def height
      ys = [@y1, @y2, @y3]
      ys.max - ys.min
    end

    # Create a triangle. Specify vertices via `points:` or via `x1:`/`y1:`/...
    # `points:` takes precedence if both are given.
    def initialize(x1: 50, y1: 0, x2: 100, y2: 100, x3: 0, y3: 100,
                   points: nil,
                   z: 0, rotate: 0, rx: nil, ry: nil,
                   color: nil, colour: nil, opacity: nil,
                   fill: true, stroke_width: 0, stroke_color: nil, stroke_colour: nil,
                   add: true, visible: true)
      if points
        Triangle.send(:validate_points, points)
        x1, y1 = points[0]
        x2, y2 = points[1]
        x3, y3 = points[2]
      end
      @x1 = x1
      @y1 = y1
      @x2 = x2
      @y2 = y2
      @x3 = x3
      @y3 = y3
      @z  = z
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

    # Set the stroke color. Accepts a single color or a `Color::Set` of 3
    # (one per vertex) interpolated around the perimeter. If nil, defaults to
    # the fill color (preserving a per-vertex set when the fill is per-vertex).
    def stroke_color=(c)
      @stroke_color = Renderable.resolve_color_or_default(c, 3, label: self.class)
      # A single stroke Color (not a per-vertex Set) takes the compact
      # `stroke_triangle_uniform` fast path.
      @_stroke_color_uniform = !@stroke_color.is_a?(Color::Set)
      @_stroke_cc = nil
    end
    alias_method :stroke_colour=, :stroke_color=

    # Set the color of the triangle
    def color=(color)
      # convert to Color or Color::Set
      color = Color.set(color)

      # require 3 colours if multiple colours provided
      if color.is_a?(Color::Set) && color.length != 3
        raise ArgumentError,
              "`#{self.class}` requires 3 colors, one for each vertex. #{color.length} were given."
      end

      @color = color # converted above
      # A single Color (not a per-vertex Set) is uniform across all three
      # vertices, so it takes the compact `draw_triangle_uniform` fast path.
      @_color_uniform = !color.is_a?(Color::Set)
      @_cc = nil # invalidate cached color components
    end

    # Check if the triangle contains the given point (inside the rendered fill)
    def contains?(x, y)
      x, y = _unrotate(x, y)
      _point_in_polygon?([@x1, @y1, @x2, @y2, @x3, @y3], x, y)
    end

    # Get the rotation center x coordinate
    def rx
      @_user_rx.nil? ? x : @_user_rx
    end

    # Get the rotation center y coordinate
    def ry
      @_user_ry.nil? ? y : @_user_ry
    end

    # Set the rotation center x coordinate
    def rx=(val)
      @_user_rx = val
    end

    # Set the rotation center y coordinate
    def ry=(val)
      @_user_ry = val
    end

    # Render a triangle without creating an instance
    def self.render(x1: 50, y1: 0, x2: 100, y2: 100, x3: 0, y3: 100,
                    points: nil,
                    rotate: 0, rx: nil, ry: nil,
                    color: nil, colour: nil, opacity: nil,
                    fill: true, stroke_width: 0, stroke_color: nil, stroke_colour: nil)
      Window.render_ready_check
      if points
        validate_points(points)
        x1, y1 = points[0]
        x2, y2 = points[1]
        x3, y3 = points[2]
      end
      fill_input = color || colour
      # Resolve the fill color once. A single Color (not a per-vertex Set) with
      # scalar opacity is uniform across all three vertices and draws via the
      # compact `draw_triangle_uniform`; otherwise build the per-vertex color
      # array from the already-resolved color (no second parse).
      # A per-vertex color flattens straight to floats, skipping the
      # `Color::Set` the general path builds — that allocates and parses one
      # `Color` per vertex on every call. `resolved` stays nil in that case
      # and the stroke below resolves for itself if it ends up needing one.
      # The `is_a?(Array)` guard is inline so the common single-color call
      # doesn't pay for a method call that would only decline.
      c = fill_input.is_a?(Array) ? Renderable.flatten_per_vertex(fill_input, 3, opacity) : nil
      if c
        resolved = nil
        uniform = false
      else
        resolved = Color.for_render(fill_input.nil? ? 'white' : fill_input)
        uniform = !resolved.is_a?(Color::Set) && !opacity.is_a?(Array)
        c = uniform ? nil : Renderable.flatten_resolved_color(resolved, 3, opacity, label: self)
      end

      # Rotation is inlined into locals (as in `render` below and Line#render):
      # a helper returning the rotated points would allocate an array per
      # rotated shape per frame — measured 2.9µs vs 1.8µs per quad on wasm.
      if rotate != 0
        cx = rx || ((x1 + x2 + x3) / 3.0)
        cy = ry || ((y1 + y2 + y3) / 3.0)
        rad = rotate * Math::PI / 180.0
        sa = Math.sin(rad)
        ca = Math.cos(rad)
        dx = x1 - cx; dy = y1 - cy
        x1 = dx * ca - dy * sa + cx; y1 = dx * sa + dy * ca + cy
        dx = x2 - cx; dy = y2 - cy
        x2 = dx * ca - dy * sa + cx; y2 = dx * sa + dy * ca + cy
        dx = x3 - cx; dy = y3 - cy
        x3 = dx * ca - dy * sa + cx; y3 = dx * sa + dy * ca + cy
      end

      if fill
        if uniform
          a = opacity || resolved.a
          Ext.draw_triangle_uniform(x1, y1, x2, y2, x3, y3, resolved.r, resolved.g, resolved.b, a)
        else
          c1r, c1g, c1b, c1a, c2r, c2g, c2b, c2a, c3r, c3g, c3b, c3a = c
          Ext.draw_triangle(
            x1, y1, c1r, c1g, c1b, c1a,
            x2, y2, c2r, c2g, c2b, c2a,
            x3, y3, c3r, c3g, c3b, c3a
          )
        end
      end

      # Resolve the stroke color only when actually stroking. A single stroke
      # color draws via the compact `stroke_triangle_uniform`; a per-vertex Set
      # keeps the splatting path. When no explicit stroke is given the stroke
      # reuses the already-resolved fill color. (An explicit stroke color is
      # still validated at stroke_width 0 below, matching the instance constructor.)
      if stroke_width > 0
        stroke_input = stroke_color || stroke_colour || fill_input
        sresolved = if !stroke_input.equal?(fill_input)
                      Color.for_render(stroke_input)
                    else
                      resolved || Color.for_render(fill_input.nil? ? 'white' : fill_input)
                    end
        if !sresolved.is_a?(Color::Set) && !opacity.is_a?(Array)
          sa = opacity || sresolved.a
          Ext.stroke_triangle_uniform(x1, y1, x2, y2, x3, y3, stroke_width,
                                      sresolved.r, sresolved.g, sresolved.b, sa)
        else
          s1r, s1g, s1b, s1a, s2r, s2g, s2b, s2a, s3r, s3g, s3b, s3a =
            Renderable.flatten_resolved_color(sresolved, 3, opacity, label: self)
          Ext.stroke_triangle(
            x1, y1, x2, y2, x3, y3, stroke_width,
            s1r, s1g, s1b, s1a,
            s2r, s2g, s2b, s2a,
            s3r, s3g, s3b, s3a
          )
        end
      elsif stroke_color || stroke_colour
        Renderable.flatten_color(stroke_color || stroke_colour, 3, opacity, label: self)
      end
    end

    private

    def self.validate_points(points)
      raise ArgumentError, 'Triangle requires exactly 3 points' unless points.length == 3
      raise ArgumentError, 'points must be an array of [x, y] pairs' \
        unless points.all? { |p| p.is_a?(Array) && p.length == 2 }
    end
    private_class_method :validate_points

    def render
      ensure_cc
      ensure_scc if @stroke_width && @stroke_width > 0

      x1, y1, x2, y2, x3, y3 = @x1, @y1, @x2, @y2, @x3, @y3

      # Rotation inlined into locals — see the `Triangle.render` note.
      if @rotate != 0
        cx = rx; cy = ry
        rad = @rotate * Math::PI / 180.0
        sa = Math.sin(rad)
        ca = Math.cos(rad)
        dx = x1 - cx; dy = y1 - cy
        x1 = dx * ca - dy * sa + cx; y1 = dx * sa + dy * ca + cy
        dx = x2 - cx; dy = y2 - cy
        x2 = dx * ca - dy * sa + cx; y2 = dx * sa + dy * ca + cy
        dx = x3 - cx; dy = y3 - cy
        x3 = dx * ca - dy * sa + cx; y3 = dx * sa + dy * ca + cy
      end

      if @fill
        cc = @_cc
        if @_color_uniform
          Ext.draw_triangle_uniform(x1, y1, x2, y2, x3, y3, cc[0], cc[1], cc[2], cc[3])
        else
          Ext.draw_triangle(
            x1, y1, cc[0], cc[1], cc[2],  cc[3],
            x2, y2, cc[4], cc[5], cc[6],  cc[7],
            x3, y3, cc[8], cc[9], cc[10], cc[11]
          )
        end
      end

      if @stroke_width && @stroke_width > 0
        scc = @_stroke_cc
        if @_stroke_color_uniform
          Ext.stroke_triangle_uniform(x1, y1, x2, y2, x3, y3, @stroke_width, scc[0], scc[1], scc[2], scc[3])
        else
          Ext.stroke_triangle(
            x1, y1, x2, y2, x3, y3, @stroke_width,
            scc[0], scc[1], scc[2],  scc[3],
            scc[4], scc[5], scc[6],  scc[7],
            scc[8], scc[9], scc[10], scc[11]
          )
        end
      end
    end

    # Scene-graph draw hook (see Renderable#_render_scene). Triangle's `render`
    # is already zero-arg, so the hook is the same method under the scene name.
    alias_method :_render_scene, :render
    public :_render_scene

    # Build/rebuild flat per-vertex stroke color cache (3 × rgba = 12 floats)
    def ensure_scc
      if @_stroke_color_uniform
        c = @stroke_color
        if @_stroke_cc.nil? || @_stroke_cc[0] != c.r || @_stroke_cc[1] != c.g || @_stroke_cc[2] != c.b || @_stroke_cc[3] != c.a
          @_stroke_cc = [c.r, c.g, c.b, c.a]
        end
      elsif @_stroke_cc.nil? || !scc_matches?
        @_stroke_cc = Array.new(12)
        3.times do |i|
          c = @stroke_color.vertex(i)
          @_stroke_cc[i * 4]     = c.r
          @_stroke_cc[i * 4 + 1] = c.g
          @_stroke_cc[i * 4 + 2] = c.b
          @_stroke_cc[i * 4 + 3] = c.a
        end
      end
    end

    def scc_matches?
      3.times do |i|
        c = @stroke_color.vertex(i)
        return false if @_stroke_cc[i * 4]     != c.r
        return false if @_stroke_cc[i * 4 + 1] != c.g
        return false if @_stroke_cc[i * 4 + 2] != c.b
        return false if @_stroke_cc[i * 4 + 3] != c.a
      end
      true
    end

    # Build/rebuild flat color cache for the native extension
    def ensure_cc
      # Solid fill: cache 4 floats and validity-check 4 comparisons (the
      # per-frame check still catches in-place `color.opacity=` fades). Mirrors
      # the Circle/Ellipse single-color cache.
      if @_color_uniform
        c = @color
        if @_cc.nil? || @_cc[0] != c.r || @_cc[1] != c.g || @_cc[2] != c.b || @_cc[3] != c.a
          @_cc = [c.r, c.g, c.b, c.a]
        end
      elsif @_cc.nil? || !cc_matches?
        @_cc = Array.new(12)
        3.times do |i|
          c = @color.vertex(i)
          @_cc[i * 4]     = c.r
          @_cc[i * 4 + 1] = c.g
          @_cc[i * 4 + 2] = c.b
          @_cc[i * 4 + 3] = c.a
        end
      end
    end

    def cc_matches?
      3.times do |i|
        c = @color.vertex(i)
        return false if @_cc[i * 4]     != c.r
        return false if @_cc[i * 4 + 1] != c.g
        return false if @_cc[i * 4 + 2] != c.b
        return false if @_cc[i * 4 + 3] != c.a
      end
      true
    end
  end
end
