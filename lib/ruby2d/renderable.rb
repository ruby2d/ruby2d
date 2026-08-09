# Ruby2D::Renderable

module Ruby2D
  # Shared behavior for all renderable objects
  module Renderable
    # Per-object event handling (`on` / `off` / `interactive?` / `_fire_event`).
    include Interactive

    # Resolve an input color to a single Color. If given a per-vertex array or
    # Color::Set, returns the first color. nil returns nil. Used to derive a
    # single stroke color from a fill that may be per-vertex.
    def self.resolve_single_color(input)
      return nil if input.nil?
      c = Color.set(input)
      c.is_a?(Color::Set) ? Color.new(c.first) : c
    end

    # Resolve an input color allowing a Color::Set of exactly `vertex_count`
    # entries or a single color. nil returns white. Raises ArgumentError for
    # a Color::Set of the wrong length. Used by shapes that support per-vertex
    # gradients along their outline or fill.
    def self.resolve_color_or_default(input, vertex_count, label: nil)
      return Color.new('white') if input.nil?
      c = Color.set(input)
      if c.is_a?(Color::Set) && c.length != vertex_count
        prefix = label ? "`#{label}` " : ''
        raise ArgumentError,
              "#{prefix}requires #{vertex_count} colors, one for each vertex. #{c.length} were given."
      end
      c
    end

    # Normalize any color input into a flat RGBA array with `vertices` entries.
    # Accepts names, hex, [r,g,b,a], Color, Color::Set, per-vertex arrays, or nil
    # (which defaults to white). `opacity`, if given, overrides the alpha of each
    # vertex. `label:` optionally supplies a class label used in the error message.
    # Used by class-level `.render` methods.
    def self.flatten_color(input, vertices, opacity = nil, label: nil)
      fast = flatten_per_vertex(input, vertices, opacity)
      return fast if fast

      # `for_render`'s shared cached instance is safe here: this method only
      # reads the color into a flat float array, so it can never escape.
      c = Color.for_render(input.nil? ? 'white' : input)
      flatten_resolved_color(c, vertices, opacity, label: label)
    end

    # Validate an array of `[x, y]` pairs and flatten it to a flat float
    # array in one pass. Replaces an `all?` validation followed by a
    # `flat_map`, which walked the points twice and allocated a throwaway
    # pair per vertex; on a per-frame `.render` of a few thousand points that
    # overhead is comparable to the draw itself. `while`, not blocks — this
    # is a per-draw-call path and block calls dominate on wasm mruby.
    def self.flatten_points(points)
      n = points.length
      coords = Array.new(n * 2)
      i = 0
      while i < n
        point = points[i]
        raise ArgumentError, 'points must be an array of [x, y] pairs' \
          unless point.is_a?(Array) && point.length == 2

        coords[i * 2] = point[0].to_f
        coords[i * 2 + 1] = point[1].to_f
        i += 1
      end
      coords
    end

    # Flatten a per-vertex color array straight into the `vertices`×4 float
    # array, skipping `Color::Set` entirely. The general path builds a Set,
    # which allocates and parses one `Color` per vertex via `Color.new` —
    # bypassing the render cache that makes the single-color path cheap. A
    # per-frame `.render` pays that in full every frame, and for the hex
    # strings the examples favor it is the most expensive color form there
    # is. Numeric tuples are read directly; everything else resolves through
    # `Color.for_render`, whose shared instance is safe here because it is
    # read into floats immediately and never stored.
    #
    # Returns `nil` — falling back to the general path — for anything
    # unusual: a mismatched length, an out-of-range channel, an element that
    # isn't a valid color. Those still raise and warn from the one place
    # below, so this stays a pure fast path and never the error authority.
    def self.flatten_per_vertex(input, vertices, opacity)
      return nil unless input.is_a?(Array) && input.length == vertices && vertices.positive?
      # A flat `[r, g, b(, a)]` is a single color for every vertex, not a
      # list of them — its first element is the only Numeric case here.
      return nil if input[0].is_a?(Numeric)
      return nil if opacity.is_a?(Array) && opacity.length != vertices

      opacity_array = opacity.is_a?(Array)
      flat = Array.new(vertices * 4)
      i = 0
      while i < vertices
        el = input[i]
        if el.instance_of?(Array)
          # `instance_of?` mirrors `Color.valid?` — an Array subclass is not
          # the plain-array form and must take the general path.
          n = el.length
          return nil unless n == 3 || n == 4

          r = el[0]
          g = el[1]
          b = el[2]
          a = n == 4 ? el[3] : 1.0
          return nil unless r.is_a?(Numeric) && g.is_a?(Numeric) &&
                            b.is_a?(Numeric) && a.is_a?(Numeric)
          # Out of range is `Color#channel`'s business: it warns and clamps.
          return nil unless r >= 0.0 && r <= 1.0 && g >= 0.0 && g <= 1.0 &&
                            b >= 0.0 && b <= 1.0 && a >= 0.0 && a <= 1.0

          r = r.to_f
          g = g.to_f
          b = b.to_f
          a = a.to_f
        elsif el.is_a?(Color)
          r = el.r
          g = el.g
          b = el.b
          a = el.a
        else
          # Validate first so an invalid element still raises from the
          # general path, with the message it has always produced.
          return nil unless Color.valid?(el)

          c = Color.for_render(el)
          r = c.r
          g = c.g
          b = c.b
          a = c.a
        end

        j = i * 4
        flat[j] = r
        flat[j + 1] = g
        flat[j + 2] = b
        flat[j + 3] = (opacity_array ? opacity[i] : opacity) || a
        i += 1
      end
      flat
    end

    # Flatten an already-resolved `Color`/`Color::Set` into the `vertices`×4
    # float array. Split from `flatten_color` so the immediate-mode `.render`
    # paths can resolve the color once — to choose the single-color fast path —
    # without parsing it a second time when they fall back to the per-vertex array.
    def self.flatten_resolved_color(c, vertices, opacity = nil, label: nil)
      if c.is_a?(Color::Set) && c.length != vertices
        prefix = label ? "`#{label}` " : ''
        raise ArgumentError,
              "#{prefix}requires #{vertices} colors, one for each vertex. #{c.length} were given."
      end
      if opacity.is_a?(Array) && opacity.length != vertices
        prefix = label ? "`#{label}` " : ''
        raise ArgumentError,
              "#{prefix}requires #{vertices} opacity values, one for each vertex. #{opacity.length} were given."
      end

      flat = Array.new(vertices * 4)
      opacity_array = opacity.is_a?(Array)
      vertices.times do |i|
        col = c.vertex(i)
        flat[i * 4]     = col.r
        flat[i * 4 + 1] = col.g
        flat[i * 4 + 2] = col.b
        flat[i * 4 + 3] = (opacity_array ? opacity[i] : opacity) || col.a
      end
      flat
    end

    attr_reader :x, :y, :z, :width, :height, :color, :x_align, :y_align
    attr_accessor :visible,
                  :padding_top, :padding_right, :padding_bottom, :padding_left
    alias_method :visible?, :visible

    # Set all four padding edges to the same value. Padding is the distance,
    # in pixels, between the object and the window edge it's anchored to.
    # No effect on `:center`-aligned axes or un-aligned axes.
    def padding=(value)
      @padding_top = @padding_right = @padding_bottom = @padding_left = value
    end

    # Set horizontal alignment intent (`:left`, `:center`, `:right`, or `nil`).
    # Resolution is deferred to draw time against `Window.viewport_width`.
    #
    # The nil check is spelled out rather than written `sym&.to_sym`: both yield
    # a Symbol or nil, but an ahead-of-time compiler types the safe-navigation
    # form as a plain Symbol and then miscompiles the nil case (see spinel/README.md).
    def x_align=(sym)
      @x_align = sym.nil? ? nil : sym.to_sym
    end

    # Set vertical alignment intent (`:top`, `:center`, `:bottom`, or `nil`).
    # Resolution is deferred to draw time against `Window.viewport_height`.
    def y_align=(sym)
      @y_align = sym.nil? ? nil : sym.to_sym
    end

    # Resolve symbolic alignment to numeric x/y. Called from the render path of
    # each shape that opts into alignment. Requires the window to be open —
    # `Window.viewport_width` and `viewport_height` are only correct after
    # `show` starts. The `case` computes a bounding-box top-left position;
    # `_alignment_anchor_dx`/`_dy` then shift it to the shape's own anchor
    # (zero for top-left shapes, half-extent for center-anchored Circle/Ellipse).
    def _resolve_alignment
      return unless @x_align || @y_align

      dx = _alignment_anchor_dx
      dy = _alignment_anchor_dy
      @_resolving_alignment = true
      begin
        if @x_align
          span = Window.viewport_width
          self.x = (case @x_align
                    when :left   then (@padding_left || 0)
                    when :center then (span - width) / 2.0
                    when :right  then span - width - (@padding_right || 0)
                    else raise ArgumentError, "Unknown x alignment: #{@x_align.inspect}"
                    end) + dx
        end
        if @y_align
          span = Window.viewport_height
          self.y = (case @y_align
                    when :top    then (@padding_top || 0)
                    when :center then (span - height) / 2.0
                    when :bottom then span - height - (@padding_bottom || 0)
                    else raise ArgumentError, "Unknown y alignment: #{@y_align.inspect}"
                    end) + dy
        end
      ensure
        @_resolving_alignment = false
      end
    end

    # Offset from the bounding-box top-left (what `_resolve_alignment` computes)
    # to the shape's position anchor, split into x/y components to avoid boxing a
    # throwaway pair each aligned frame. Top-left-anchored shapes (Rectangle,
    # Image, Text, …) need none; center-anchored shapes override to half their
    # extent so `:left` hugs the wall with the bounding box, like a rectangle.
    def _alignment_anchor_dx
      0
    end

    def _alignment_anchor_dy
      0
    end

    # Resolve construction-time padding kwargs into per-edge values. The
    # uniform `padding:` seeds all four edges; per-edge kwargs override
    # individual slots. Called from each shape's `initialize` after
    # `_extract_alignment`.
    def _apply_padding(padding, top, right, bottom, left)
      base = padding || 0
      @padding_top    = top    || base
      @padding_right  = right  || base
      @padding_bottom = bottom || base
      @padding_left   = left   || base
    end

    # Reject negative construction-time dimensions (width, height, radius, …).
    # A negative extent is a setup mistake: it renders but disagrees with hit
    # testing, since `contains?` assumes positive geometry. Zero is allowed
    # (collapse-to-point). Runtime setters are deliberately left unguarded so an
    # animation whose size momentarily dips below zero degrades to nothing for
    # that frame rather than crashing the app — see USAGE.md.
    def _validate_dimensions(**dims)
      dims.each do |name, value|
        next unless value.is_a?(Numeric) && value.negative?
        raise ArgumentError, "#{self.class} #{name} must be zero or positive, got #{value}"
      end
    end

    # Extract symbolic alignment from a constructor (x, y) pair, store the
    # intent, and return numeric placeholders to use until the first draw.
    def _extract_alignment(x, y)
      self.x_align = x if x.is_a?(Symbol)
      self.y_align = y if y.is_a?(Symbol)
      [x.is_a?(Symbol) ? 0 : x, y.is_a?(Symbol) ? 0 : y]
    end

    # Reject a non-numeric position on a shape with no single anchor to align.
    # Bounding-box shapes (Image, Text, Rectangle, Circle, Ellipse) accept a
    # symbol like `:center` as alignment intent; the centroid-anchored vertex
    # shapes (Triangle, Quad, Polygon, Polyline) and the pixel-buffer Canvas have
    # nothing to align, so a symbol there is a setup mistake. Raise a clear error
    # rather than let it reach the centroid arithmetic (a bare `Symbol#-`
    # NoMethodError) or the native renderer (a cryptic type error at draw time).
    # Returns the value so a setter can validate and assign in one expression.
    def _require_numeric_position(axis, value)
      return value if value.is_a?(Numeric)
      raise Error,
            "#{self.class} #{axis} must be a number; #{self.class} doesn't support " \
            "symbolic alignment (e.g. #{axis}: :center) — use a bounding-box shape " \
            'like Text, Image, or Rectangle for that'
    end

    # Set the z position (depth) of the object. Re-inserts at the new depth only
    # if the object was actually in the scene graph — `Window#remove` returns
    # false for an object built with `add: false` or already removed, so changing
    # its `z` updates the value without silently adding it to the window.
    def z=(z)
      was_added = remove
      @z = z
      add if was_added
    end

    # Add the object to the window's scene graph. This governs iteration and
    # z-ordering, not visibility. Use #show / #hide (or the `visible` accessor)
    # to toggle frame-by-frame drawing without affecting scene-graph membership.
    def add
      Window.add(self)
    end

    # Remove the object from the window's scene graph.
    def remove
      Window.remove(self)
    end

    # Mark the object visible. Preserves scene-graph position and z-order; the
    # window's render loop will draw it on subsequent frames.
    def show
      @visible = true
    end

    # Mark the object hidden. Stays in the scene graph (and contains?/events
    # continue to work). Visually equivalent to opacity 0 but with zero draw
    # cost.
    def hide
      @visible = false
    end

    # Scene-graph draw hook, called once per frame per visible object. This
    # fallback forwards to `render` so a custom renderable only has to define
    # `render`; every built-in shape overrides or aliases it to skip the
    # keyword handling of its public `render`, which costs ~5µs per call on
    # wasm mruby even when no keywords are passed. Public — like the other
    # underscore-prefixed internals — so the scene loop can call it directly:
    # a `send` there costs real time at thousands of objects per frame. Shapes
    # that alias it from a private `render` re-publicize the alias with
    # `public :_render_scene`, since aliases inherit the original visibility.
    def _render_scene
      render
    end

    # Set the color value
    def color=(color)
      @color = Color.new(color)
    end

    # Allow British English spelling of color
    alias colour color

    def colour=(color)
      self.color = color
    end

    # Get the opacity (alpha) of the object's fill color. For per-vertex
    # `Color::Set` fills, returns the alpha of the first color.
    def opacity
      @color&.opacity
    end

    # Set the opacity (alpha) of the object's color. Fades the fill and, on
    # shapes that have one, the stroke too — matching how a construction-time
    # `opacity:` applies to both. For per-vertex `Color::Set` colors, sets every
    # vertex's alpha to the same value. To fade fill and stroke independently,
    # set each color's opacity directly: `obj.color.opacity = a` and
    # `obj.stroke_color.opacity = b`.
    def opacity=(value)
      @color.opacity = value
      @stroke_color.opacity = value if instance_variable_defined?(:@stroke_color) && @stroke_color
    end

    # Map a query point into this object's unrotated coordinate frame. Each
    # shape's `render` rotates geometry about `(rx, ry)` by `@rotate` degrees
    # before drawing; `contains?` calls this first so hit-testing matches what
    # the user sees. Returns the point unchanged when there's no rotation (or
    # the object has no rotation pivot, e.g. `BitmapText`).
    # Takes the object explicitly, as a module function, rather than reading it
    # off `self` as an instance method. Both work under CRuby, but an
    # ahead-of-time compiler resolves a module instance method against the
    # module itself — where `rx` / `ry`, which only the includers define, cannot
    # be resolved — and silently emits a call to a function it never defines.
    # `Renderable`'s other helpers are module functions for related reasons.
    # See spinel/README.md.
    def self._unrotate(obj, px, py)
      rotate = obj.instance_variable_get(:@rotate)
      return [px, py] if rotate.nil? || rotate == 0

      cx = obj.rx; cy = obj.ry
      rad = -rotate * Math::PI / 180.0
      sa = Math.sin(rad); ca = Math.cos(rad)
      dx = px - cx; dy = py - cy
      [dx * ca - dy * sa + cx, dx * sa + dy * ca + cy]
    end

    # Even-odd ray-cast point-in-polygon test over a flat `[x0, y0, x1, y1, ...]`
    # coordinate array. This is the shared hit-test for every filled polygonal
    # shape (`Triangle`, `Quad`, `Polygon`) so `contains?` means "inside the
    # rendered fill" consistently — matching the fill for simple polygons (convex
    # and concave). Self-intersecting input isn't fully supported by the fill
    # renderer, so the test can diverge from the drawn pixels there. The boundary
    # is half-open (top/right edges read as outside), as in rasterization.
    def _point_in_polygon?(coords, px, py)
      n = coords.length / 2
      inside = false
      j = n - 1
      n.times do |i|
        xi = coords[i * 2]; yi = coords[i * 2 + 1]
        xj = coords[j * 2]; yj = coords[j * 2 + 1]
        if (yi > py) != (yj > py) &&
           px < (xj - xi) * (py - yi) / (yj - yi).to_f + xi
          inside = !inside
        end
        j = i
      end
      inside
    end

    # Hit-test a point against the stroked band of segment (x1, y1)-(x2, y2):
    # true when (px, py) lies within the rectangle the stroke actually draws.
    # `half_sq` is the squared half-stroke-width tolerance. The point must
    # project onto the segment (0 <= t <= 1) *and* fall within the half-width
    # perpendicular, so the hit region matches the drawn (butt-capped) rectangle
    # and does not overhang the ends. Shared stroke hit-test for `Line` and
    # `Polyline`; compares squared distances to skip the square root on this
    # per-event, per-segment path.
    def _point_on_segment?(px, py, x1, y1, x2, y2, half_sq)
      dx = x2 - x1
      dy = y2 - y1
      len_sq = dx * dx + dy * dy
      return false if len_sq.zero? # zero-length segment draws nothing

      # fdiv (not /) so integer coordinates don't trigger integer floor
      # division, which would snap t to 0/1 and mis-measure the projection.
      t = ((px - x1) * dx + (py - y1) * dy).fdiv(len_sq)
      return false if t < 0.0 || t > 1.0 # past an end — outside the drawn rect

      cx = x1 + t * dx
      cy = y1 + t * dy
      ex = px - cx; ey = py - cy
      ex * ex + ey * ey <= half_sq
    end

    # Check if the object contains the given point
    def contains?(x, y)
      x, y = Renderable._unrotate(self, x, y)
      x >= @x && x <= (@x + @width) && y >= @y && y <= (@y + @height)
    end

  end

  # How a texture is sampled when drawn at a size other than its own. Mixed
  # into the texture-backed classes; shapes have nothing to sample.
  module TextureScaling
    # `:linear` smooths between texels, `:nearest` keeps hard pixel edges,
    # `:pixel_art` is nearest at integer scales and antialiased at fractional.
    SCALE_MODES = %i[linear nearest pixel_art].freeze

    # nil means inherit the window's.
    def self.validate(value)
      return nil if value.nil?
      unless SCALE_MODES.include?(value)
        raise Error, "Invalid scale_mode #{value.inspect}; expected one of #{SCALE_MODES.inspect}"
      end

      value
    end

    # The object's sampling mode, or nil to follow the window.
    attr_reader :scale_mode

    def scale_mode=(value)
      @scale_mode = TextureScaling.validate(value)
    end
  end
end
