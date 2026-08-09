# Ruby2D::Polyline

module Ruby2D
  # A connected sequence of line segments. Stroke-only (no fill).
  # Set `closed: true` to connect the last point back to the first.
  class Polyline
    include Renderable

    attr_accessor :rotate, :stroke_width, :closed

    # Miter-join limit, matching `R2D_MITER_LIMIT` in the C extension (the SVG
    # default). A sharp corner's miter is clamped to `MITER_LIMIT * stroke_width / 2`.
    MITER_LIMIT = 4.0

    # Create a polyline
    # points is an array of [x, y] pairs with N >= 2 vertices
    def initialize(points:, z: 0, rotate: 0, rx: nil, ry: nil,
                   color: nil, colour: nil, opacity: nil,
                   stroke_width: 1, closed: false, add: true, visible: true)
      raise ArgumentError, 'Polyline requires at least 2 points' if points.length < 2
      raise ArgumentError, 'points must be an array of [x, y] pairs' \
        unless points.all? { |p| p.is_a?(Array) && p.length == 2 }

      @coordinates = points.flat_map { |x, y| [x.to_f, y.to_f] }
      @z = z
      @rotate = rotate
      @_user_rx = rx
      @_user_ry = ry
      @stroke_width = stroke_width
      @closed = closed
      self.color = color || colour || 'white'
      self.opacity = opacity unless opacity.nil?
      @visible = visible
      self.add if add
    end

    # Number of vertices
    def vertex_count
      @coordinates.length / 2
    end

    # The vertices as an array of [x, y] pairs
    def points
      @coordinates.each_slice(2).to_a
    end

    # Bounding-box width and height (extent across all vertices)
    def width
      xs = @coordinates.each_slice(2).map(&:first)
      xs.max - xs.min
    end

    def height
      ys = @coordinates.each_slice(2).map(&:last)
      ys.max - ys.min
    end

    # Test whether (x, y) lies on the polyline's stroke. Hit-tests against the
    # exact shape the renderer draws — the ribbon between the outer and inner
    # stroke outlines, with mitered joints and butt-capped open ends — so the
    # clickable region matches the visible pixels, corners and all. A closed
    # path joins at every vertex (no open ends).
    def contains?(x, y)
      return false unless @stroke_width.positive?
      x, y = Renderable._unrotate(self, x, y) if @rotate != 0
      n = vertex_count
      outer, inner = compute_stroke_outline
      edges = @closed ? n : n - 1
      edges.times do |i|
        j = (i + 1) % n
        # The renderer fills each edge as the quad outer[i] → inner[i] →
        # inner[j] → outer[j]; the point is on the stroke iff it lies inside any
        # of those quads. The miter outline makes the corners exact.
        oi = outer[i]; ii = inner[i]
        oj = outer[j]; ij = inner[j]
        return true if _point_in_polygon?(
          [oi[0], oi[1], ii[0], ii[1], ij[0], ij[1], oj[0], oj[1]], x, y
        )
      end
      false
    end

    # Centroid x
    def x
      sum = 0.0
      n = vertex_count
      n.times { |i| sum += @coordinates[i * 2] }
      sum / n
    end

    # Centroid y
    def y
      sum = 0.0
      n = vertex_count
      n.times { |i| sum += @coordinates[i * 2 + 1] }
      sum / n
    end

    # Set the centroid x coordinate, translating all vertices
    def x=(new_x)
      _require_numeric_position(:x, new_x)
      dx = new_x - x
      i = 0
      while i < @coordinates.length
        @coordinates[i] += dx
        i += 2
      end
    end

    # Set the centroid y coordinate, translating all vertices
    def y=(new_y)
      _require_numeric_position(:y, new_y)
      dy = new_y - y
      i = 1
      while i < @coordinates.length
        @coordinates[i] += dy
        i += 2
      end
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

    # The stroke color. Accepts a single color or a `Color::Set` of
    # vertex_count colors (one per vertex) interpolated along the path.
    def color=(c)
      @color = Renderable.resolve_color_or_default(c, vertex_count, label: self.class)
      @_stroke_cc = nil
    end

    # Set opacity. Accepts a single value (applied to all vertices) or an
    # array of per-vertex values (length must equal vertex_count).
    def opacity=(value)
      if value.is_a?(Array)
        n = vertex_count
        raise ArgumentError,
              "opacity array must have #{n} values, one for each vertex. #{value.length} were given." \
              unless value.length == n
        # Clamp each entry to 0.0..1.0, matching the scalar path (Color#opacity=).
        # NaN can't be clamped (Float::NAN.clamp raises), so map it to 0.0 first.
        @_per_vertex_opacity = value.map do |v|
          f = v.to_f
          f = 0.0 if f.nan?
          f.clamp(0.0, 1.0)
        end
      else
        @_per_vertex_opacity = nil
        @color.opacity = value
      end
      @_stroke_cc = nil
    end

    # Get opacity. Returns the per-vertex array when set, otherwise the
    # uniform alpha from the first vertex color.
    #
    # The nil check is spelled out rather than written `@color&.opacity`: on the
    # right of an `||`, an ahead-of-time compiler mistypes the safe-navigation
    # form and yields NaN instead of nil when both sides are nil (see SPINEL.md).
    def opacity
      @_per_vertex_opacity || (@color.nil? ? nil : @color.opacity)
    end

    # Render a polyline without creating an instance
    def self.render(points:, rotate: 0, rx: nil, ry: nil,
                    color: nil, colour: nil, opacity: nil,
                    stroke_width: 1, closed: false)
      Window.render_ready_check
      raise ArgumentError, 'Polyline requires at least 2 points' if points.length < 2

      n = points.length
      coords = Renderable.flatten_points(points)
      pvs = Renderable.flatten_color(color || colour, n, opacity, label: self)

      if rotate != 0
        ccx = 0.0; ccy = 0.0
        n.times do |i|
          ccx += coords[i * 2]
          ccy += coords[i * 2 + 1]
        end
        ccx /= n
        ccy /= n
        coords = rotate_coords(coords, rotate, rx || ccx, ry || ccy)
      end

      Ext.stroke_path(coords, stroke_width, pvs, closed) if stroke_width > 0
    end

    private

    # Build the stroke outline the renderer draws: the outer- and inner-edge
    # point for each vertex, with miter joins clamped to `MITER_LIMIT` and butt
    # caps at the open ends. A faithful port of `R2D_ComputeStrokeOutline`
    # (`ext/ruby2d/shapes.c`) — keep the two in sync. Returns `[outer, inner]`,
    # each an array of `[x, y]`. Used by `contains?` to hit-test the exact drawn
    # shape, including the mitered corner spikes a round-join disk would miss.
    def compute_stroke_outline
      n = vertex_count
      coords = @coordinates
      hw = @stroke_width / 2.0
      max_ml = MITER_LIMIT * hw
      outer = Array.new(n)
      inner = Array.new(n)

      n.times do |i|
        vx = coords[i * 2]
        vy = coords[i * 2 + 1]

        # Open-path endpoints get a butt cap: perpendicular of the lone edge.
        if !@closed && (i == 0 || i == n - 1)
          other = i == 0 ? 1 : n - 2
          dx = vx - coords[other * 2]
          dy = vy - coords[other * 2 + 1]
          if i == 0
            dx = -dx
            dy = -dy
          end
          len = Math.sqrt(dx * dx + dy * dy)
          if len < 0.0001
            outer[i] = [vx, vy]
            inner[i] = [vx, vy]
          else
            nx = -dy / len
            ny = dx / len
            outer[i] = [vx + nx * hw, vy + ny * hw]
            inner[i] = [vx - nx * hw, vy - ny * hw]
          end
          next
        end

        # Interior joint (every vertex when closed): miter.
        prev = (i - 1 + n) % n
        nxt = (i + 1) % n
        d1x = vx - coords[prev * 2]
        d1y = vy - coords[prev * 2 + 1]
        d2x = coords[nxt * 2] - vx
        d2y = coords[nxt * 2 + 1] - vy
        len1 = Math.sqrt(d1x * d1x + d1y * d1y)
        len2 = Math.sqrt(d2x * d2x + d2y * d2y)
        if len1 < 0.0001 || len2 < 0.0001
          outer[i] = [vx, vy]
          inner[i] = [vx, vy]
          next
        end
        d1x /= len1; d1y /= len1
        d2x /= len2; d2y /= len2
        n1x = -d1y; n1y = d1x
        n2x = -d2y; n2y = d2x
        mx = n1x + n2x
        my = n1y + n2y
        mlen = Math.sqrt(mx * mx + my * my)
        if mlen < 0.0001
          # 180° turn — degenerate; use the perpendicular of the first edge.
          outer[i] = [vx + n1x * hw, vy + n1y * hw]
          inner[i] = [vx - n1x * hw, vy - n1y * hw]
          next
        end
        mx /= mlen; my /= mlen
        dot = mx * n1x + my * n1y
        dot = 0.0001 if dot.abs < 0.0001
        ml = hw / dot
        ml = max_ml if ml > max_ml
        ml = -max_ml if ml < -max_ml
        outer[i] = [vx + mx * ml, vy + my * ml]
        inner[i] = [vx - mx * ml, vy - my * ml]
      end

      [outer, inner]
    end

    # Apply rotation to every (x, y) pair in a flat coords array, writing into
    # `out` (allocated fresh when nil) — the input is never mutated. The
    # instance render path passes a reused per-object buffer so a rotated
    # polyline doesn't allocate an N-element array every frame; the native draw
    # copies the values out synchronously, so reuse is safe.
    def self.rotate_coords(coords, angle, cx, cy, out = nil)
      rad = angle * Math::PI / 180.0
      sa = Math.sin(rad)
      ca = Math.cos(rad)
      n = coords.length / 2
      out ||= Array.new(coords.length)
      n.times do |i|
        dx = coords[i * 2]     - cx
        dy = coords[i * 2 + 1] - cy
        out[i * 2]     = dx * ca - dy * sa + cx
        out[i * 2 + 1] = dx * sa + dy * ca + cy
      end
      out
    end
    private_class_method :rotate_coords

    def render
      ensure_scc

      coords = @coordinates
      if @rotate != 0
        # Resolve the rotation center in a single vertex pass. Calling `rx` and
        # `ry` separately would average the coordinates twice (two N-loops) when
        # no user pivot is set; an explicit pivot skips the loop entirely.
        if !@_user_rx.nil? && !@_user_ry.nil?
          cx = @_user_rx
          cy = @_user_ry
        else
          sum_x = 0.0
          sum_y = 0.0
          n = vertex_count
          n.times do |i|
            sum_x += @coordinates[i * 2]
            sum_y += @coordinates[i * 2 + 1]
          end
          cx = @_user_rx.nil? ? sum_x / n : @_user_rx
          cy = @_user_ry.nil? ? sum_y / n : @_user_ry
        end
        if @_rot_coords.nil? || @_rot_coords.length != @coordinates.length
          @_rot_coords = Array.new(@coordinates.length)
        end
        coords = Polyline.send(:rotate_coords, @coordinates, @rotate, cx, cy, @_rot_coords)
      end

      Ext.stroke_path(coords, @stroke_width, @_stroke_cc, @closed) if @stroke_width && @stroke_width > 0
    end

    # Scene-graph draw hook (see Renderable#_render_scene). Polyline's `render`
    # is already zero-arg, so the hook is the same method under the scene name.
    alias_method :_render_scene, :render
    public :_render_scene

    # Build flat per-vertex stroke color cache (vertex_count × rgba floats).
    # Rebuilt only when the color's revision changes (see `Color#_rev`);
    # `color=` and `opacity=` clear the cache when they swap objects.
    def ensure_scc
      n = vertex_count
      rev = @color._rev
      return if @_stroke_cc && @_stroke_cc_rev == rev && @_stroke_cc.length == n * 4

      @_stroke_cc = Array.new(n * 4)
      n.times do |i|
        c = @color.vertex(i)
        @_stroke_cc[i * 4]     = c.r
        @_stroke_cc[i * 4 + 1] = c.g
        @_stroke_cc[i * 4 + 2] = c.b
        @_stroke_cc[i * 4 + 3] = @_per_vertex_opacity ? @_per_vertex_opacity[i] : c.a
      end
      @_stroke_cc_rev = rev
    end

  end
end
