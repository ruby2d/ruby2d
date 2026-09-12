# Ruby2D::Polyline

module Ruby2D
  # A connected sequence of line segments. Stroke-only (no fill).
  # Set `closed: true` to connect the last point back to the first.
  class Polyline
    include Renderable

    attr_accessor :rotate
    attr_reader :stroke_width, :closed

    # Miter-join limit, matching `R2D_MITER_LIMIT` in the C extension (the SVG
    # default). A corner whose miter tip would reach past
    # `MITER_LIMIT * stroke_width / 2` is cut off there.
    MITER_LIMIT = 4.0

    # Squared distance under which two consecutive points count as one, and
    # the |n1 + n2| below which a corner counts as a reversal, matching
    # `R2D_STROKE_EPS_SQ` and `R2D_STROKE_REVERSAL`.
    STROKE_EPS_SQ = 1e-8
    STROKE_REVERSAL = 0.001

    # One vertex of the stroke as `stroke_vertices` lays it out: the corner
    # points of the edges meeting there (`sp`/`sn` start the outgoing edge on
    # the +normal and -normal sides, `ep`/`en` end the incoming edge) and the
    # wedge points fanned from the vertex when the corner keeps plain ends.
    class StrokeVertex
      attr_accessor :x, :y, :sp, :sn, :ep, :en, :wedge, :t, :reach, :s_in, :ribbon

      def initialize(x, y)
        @x = x
        @y = y
        @wedge = []
        @t = 0.0
        @reach = 0.0
        @s_in = 0
        @ribbon = false
      end
    end
    private_constant :StrokeVertex, :STROKE_EPS_SQ, :STROKE_REVERSAL

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

    # Bounding-box left and top (the least vertex x and y)
    def _bounding_box_left
      @coordinates.each_slice(2).map(&:first).min
    end

    def _bounding_box_top
      @coordinates.each_slice(2).map(&:last).min
    end

    # Test whether (x, y) lies on the polyline's stroke. Hit-tests against the
    # exact shape the renderer draws — a quad per edge, mitered at the corners
    # and butt-capped at the open ends, plus the wedge at a corner too sharp
    # or too short for its miter — so the clickable region matches the visible
    # pixels, corners and all. A closed path joins at every vertex. The layout
    # is cached until the path changes, and a point outside its bounds is
    # rejected before any piece is tested: this runs on every mouse move.
    def contains?(x, y)
      return false unless @stroke_width && @stroke_width > 0
      x, y = _unrotate(x, y) if @rotate != 0
      sv, closed, bounds = stroke_layout
      m = sv.length
      return false if m < 2
      return false if x < bounds[0] || y < bounds[1] || x > bounds[2] || y > bounds[3]

      edges = closed ? m : m - 1
      edges.times do |k|
        a = sv[k]
        b = sv[(k + 1) % m]
        # The edge's quad, then the wedge at its end vertex, as
        # `R2D_StrokeEdgeTriangles` emits them; every piece is convex.
        return true if _point_in_polygon?(
          [a.sp[0], a.sp[1], a.sn[0], a.sn[1], b.en[0], b.en[1], b.ep[0], b.ep[1]], x, y
        )
        next if b.wedge.empty?

        poly = [b.x, b.y]
        b.wedge.each { |p| poly << p[0] << p[1] }
        return true if _point_in_polygon?(poly, x, y)
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

    # Stroke thickness and closure feed the cached stroke layout, so setting
    # either drops it (the vertex translators below do the same).
    def stroke_width=(value)
      @stroke_width = value
      @_stroke_layout = nil
    end

    def closed=(value)
      @closed = value
      @_stroke_layout = nil
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
      @_stroke_layout = nil
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
      @_stroke_layout = nil
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

    # Get opacity. Returns a copy of the per-vertex array when set (assign a
    # new array through `opacity=` to change it; the renderer only sees values
    # that went through the setter), otherwise the uniform alpha from the first
    # vertex color.
    def opacity
      @_per_vertex_opacity ? @_per_vertex_opacity.dup : @color&.opacity
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

    # Unit direction and length from vertex `a` to vertex `b`.
    def edge_dir(a, b)
      ex = b.x - a.x
      ey = b.y - a.y
      len = Math.sqrt(ex * ex + ey * ey)
      [ex / len, ey / len, len]
    end

    # The stroke layout plus its bounding box `[min_x, min_y, max_x, max_y]`
    # over every piece, built once and kept until the path, width, or closure
    # changes.
    def stroke_layout
      return @_stroke_layout if @_stroke_layout

      sv, closed = stroke_vertices
      min_x = min_y = Float::INFINITY
      max_x = max_y = -Float::INFINITY
      sv.each do |v|
        pts = [v.sp, v.sn, v.ep, v.en, [v.x, v.y]]
        pts.concat(v.wedge)
        pts.each do |px, py|
          next if px.nil?

          min_x = px if px < min_x
          min_y = py if py < min_y
          max_x = px if px > max_x
          max_y = py if py > max_y
        end
      end
      @_stroke_layout = [sv, closed, [min_x, min_y, max_x, max_y]]
    end

    # Lay out the stroke the renderer draws: a faithful port of
    # `R2D_StrokeVertices` (`ext/ruby2d/shapes.c`), which explains the
    # geometry — keep the two in sync. Consecutive repeated points collapse
    # into one. Returns `[vertices, closed]`, `closed` cleared when the path
    # collapses to a single edge. Used by `contains?` to hit-test the exact
    # drawn shape, including the mitered corners a round-join disk would miss.
    def stroke_vertices
      coords = @coordinates
      closed = @closed
      sv = []
      vertex_count.times do |i|
        px = coords[i * 2]
        py = coords[i * 2 + 1]
        unless sv.empty?
          ex = px - sv[-1].x
          ey = py - sv[-1].y
          next if ex * ex + ey * ey < STROKE_EPS_SQ
        end
        sv << StrokeVertex.new(px, py)
      end
      if closed
        while sv.length > 1
          ex = sv[-1].x - sv[0].x
          ey = sv[-1].y - sv[0].y
          break if ex * ex + ey * ey >= STROKE_EPS_SQ

          sv.pop
        end
      end
      m = sv.length
      return [sv, closed] if m < 2 || !(@stroke_width > 0)

      closed = false if m == 2
      hw = @stroke_width / 2.0
      max_ml = MITER_LIMIT * hw

      # Pass 1: at each corner, how far the miter reaches back along both
      # edges, how far the rectangle corners reach past the vertex, which side
      # the path bends toward, and whether the miter is within the limit and
      # fits both edges. |n1 + n2| is twice the cosine of the half turn; below
      # the threshold the corner counts as a reversal.
      m.times do |k|
        next if !closed && (k == 0 || k == m - 1)

        v = sv[k]
        d1x, d1y, len1 = edge_dir(sv[(k + m - 1) % m], v)
        d2x, d2y, len2 = edge_dir(v, sv[(k + 1) % m])
        mx = -d1y - d2y
        my = d1x + d2x
        mlen = Math.sqrt(mx * mx + my * my)
        next if mlen < STROKE_REVERSAL

        dot = 0.5 * mlen
        ml = hw / dot
        turn = d1x * d2y - d1y * d2x
        v.t = ml * Math.sqrt([0.0, 1.0 - dot * dot].max)
        v.reach = hw * turn.abs
        v.s_in = turn > 0 ? 1 : (turn < 0 ? -1 : 0)
        v.ribbon = ml <= max_ml && v.t <= len1 && v.t <= len2
      end

      # Pass 2: an edge whose two inner points, on the same side, reach past
      # each other keeps plain ends at both corners.
      edges = closed ? m : m - 1
      edges.times do |k|
        a = sv[k]
        b = sv[(k + 1) % m]
        next unless a.ribbon && b.ribbon && a.s_in != 0 && a.s_in == b.s_in

        len = edge_dir(a, b)[2]
        if a.t + b.t > len
          a.ribbon = false
          b.ribbon = false
        end
      end

      # Pass 2, continued: the ribbon cut hands the inner corner of each
      # rectangle's end to the neighboring edge, whose rectangle has to reach
      # `reach` past the vertex to cover it, less the miter of a same-side
      # ribbon at its far corner. Every corner is judged against the flags as
      # they stood before this pass.
      demoted = []
      m.times do |k|
        v = sv[k]
        next if !v.ribbon || v.s_in == 0

        p = sv[(k + m - 1) % m]
        n = sv[(k + 1) % m]
        len1 = edge_dir(p, v)[2]
        len2 = edge_dir(v, n)[2]
        len1 -= p.t if p.ribbon && p.s_in == v.s_in
        len2 -= n.t if n.ribbon && n.s_in == v.s_in
        demoted << v if v.reach > len1 || v.reach > len2
      end
      demoted.each { |v| v.ribbon = false }

      # Pass 3: the corner points, and the wedge at each plain corner
      m.times do |k|
        v = sv[k]
        d1x = d1y = d2x = d2y = 0.0
        d1x, d1y, = edge_dir(sv[(k + m - 1) % m], v) if closed || k > 0
        d2x, d2y, = edge_dir(v, sv[(k + 1) % m]) if closed || k < m - 1
        n1x = -d1y
        n1y = d1x
        n2x = -d2y
        n2y = d2x

        if v.ribbon
          mx = n1x + n2x
          my = n1y + n2y
          mlen = Math.sqrt(mx * mx + my * my)
          ml = 2.0 * hw / mlen
          mx /= mlen
          my /= mlen
          v.sp = v.ep = [v.x + mx * ml, v.y + my * ml]
          v.sn = v.en = [v.x - mx * ml, v.y - my * ml]
          next
        end

        v.sp = [v.x + n2x * hw, v.y + n2y * hw]
        v.sn = [v.x - n2x * hw, v.y - n2y * hw]
        v.ep = [v.x + n1x * hw, v.y + n1y * hw]
        v.en = [v.x - n1x * hw, v.y - n1y * hw]
        next if v.s_in == 0

        so = -v.s_in
        mx = n1x + n2x
        my = n1y + n2y
        mlen = Math.sqrt(mx * mx + my * my)
        dot = 0.5 * mlen
        ml = hw / dot
        mox = so * mx / mlen
        moy = so * my / mlen
        c1 = [v.x + so * n1x * hw, v.y + so * n1y * hw]
        c2 = [v.x + so * n2x * hw, v.y + so * n2y * hw]
        if ml <= max_ml
          v.wedge = [c1, [v.x + mox * ml, v.y + moy * ml], c2]
        else
          reach = max_ml - hw * dot
          u = reach / (d1x * mox + d1y * moy)
          w = reach / (d2x * mox + d2y * moy)
          v.wedge = [c1, [c1[0] + d1x * u, c1[1] + d1y * u],
                     [c2[0] + d2x * w, c2[1] + d2y * w], c2]
        end
      end

      [sv, closed]
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
