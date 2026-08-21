# Ruby2D::Canvas

module Ruby2D
  class Canvas
    include Renderable
    include TextureScaling

    # Canvas uses `tint` instead of `color` — the canvas has its own pixel
    # buffer; tint modulates the texture when drawn (white = untinted) and
    # also acts as the default color for `canvas.fill_*` / `stroke_*` /
    # `draw_*` methods when none is passed.
    undef_method :color, :color=, :colour, :colour=

    attr_accessor :width, :height, :rotate
    attr_reader :x, :y, :fill

    # Create a canvas with the given dimensions
    def initialize(width:, height:, x: 0, y: 0, z: 0, rotate: 0,
                   fill: [0, 0, 0, 0], tint: nil, opacity: nil,
                   add: true, visible: true, scale_mode: nil)
      self.scale_mode = scale_mode
      self.x = x
      self.y = y
      @z = z
      @width = width
      @height = height
      @rotate = rotate
      @_user_rx = nil
      @_user_ry = nil
      @fill = Color.new(fill)
      self.tint = tint || 'white'
      self.opacity = opacity unless opacity.nil?

      @fill_r = @fill.r
      @fill_g = @fill.g
      @fill_b = @fill.b
      @fill_a = @fill.a

      # The surface is sized once, here. Before `show` the extension's asset
      # scale doesn't yet reflect `pixel_scale` (it's applied when the window
      # opens), so tell it when the canvas should be built at logical
      # resolution; otherwise a canvas created pre-show — the usual case —
      # would be built at full display resolution regardless of the setting.
      logical = !Window.shown? && Window.pixel_scale && Window.highdpi
      Ext.canvas_create(self, logical)
      @visible = visible
      self.add if add
    end

    # The canvas's tint color. The canvas's own pixel buffer is multiplied by
    # this — `tint: 'red'` makes the canvas redder, not solid red.
    def tint
      @tint
    end

    def tint=(c)
      @tint = Color.new(c)
    end

    # Get the tint's opacity. Canvas overrides `Renderable#opacity` because its
    # modulating color is `@tint`, not `@color`.
    def opacity
      @tint&.opacity
    end

    def opacity=(value)
      @tint.opacity = value
    end

    # Set the x position. The canvas draws its pixel buffer at (x, y) and has no
    # symbolic alignment, so x must be a number — see Aligning to the window in
    # USAGE.md.
    def x=(value)
      @x = _require_numeric_position(:x, value)
    end

    # Set the y position (numeric only — see `x=`).
    def y=(value)
      @y = _require_numeric_position(:y, value)
    end

    # Get the rotation center x coordinate
    def rx
      @_user_rx.nil? ? @x + @width / 2.0 : @_user_rx
    end

    # Get the rotation center y coordinate
    def ry
      @_user_ry.nil? ? @y + @height / 2.0 : @_user_ry
    end

    # Set the rotation center x coordinate
    def rx=(val)
      @_user_rx = val
    end

    # Set the rotation center y coordinate
    def ry=(val)
      @_user_ry = val
    end

    # Fill a triangle. Specify vertices via `points:` or via numbered kwargs.
    def fill_triangle(x1: nil, y1: nil, x2: nil, y2: nil, x3: nil, y3: nil,
                      points: nil, color: nil, colour: nil, opacity: nil)
      if points
        validate_points(points, 3, :fill_triangle)
        x1, y1 = points[0]
        x2, y2 = points[1]
        x3, y3 = points[2]
      end
      return unless validate_vertex6(:fill_triangle, x1, y1, x2, y2, x3, y3)
      opacity = clamp_opacity(opacity) if opacity
      c = resolve_color_or_set(color || colour)
      # A single flat color reads its channels straight into the C call; only
      # a `Color::Set` or per-vertex opacity array builds the tuple array.
      if c.is_a?(Color::Set) || opacity.is_a?(Array)
        colors = per_vertex_fill_tuples(c, opacity, 3, :fill_triangle)
        Ext.canvas_fill_triangle_lerp(self,
          [x1, y1, *colors[0], x2, y2, *colors[1], x3, y3, *colors[2]])
      else
        Ext.canvas_fill_triangle(self, x1, y1, x2, y2, x3, y3,
                                 c.r, c.g, c.b, opacity || c.a)
      end
    end

    # Fill a quadrilateral. Specify vertices via `points:` or via numbered kwargs.
    def fill_quad(x1: nil, y1: nil, x2: nil, y2: nil, x3: nil, y3: nil, x4: nil, y4: nil,
                  points: nil, color: nil, colour: nil, opacity: nil)
      if points
        validate_points(points, 4, :fill_quad)
        x1, y1 = points[0]
        x2, y2 = points[1]
        x3, y3 = points[2]
        x4, y4 = points[3]
      end
      return unless validate_vertex8(:fill_quad, x1, y1, x2, y2, x3, y3, x4, y4)
      opacity = clamp_opacity(opacity) if opacity
      c = resolve_color_or_set(color || colour)
      if c.is_a?(Color::Set) || opacity.is_a?(Array)
        colors = per_vertex_fill_tuples(c, opacity, 4, :fill_quad)
        # Split into triangles (0,1,2) and (0,2,3), each carrying its vertices'
        # colors so the per-vertex gradient interpolates across the quad.
        Ext.canvas_fill_triangle_lerp(self,
          [x1, y1, *colors[0], x2, y2, *colors[1], x3, y3, *colors[2]])
        Ext.canvas_fill_triangle_lerp(self,
          [x1, y1, *colors[0], x3, y3, *colors[2], x4, y4, *colors[3]])
      else
        a = opacity || c.a
        Ext.canvas_fill_triangle(self, x1, y1, x2, y2, x3, y3, c.r, c.g, c.b, a)
        Ext.canvas_fill_triangle(self, x1, y1, x3, y3, x4, y4, c.r, c.g, c.b, a)
      end
    end

    # Fill a rectangle at position (x,y) with the given width and height
    def fill_rectangle(x:, y:, width:, height:, color: nil, colour: nil, opacity: nil)
      return unless validate4(:fill_rectangle, x, y, width, height)
      opacity = clamp_opacity(opacity) if opacity
      c = resolve_color_or_set(color || colour)
      # Per-vertex (corner) coloring or opacity needs the quad path; a single
      # flat color uses the dedicated rectangle rasterizer.
      if c.is_a?(Color::Set) || opacity.is_a?(Array)
        fill_quad(
          x1: x, y1: y, x2: x + width, y2: y,
          x3: x + width, y3: y + height, x4: x, y4: y + height,
          color: c, opacity: opacity
        )
      else
        # `c` is already a drawable Color (or the canvas tint) from
        # resolve_color_or_set; read it directly instead of allocating a second
        # Color via resolve_draw_color.
        Ext.canvas_fill_rectangle(self, x, y, width, height, c.r, c.g, c.b, opacity || c.a)
      end
    end

    # Fill many rectangles with a single shared color in one call.
    # rectangles is an array of `[x, y, width, height]` tuples.
    def fill_rectangles(rectangles:, color: nil, colour: nil, opacity: nil)
      return if rectangles.empty?
      if opacity.is_a?(Array)
        raise ArgumentError, 'fill_rectangles uses a single shared color and does not support a per-vertex opacity array'
      end
      opacity = clamp_opacity(opacity) if opacity

      # One fused validate-and-build pass (`while`, not blocks — this runs per
      # draw call on N tuples, and block calls dominate on wasm mruby). A
      # malformed tuple or non-Numeric coordinate is a programming mistake —
      # raise, as the vertex-based methods do. A rect carrying a non-finite
      # (NaN/Inf) coordinate or size is instead dropped rather than forwarded
      # to C; the finite-only payload keeps the draw a clean no-op for the bad
      # rects while still drawing the good ones.
      payload = [0]
      count = 0
      i = 0
      size = rectangles.size
      while i < size
        r = rectangles[i]
        unless r.is_a?(Array) && r.length == 4
          raise ArgumentError, 'rectangles must be an array of [x, y, width, height] tuples'
        end
        x = r[0]
        y = r[1]
        w = r[2]
        h = r[3]
        unless x.is_a?(Numeric) && y.is_a?(Numeric) && w.is_a?(Numeric) && h.is_a?(Numeric)
          raise ArgumentError, 'fill_rectangles: every coordinate must be a number'
        end
        if finite4?(x, y, w, h)
          count += 1
          payload.push(x, y, w, h)
        end
        i += 1
      end
      return if count.zero?

      payload[0] = count
      c = resolve_draw_color(color || colour)
      payload.push(c.r, c.g, c.b, opacity || c.a)
      Ext.canvas_fill_rectangles(self, payload)
    end

    # Fill a regular grid of equal-size rectangles, each with its own color,
    # in one call. The cell at column c, row r covers
    # `(x + c*cell_w, y + r*cell_h, cell_w, cell_h)` and is colored by
    # `colors[(r*cols + c)*4 .. +3]`. `colors` is a flat array of
    # `cols*rows*4` floats in 0..1: `r0, g0, b0, a0, r1, g1, b1, a1, ...`.
    # Cells with alpha 0 are skipped. Designed for grid renderings
    # (fluid sims, heatmaps, tile fields) where per-rect FFI overhead
    # dominates over the actual pixel work.
    def fill_pixel_grid(cols:, rows:, cell_w:, cell_h:, colors:, x: 0, y: 0)
      return if cols < 1 || rows < 1
      return unless validate4(:fill_pixel_grid, cell_w, cell_h, x, y)
      expected = cols * rows * 4
      unless colors.length == expected
        raise ArgumentError,
              "colors must have #{expected} elements (cols*rows*4), got #{colors.length}"
      end
      Ext.canvas_fill_pixel_grid(self, [cols, rows, cell_w, cell_h, x, y], colors)
    end

    # Fill a square at position (x,y) with the given size
    def fill_square(x:, y:, size:, color: nil, colour: nil, opacity: nil)
      fill_rectangle(x: x, y: y, width: size, height: size, color: color, colour: colour, opacity: opacity)
    end

    # Fill a circle centered at (x,y) with the given radius
    def fill_circle(x:, y:, radius:, color: nil, colour: nil, opacity: nil)
      fill_ellipse(x: x, y: y, xradius: radius, yradius: radius, color: color, colour: colour, opacity: opacity)
    end

    # Fill an ellipse centered at (x,y) with the given x and y radii
    def fill_ellipse(x:, y:, xradius:, yradius:, color: nil, colour: nil, opacity: nil)
      if opacity.is_a?(Array)
        raise ArgumentError, 'fill_ellipse/fill_circle is rasterized, not vertex-based, so it does not support a per-vertex opacity array'
      end
      return unless validate4(:fill_ellipse, x, y, xradius, yradius)
      opacity = clamp_opacity(opacity) if opacity
      c = resolve_draw_color(color || colour)
      Ext.canvas_fill_ellipse(self, x, y, xradius, yradius, c.r, c.g, c.b, opacity || c.a)
    end

    # Fill a polygon defined by an array of [x, y] pairs.
    # Concave polygons fill correctly: triangulation happens in C via
    # ear clipping (R2D_TriangulatePolygon), shared with Polygon.new.
    def fill_polygon(points:, color: nil, colour: nil, opacity: nil)
      validate_point_pairs(points)
      n = points.length
      return if n < 3
      return unless validate_pair_coords(points, :fill_polygon)

      opacity = clamp_opacity(opacity) if opacity
      c = resolve_color_or_set(color || colour)
      # `while` loops, not blocks — this is a per-draw-call path over N points
      # and block calls dominate on wasm mruby.
      if c.is_a?(Color::Set) || opacity.is_a?(Array)
        colors = per_vertex_fill_tuples(c, opacity, n, :fill_polygon)
        payload = [n]
        i = 0
        while i < n
          p = points[i]
          col = colors[i]
          payload.push(p[0], p[1], col[0], col[1], col[2], col[3])
          i += 1
        end
        Ext.canvas_fill_polygon_lerp(self, payload)
      else
        payload = [n]
        i = 0
        while i < n
          p = points[i]
          payload.push(p[0], p[1])
          i += 1
        end
        payload.push(c.r, c.g, c.b, opacity || c.a)
        Ext.canvas_fill_polygon(self, payload)
      end
    end

    # Stroke a triangle outline. Specify vertices via `points:` or via numbered
    # kwargs. `color:` accepts a single color or a `Color::Set` of 3 (one per
    # vertex) interpolated around the perimeter.
    def stroke_triangle(x1: nil, y1: nil, x2: nil, y2: nil, x3: nil, y3: nil,
                        points: nil, stroke_width: 1, color: nil, colour: nil, opacity: nil)
      if points
        validate_points(points, 3, :stroke_triangle)
        x1, y1 = points[0]
        x2, y2 = points[1]
        x3, y3 = points[2]
      end
      return unless validate_vertex6(:stroke_triangle, x1, y1, x2, y2, x3, y3)
      colors = expand_stroke_colors(color || colour, 3, opacity, label: :stroke_triangle)
      Ext.canvas_stroke_polygon(self, [3, x1, y1, x2, y2, x3, y3, stroke_width, *colors])
    end

    # Stroke a quadrilateral outline. Specify vertices via `points:` or via
    # numbered kwargs. `color:` accepts a single color or a `Color::Set` of 4
    # (one per vertex) interpolated around the perimeter.
    def stroke_quad(x1: nil, y1: nil, x2: nil, y2: nil, x3: nil, y3: nil, x4: nil, y4: nil,
                    points: nil, stroke_width: 1, color: nil, colour: nil, opacity: nil)
      if points
        validate_points(points, 4, :stroke_quad)
        x1, y1 = points[0]
        x2, y2 = points[1]
        x3, y3 = points[2]
        x4, y4 = points[3]
      end
      return unless validate_vertex8(:stroke_quad, x1, y1, x2, y2, x3, y3, x4, y4)
      colors = expand_stroke_colors(color || colour, 4, opacity, label: :stroke_quad)
      Ext.canvas_stroke_polygon(self, [4, x1, y1, x2, y2, x3, y3, x4, y4, stroke_width, *colors])
    end

    # Stroke a rectangle outline at position (x,y) with the given width and height
    def stroke_rectangle(x:, y:, width:, height:, stroke_width: 1, color: nil, colour: nil, opacity: nil)
      stroke_quad(
        x1: x, y1: y, x2: x + width, y2: y,
        x3: x + width, y3: y + height, x4: x, y4: y + height,
        stroke_width: stroke_width, color: color, colour: colour, opacity: opacity
      )
    end

    # Stroke a square outline at position (x,y) with the given size
    def stroke_square(x:, y:, size:, stroke_width: 1, color: nil, colour: nil, opacity: nil)
      stroke_rectangle(x: x, y: y, width: size, height: size, stroke_width: stroke_width, color: color, colour: colour, opacity: opacity)
    end

    # Stroke a circle outline centered at (x,y) with the given radius.
    # Single color only — sectors have no natural vertex identity.
    def stroke_circle(x:, y:, radius:, sectors: 30, stroke_width: 1, color: nil, colour: nil, opacity: nil)
      stroke_ellipse(x: x, y: y, xradius: radius, yradius: radius, sectors: sectors,
                     stroke_width: stroke_width, color: color, colour: colour, opacity: opacity)
    end

    # Stroke an ellipse outline centered at (x,y) with the given x and y radii.
    # Single color only — sectors have no natural vertex identity.
    def stroke_ellipse(x:, y:, xradius:, yradius:, sectors: 30, stroke_width: 1, color: nil, colour: nil, opacity: nil)
      c = resolve_draw_color(color || colour)
      a = (clamp_opacity(opacity) if opacity) || c.a
      verts = []
      colors = []
      sectors.times do |i|
        angle = 2.0 * Math::PI * i / sectors
        verts << x + xradius * Math.cos(angle)
        verts << y + yradius * Math.sin(angle)
        colors << c.r << c.g << c.b << a
      end
      Ext.canvas_stroke_polygon(self, [sectors, *verts, stroke_width, *colors])
    end

    # Draw a line. Specify endpoints via `points:` or via numbered kwargs.
    # Pass `dash:` (and optionally `gap:`) to draw a dashed line. `color:`
    # accepts a single color or a `Color::Set` of 2 (start, end) for a
    # gradient along the length.
    def draw_line(x1: nil, y1: nil, x2: nil, y2: nil,
                  points: nil, stroke_width: 1, dash: 0, gap: 5,
                  color: nil, colour: nil, opacity: nil)
      if points
        validate_points(points, 2, :draw_line)
        x1, y1 = points[0]
        x2, y2 = points[1]
      end
      return unless validate_vertex4(:draw_line, x1, y1, x2, y2)
      opacity = clamp_opacity(opacity) if opacity
      c = resolve_color_or_set(color || colour)
      if c.is_a?(Color::Set)
        raise ArgumentError, 'Color::Set for draw_line must have 2 colors (start, end)' unless c.length == 2
        Ext.canvas_draw_line_lerp(self, [
          x1, y1, x2, y2, stroke_width,
          c[0].r, c[0].g, c[0].b, opacity || c[0].a,
          c[0].r, c[0].g, c[0].b, opacity || c[0].a,
          c[1].r, c[1].g, c[1].b, opacity || c[1].a,
          c[1].r, c[1].g, c[1].b, opacity || c[1].a,
          dash, gap
        ])
      else
        # `c` is already a drawable Color (or the canvas tint); read it directly
        # instead of allocating a second Color via resolve_draw_color.
        Ext.canvas_draw_line(self, x1, y1, x2, y2, stroke_width, c.r, c.g, c.b, opacity || c.a, dash, gap)
      end
    end

    # Draw many line segments with a single shared color and stroke width in one call.
    # segments is an array of `[[x, y], [x, y]]` endpoint pairs.
    def draw_lines(segments:, stroke_width: 1, color: nil, colour: nil, opacity: nil)
      return if segments.empty?

      n = segments.length
      # Fused validate-and-build pass (`while`, not blocks) — per draw call
      # over N segments; see fill_rectangles.
      payload = [n]
      i = 0
      while i < n
        s = segments[i]
        unless s.is_a?(Array) && s.length == 2
          raise ArgumentError, 'segments must be an array of [[x, y], [x, y]] endpoint pairs'
        end
        a = s[0]
        b = s[1]
        unless a.is_a?(Array) && a.length == 2 && b.is_a?(Array) && b.length == 2
          raise ArgumentError, 'segments must be an array of [[x, y], [x, y]] endpoint pairs'
        end
        payload.push(a[0], a[1], b[0], b[1])
        i += 1
      end
      opacity = clamp_opacity(opacity) if opacity
      c = resolve_draw_color(color || colour)
      payload.push(stroke_width, c.r, c.g, c.b, opacity || c.a)
      Ext.canvas_draw_lines(self, payload)
    end

    # Draw a polyline from an array of [x, y] pairs.
    # Set `closed: true` to connect the last point back to the first.
    # `color:` accepts a single color or a `Color::Set` of N (one per vertex)
    # interpolated along the path.
    def draw_polyline(points:, stroke_width: 1, color: nil, colour: nil, closed: false, opacity: nil)
      validate_point_pairs(points)
      n = points.length
      return if n < 2
      return unless validate_pair_coords(points, :draw_polyline)

      colors = expand_stroke_colors(color || colour, n, opacity, label: :draw_polyline)
      payload = [closed ? 1 : 0, n]
      i = 0
      while i < n
        p = points[i]
        payload.push(p[0], p[1])
        i += 1
      end
      payload.push(stroke_width)
      payload.concat(colors)
      Ext.canvas_stroke_polyline(self, payload)
    end

    # Draw an Image onto this canvas at the given position and size
    def draw_image(image, x: 0, y: 0, width: nil, height: nil)
      w = width || image.width
      h = height || image.height
      return unless validate4(:draw_image, x, y, w, h)
      Ext.canvas_draw_image(self, image, [x, y, w, h])
    end

    # Draw a Text onto this canvas at the given position and size, with optional color
    def draw_text(text, x: 0, y: 0, width: nil, height: nil, color: nil, colour: nil, opacity: nil)
      w = width || text.width
      h = height || text.height
      return unless validate4(:draw_text, x, y, w, h)
      opacity = clamp_opacity(opacity) if opacity
      c = resolve_draw_color(color || colour)
      Ext.canvas_draw_text(self, text, [x, y, w, h, c.r, c.g, c.b, opacity || c.a])
    end

    # Clear the canvas, resetting all pixels to the fill color (or the given
    # color). The color may be passed positionally or via `color:`/`colour:`,
    # matching the rest of the draw API. Optionally clear only a rectangular
    # region.
    def clear(fill_color = nil, color: nil, colour: nil, x: 0, y: 0, width: @width, height: @height)
      return unless validate4(:clear, x, y, width, height)
      input = fill_color || color || colour
      c = input ? Color.new(input) : @fill
      Ext.canvas_clear(self, [c.r, c.g, c.b, c.a, x, y, width, height])
    end

    # Render the canvas. Called with overrides for one-shot rendering inside a
    # render block; with no arguments it draws the same frame the scene graph
    # does (delegating to `_render_scene`). `width:`/`height:` scale the
    # displayed output — the underlying pixel buffer is fixed at construction.
    def render(x: nil, y: nil, width: nil, height: nil, rotate: nil,
               tint: nil, opacity: nil)
      if x.nil? && y.nil? && width.nil? && height.nil? && rotate.nil? &&
         tint.nil? && opacity.nil?
        return _render_scene
      end

      Window.render_ready_check

      # Plain assignments rather than `a, b = @a, @b`: a multiple assignment
      # from ivars emits invalid C under Spinel (see spinel/issues/53).
      saved_x = @x
      saved_y = @y
      saved_width = @width
      saved_height = @height
      saved_rotate = @rotate
      saved_tint = @tint

      @x = x if x
      @y = y if y
      @width = width if width
      @height = height if height
      @rotate = rotate if rotate

      if tint || opacity
        @tint = tint ? Color.new(tint) : Color.new(saved_tint)
        @tint.opacity = opacity if opacity
      end

      begin
        Ext.canvas_draw(self, rx, ry)
      ensure
        @x = saved_x
        @y = saved_y
        @width = saved_width
        @height = saved_height
        @rotate = saved_rotate
        @tint = saved_tint
      end
    end

    private

    # Scene-graph draw hook (see Renderable#_render_scene): `render` with no
    # overrides, minus its keyword handling — a zero-arg call into a
    # keyword-heavy `render` still pays microseconds of keyword setup on wasm
    # mruby.
    def _render_scene
      Ext.canvas_draw(self, rx, ry)
    end
    public :_render_scene

    def validate_points(points, expected, name)
      raise ArgumentError, "#{name} requires exactly #{expected} points" unless points.length == expected
      validate_point_pairs(points)
    end

    # Validate a variable-length list of `[x, y]` pairs (e.g. fill_polygon,
    # draw_polyline), which have no fixed point count. A `while` loop, not
    # `all?` — these validators run per draw call on N-element inputs, and on
    # wasm mruby every block invocation costs real time (see the batch draw
    # methods, whose lib-side cost was dominated by validation block calls).
    def validate_point_pairs(points)
      raise ArgumentError, 'points must be an array of [x, y] pairs' unless points.is_a?(Array)

      i = 0
      size = points.size
      while i < size
        p = points[i]
        raise ArgumentError, 'points must be an array of [x, y] pairs' unless p.is_a?(Array) && p.length == 2
        i += 1
      end
    end

    # Fused numeric + finiteness pass over `[x, y]` pairs: the pair-list
    # equivalent of the fixed-arity `validate_vertex*` checks without the
    # flattened copy or per-element blocks. Raises on a non-Numeric coordinate;
    # returns false (skip the draw) when any coordinate is non-finite.
    def validate_pair_coords(points, name)
      finite = true
      i = 0
      size = points.size
      while i < size
        p = points[i]
        x = p[0]
        y = p[1]
        unless x.is_a?(Numeric) && y.is_a?(Numeric)
          raise ArgumentError,
                "#{name}: every coordinate must be a number — pass all vertices via `points:` or the numbered kwargs"
        end
        finite = false unless finite_value?(x) && finite_value?(y)
        i += 1
      end
      finite
    end

    # Validate a vertex-method coordinate list before it crosses into the C
    # extension. Catches a missing numbered-kwarg vertex (left nil) or a
    # non-numeric coordinate, which would otherwise surface as a cryptic
    # "no implicit conversion to Float" from deep in the native call.
    #
    # Returns true when the draw should proceed. A genuine type error (a nil or
    # non-Numeric coordinate) still raises, since that signals a programming
    # mistake. A non-finite Numeric (NaN/Inf) instead returns false so the caller
    # skips the draw — animation-safe, matching the no-mid-run-raise philosophy
    # and the C rasterizer's isfinite no-op backstop.
    #
    # Fixed-arity variants, one per vertex-method width — a coords array
    # argument (or a `*coords` splat) would allocate on every draw call, and
    # each caller passes a fixed number of coordinates.
    def validate_vertex4(name, x1, y1, x2, y2)
      unless x1.is_a?(Numeric) && y1.is_a?(Numeric) &&
             x2.is_a?(Numeric) && y2.is_a?(Numeric)
        raise_vertex_type_error(name)
      end
      finite4?(x1, y1, x2, y2)
    end

    def validate_vertex6(name, x1, y1, x2, y2, x3, y3)
      unless x1.is_a?(Numeric) && y1.is_a?(Numeric) &&
             x2.is_a?(Numeric) && y2.is_a?(Numeric) &&
             x3.is_a?(Numeric) && y3.is_a?(Numeric)
        raise_vertex_type_error(name)
      end
      finite4?(x1, y1, x2, y2) && finite_value?(x3) && finite_value?(y3)
    end

    def validate_vertex8(name, x1, y1, x2, y2, x3, y3, x4, y4)
      unless x1.is_a?(Numeric) && y1.is_a?(Numeric) &&
             x2.is_a?(Numeric) && y2.is_a?(Numeric) &&
             x3.is_a?(Numeric) && y3.is_a?(Numeric) &&
             x4.is_a?(Numeric) && y4.is_a?(Numeric)
        raise_vertex_type_error(name)
      end
      finite4?(x1, y1, x2, y2) && finite4?(x3, y3, x4, y4)
    end

    def raise_vertex_type_error(name)
      raise ArgumentError,
            "#{name}: every coordinate must be a number — pass all vertices via `points:` or the numbered kwargs"
    end

    # True when the value is a finite Numeric — the single-value primitive the
    # validators above compose. A non-finite (NaN/Inf) coordinate or size skips
    # the draw rather than reaching the C rasterizer's integer casts (which the
    # isfinite backstop also guards).
    def finite_value?(v)
      # Float and Integer cover every real caller; `respond_to?` is expensive
      # on wasm mruby, so reserve that generic path for exotic Numerics.
      case v
      when Float then v.finite?
      when Integer then true
      when Numeric then v.respond_to?(:finite?) ? v.finite? : true
      else false
      end
    end

    # Fixed-arity finiteness check for the four-coordinate fill paths. A `*values`
    # signature would allocate a splat array on every fill; every caller here
    # passes exactly four values, so take them positionally instead.
    def finite4?(a, b, c, d)
      finite_value?(a) && finite_value?(b) && finite_value?(c) && finite_value?(d)
    end

    # Fixed-arity validate-and-finiteness for the four-value fill/draw paths,
    # mirroring `validate_vertex4` (minus its `points:` hint — these methods
    # take position/size values, not vertices): a non-Numeric value raises (a
    # programming mistake), while a non-finite Numeric (NaN/Inf) returns false
    # so the caller skips the draw (animation-safe).
    def validate4(name, a, b, c, d)
      unless a.is_a?(Numeric) && b.is_a?(Numeric) && c.is_a?(Numeric) && d.is_a?(Numeric)
        raise ArgumentError, "#{name}: every coordinate must be a number"
      end
      finite4?(a, b, c, d)
    end

    # Clamp an `opacity:` argument (a scalar, a per-vertex array, or nil) into
    # the valid 0.0..1.0 range. An out-of-range value would otherwise wrap the
    # Uint8 alpha cast in the C extension into a wrong, near-opaque byte. Silent
    # and animation-safe, matching `Color#opacity=`. nil passes through so the
    # color's own alpha is used.
    def clamp_opacity(opacity)
      case opacity
      when Numeric then opacity.clamp(0.0, 1.0)
      when Array   then opacity.map { |o| o.is_a?(Numeric) ? o.clamp(0.0, 1.0) : o }
      else opacity
      end
    end

    # Resolve a draw color for immediate reading on the per-draw-call path.
    # String colors and flat `[r, g, b(, a)]` numeric arrays go through
    # `Color.for_render`'s shared cached instance and a passed-in Color is
    # returned as-is — no defensive copy. Safe because every caller reads
    # `.r/.g/.b/.a` into its payload immediately and never stores the result
    # (the `@tint` fallback is already a shared instance). Other inputs keep
    # the allocating `Color.new` path so invalid input raises exactly as
    # before.
    def resolve_draw_color(c)
      return @tint unless c
      return c if c.is_a?(Color)
      return Color.for_render(c) if c.is_a?(String) || Color.rgba_array?(c)
      Color.new(c)
    end

    # Same contract as `resolve_draw_color`, additionally passing through a
    # `Color::Set` (or recognizing an array of colors as one via `Color.set`).
    def resolve_color_or_set(c)
      return c if c.is_a?(Color::Set)
      return @tint unless c
      return c if c.is_a?(Color)
      return Color.for_render(c) if c.is_a?(String) || Color.rgba_array?(c)
      Color.set(c)
    end

    # Build a fill's per-vertex `[r, g, b, a]` tuples for the lerp draw path.
    # `c` is an already-resolved `Color` or `Color::Set` (see
    # `resolve_color_or_set`) and `opacity` is already clamped — the caller
    # resolves both first to decide the path, and only calls this when the
    # color varies per vertex OR an opacity array is given, so a single color
    # with a per-vertex `opacity:` array still fades across the fill (matching
    # `Polyline`). The flat single-color case never gets here: callers read
    # the resolved color's channels straight into the C call, allocating
    # nothing.
    def per_vertex_fill_tuples(c, opacity, count, name)
      if c.is_a?(Color::Set) && c.length != count
        raise ArgumentError, "Color::Set for #{name} must have #{count} colors. #{c.length} were given."
      end
      if opacity.is_a?(Array) && opacity.length != count
        raise ArgumentError,
              "opacity array for #{name} must have #{count} values, one per vertex. #{opacity.length} were given."
      end

      single = c.is_a?(Color::Set) ? nil : c
      Array.new(count) do |i|
        col = single || c[i]
        a = opacity.is_a?(Array) ? opacity[i] : (opacity || col.a)
        [col.r, col.g, col.b, a]
      end
    end

    # Expand a single color or a Color::Set of vertex_count colors into a flat
    # [r,g,b,a, r,g,b,a, ...] array of length vertex_count*4.
    def expand_stroke_colors(input, vertex_count, opacity, label:)
      opacity = clamp_opacity(opacity) if opacity
      c = resolve_color_or_set(input)
      if c.is_a?(Color::Set)
        unless c.length == vertex_count
          raise ArgumentError,
                "Color::Set for #{label} must have #{vertex_count} colors. #{c.length} were given."
        end
      end
      if opacity.is_a?(Array) && opacity.length != vertex_count
        raise ArgumentError,
              "opacity array for #{label} must have #{vertex_count} values. #{opacity.length} were given."
      end

      flat = Array.new(vertex_count * 4)
      vertex_count.times do |i|
        col = c.is_a?(Color::Set) ? c[i] : c
        flat[i * 4]     = col.r
        flat[i * 4 + 1] = col.g
        flat[i * 4 + 2] = col.b
        flat[i * 4 + 3] = (opacity.is_a?(Array) ? opacity[i] : opacity) || col.a
      end
      flat
    end

  end
end
