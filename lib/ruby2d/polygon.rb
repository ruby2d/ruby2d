# Ruby2D::Polygon

module Ruby2D
  # A closed polygon defined by N vertices (N >= 3), filled or stroked.
  class Polygon
    include Renderable

    attr_accessor :rotate, :fill, :stroke_width
    attr_reader :stroke_color
    alias_method :stroke_colour, :stroke_color

    # Create a polygon
    # points is an array of [x, y] pairs with N >= 3 vertices
    def initialize(points:, z: 0, rotate: 0, rx: nil, ry: nil,
                   color: nil, colour: nil, opacity: nil,
                   fill: true, stroke_width: 0, stroke_color: nil, stroke_colour: nil,
                   add: true, visible: true)
      raise ArgumentError, 'Polygon requires at least 3 points' if points.length < 3
      raise ArgumentError, 'points must be an array of [x, y] pairs' \
        unless points.all? { |p| p.is_a?(Array) && p.length == 2 }

      @coordinates = points.flat_map { |x, y| [x.to_f, y.to_f] }
      @z = z
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

    # Test whether (x, y) lies inside the polygon, using the even-odd ray-cast
    # rule (shared by every filled polygonal shape — see `_point_in_polygon?`).
    # Matches the rendered fill for non-self-intersecting polygons (convex and
    # concave); self-intersecting input isn't fully supported by the renderer, so
    # the test can diverge from the drawn pixels there.
    def contains?(x, y)
      x, y = _unrotate(x, y)
      _point_in_polygon?(@coordinates, x, y)
    end

    # Centroid x (average of vertex x coordinates)
    def x
      sum = 0.0
      n = vertex_count
      n.times { |i| sum += @coordinates[i * 2] }
      sum / n
    end

    # Centroid y (average of vertex y coordinates)
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

    # Set the fill color (single or per-vertex array).
    # Per-vertex array length must match vertex_count.
    def color=(color)
      cs = Color.set(color)
      if cs.is_a?(Color::Set) && cs.length != vertex_count
        raise ArgumentError,
              "`#{self.class}` requires #{vertex_count} colors, one for each vertex. #{cs.length} were given."
      end
      @color = cs
      @_cc = nil
    end

    # Set the stroke color. Accepts a single color or a `Color::Set` of
    # vertex_count colors (one per vertex) interpolated around the perimeter.
    def stroke_color=(c)
      @stroke_color = Renderable.resolve_color_or_default(c, vertex_count, label: self.class)
      @_stroke_cc = nil
    end
    alias_method :stroke_colour=, :stroke_color=

    # Render a polygon without creating an instance
    def self.render(points:, rotate: 0, rx: nil, ry: nil,
                    color: nil, colour: nil, opacity: nil,
                    fill: true, stroke_width: 0, stroke_color: nil, stroke_colour: nil)
      Window.render_ready_check
      raise ArgumentError, 'Polygon requires at least 3 points' if points.length < 3

      n = points.length
      coords = Renderable.flatten_points(points)
      fill_input = color || colour
      pvc = Renderable.flatten_color(fill_input, n, opacity, label: self)

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

      Ext.draw_polygon(coords, pvc) if fill
      # Flatten the stroke colors only when actually stroking; an explicitly
      # given stroke color is still validated at stroke_width 0 to match the
      # instance constructor.
      if stroke_width > 0
        pvs = Renderable.flatten_color(stroke_color || stroke_colour || fill_input, n, opacity, label: self)
        Ext.stroke_path(coords, stroke_width, pvs, true)
      elsif stroke_color || stroke_colour
        Renderable.flatten_color(stroke_color || stroke_colour, n, opacity, label: self)
      end
    end

    private

    # Apply rotation to every (x, y) pair in a flat coords array, writing into
    # `out` (allocated fresh when nil) — the input is never mutated. The
    # instance render path passes a reused per-object buffer so a rotated
    # polygon doesn't allocate an N-element array every frame; the native draw
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
      ensure_cc
      ensure_scc if @stroke_width && @stroke_width > 0

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
        coords = Polygon.send(:rotate_coords, @coordinates, @rotate, cx, cy, @_rot_coords)
      end

      Ext.draw_polygon(coords, @_cc)              if @fill
      Ext.stroke_path(coords, @stroke_width, @_stroke_cc, true) if @stroke_width && @stroke_width > 0
    end

    # Scene-graph draw hook (see Renderable#_render_scene). Polygon's `render` is
    # already zero-arg, so the hook is the same method under the scene name.
    alias_method :_render_scene, :render
    public :_render_scene

    # Flatten @color into per-vertex RGBA array. If @color is a Color::Set, use
    # each entry; otherwise replicate across all vertices.
    def ensure_cc
      n = vertex_count
      if @_cc.nil? || @_cc.length != n * 4 || !cc_matches?
        @_cc = Array.new(n * 4)
        n.times do |i|
          c = @color.vertex(i)
          @_cc[i * 4]     = c.r
          @_cc[i * 4 + 1] = c.g
          @_cc[i * 4 + 2] = c.b
          @_cc[i * 4 + 3] = c.a
        end
      end
    end

    def cc_matches?
      n = vertex_count
      n.times do |i|
        c = @color.vertex(i)
        return false if @_cc[i * 4]     != c.r
        return false if @_cc[i * 4 + 1] != c.g
        return false if @_cc[i * 4 + 2] != c.b
        return false if @_cc[i * 4 + 3] != c.a
      end
      true
    end

    # Build flat per-vertex stroke color cache (vertex_count × rgba floats)
    def ensure_scc
      n = vertex_count
      if @_stroke_cc.nil? || @_stroke_cc.length != n * 4 || !scc_matches?
        @_stroke_cc = Array.new(n * 4)
        n.times do |i|
          c = @stroke_color.vertex(i)
          @_stroke_cc[i * 4]     = c.r
          @_stroke_cc[i * 4 + 1] = c.g
          @_stroke_cc[i * 4 + 2] = c.b
          @_stroke_cc[i * 4 + 3] = c.a
        end
      end
    end

    def scc_matches?
      n = vertex_count
      n.times do |i|
        c = @stroke_color.vertex(i)
        return false if @_stroke_cc[i * 4]     != c.r
        return false if @_stroke_cc[i * 4 + 1] != c.g
        return false if @_stroke_cc[i * 4 + 2] != c.b
        return false if @_stroke_cc[i * 4 + 3] != c.a
      end
      true
    end
  end
end
