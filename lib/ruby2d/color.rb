# Ruby2D::Color

module Ruby2D
  # A color from a keyword, hex value, or RGBA array
  class Color
    # An array of colors
    class Set
      include Enumerable

      # Create a color set from an array of colors
      def initialize(colors)
        raise Error, 'a Color::Set requires at least one color, got an empty array' if colors.empty?

        @_rev = 0
        @colors = colors.map { |c| Color.new(c)._adopt(self) }
      end

      # Mutation revision of the whole set; see `Color#_rev`. Each member
      # color bumps it when a channel changes, so a shape holding a gradient
      # can compare one integer instead of rescanning every vertex color.
      attr_reader :_rev

      # Called by a member color when it changes (see `Color#_adopt`).
      def _touch
        @_rev += 1
      end

      # Get a color by index
      def [](index)
        @colors[index]
      end

      # Get the number of colors in the set
      def length
        @colors.length
      end

      # Iterate over each color
      def each(&block)
        @colors.each(&block)
      end

      # Get the first color, or the first `n` colors if a count is given
      def first(*args)
        @colors.first(*args)
      end

      # Get the last color, or the last `n` colors if a count is given
      def last(*args)
        @colors.last(*args)
      end

      # Get the opacity of the first color
      def opacity
        @colors.first.opacity
      end

      # Set the opacity for all colors
      def opacity=(opacity)
        unless opacity.is_a?(Numeric)
          raise ArgumentError, "opacity must be a number between 0.0 and 1.0, got #{opacity.inspect}"
        end

        @colors.each do |color|
          color.opacity = opacity
        end
      end

      # The color for the i-th vertex. Paired with `Color#vertex` so per-vertex
      # rendering code can uniformly call `color.vertex(i)` whether it holds a
      # single `Color` (every vertex is the same) or a `Color::Set`.
      def vertex(i)
        @colors[i]
      end
    end

    attr_reader :r, :g, :b, :a

    # Mutation revision: a counter bumped by every in-place channel change
    # (`r=`, `g=`, `b=`, `a=`, `opacity=`). Shapes cache their flattened RGBA
    # arrays against it, so an unchanged color costs one integer comparison
    # per draw instead of a per-channel (per-vertex, for gradients) rescan.
    # Internal; not part of the public API.
    attr_reader :_rev

    def r=(value)
      @r = value
      _touch
    end

    def g=(value)
      @g = value
      _touch
    end

    def b=(value)
      @b = value
      _touch
    end

    def a=(value)
      @a = value
      _touch
    end

    # Bounded cache of parsed color strings, keyed by the user input.
    # `'random'` is never cached (re-randomized on each call).
    PARSE_CACHE_MAX = 256
    @parse_cache = {}

    # Bounded cache of shared Color instances for immediate-mode `.render`
    # calls, keyed by the color string, plus one scratch instance refilled for
    # every flat numeric `[r, g, b(, a)]` input. See `Color.for_render`.
    RENDER_CACHE_MAX = 256
    @render_cache = {}
    @render_scratch = nil

    # Based on clrs.cc
    NAMED_COLORS = {
      'navy' => '#001F3F',
      'blue' => '#0074D9',
      'aqua' => '#7FDBFF',
      'teal' => '#39CCCC',
      'olive' => '#3D9970',
      'green' => '#2ECC40',
      'lime' => '#01FF70',
      'yellow' => '#FFDC00',
      'orange' => '#FF851B',
      'red' => '#FF4136',
      'brown' => '#663300',
      'fuchsia' => '#F012BE',
      'purple' => '#B10DC9',
      'maroon' => '#85144B',
      'white' => '#FFFFFF',
      'silver' => '#DDDDDD',
      'gray' => '#AAAAAA',
      'black' => '#111111',
      'random' => ''
    }.freeze

    # Create a color from a keyword, hex string, array, or Color
    def initialize(color)
      raise Error, "#{color.inspect} is not a valid color" unless self.class.valid? color

      @_rev = 0
      @_owner = nil

      case color
      when String
        init_from_string color
      when Array
        @r = channel(color[0])
        @g = channel(color[1])
        @b = channel(color[2])
        @a = color.length == 4 ? channel(color[3]) : 1.0
      when Color
        @r = color.r
        @g = color.g
        @b = color.b
        @a = color.a
      end
    end

    class << self
      # Create a Color or Color::Set from the given value
      def set(colors)
        # Already a Color::Set (e.g. re-applying a gradient fill): pass through.
        return colors if colors.is_a?(Color::Set)

        # A non-empty array of valid colors becomes a `Color::Set`. An empty
        # array is not a valid gradient, so it falls through to `Color.new`,
        # which raises a clear "not a valid color" at the mistake site.
        if colors.is_a?(Array) && !colors.empty? && colors.all? { |el| Color.valid? el }
          Color::Set.new(colors)
        # Otherwise, return single color
        else
          Color.new(colors)
        end
      end

      # Resolve a color for an immediate-mode class-level `.render` call.
      # Behaves like `.set`, except string colors return a shared cached Color
      # instance and flat `[r, g, b(, a)]` numeric arrays return one shared
      # scratch instance refilled in place — both skip the validation re-scan
      # and object allocation `.new` pays on every call. Those two forms are
      # the common case in per-frame draws, and on the web (mruby/wasm) that
      # per-call cost dominates the frame budget. The returned instance is
      # read and forwarded to the native draw call immediately; it must never
      # be stored on an object, handed to user code, or held across another
      # `for_render` call (the next numeric input overwrites the scratch) —
      # use `.set` anywhere the color is kept. `'random'` is never cached, so
      # each call still rolls a fresh color.
      def for_render(colors)
        if colors.is_a?(String)
          cached = @render_cache[colors]
          return cached if cached
          return Color.new(colors) if colors == 'random'

          @render_cache.shift if @render_cache.size >= RENDER_CACHE_MAX
          @render_cache[colors] = Color.new(colors)
        elsif colors.is_a?(Array) && colors[0].is_a?(Numeric) && rgba_array?(colors)
          # ^ The two inline checks pre-screen the non-match cases (an array of
          # colors starts with a String/Array/Color, never a Numeric) so this
          # per-draw-call path only pays the `rgba_array?` method call when the
          # input is almost certainly a flat [r, g, b(, a)] array.
          # Numeric tuples are not cached by value: a hash lookup on a 4-float
          # key costs more than refilling four channels, and high-cardinality
          # inputs (a fresh `[rand, rand, rand]` per draw) would miss every
          # time, each miss allocating a `Color`, a frozen key copy, and the
          # pair `Hash#shift` returns on eviction.
          scratch = (@render_scratch ||= Color.new('white'))
          scratch._set_channels(colors[0], colors[1], colors[2],
                                colors.length == 4 ? colors[3] : 1.0)
          scratch
        else
          # Qualified: Ruby 2D also has a top-level `set` in the DSL, so a bare
          # call here reads ambiguously — and resolves to the wrong one under a
          # build that puts the DSL methods at the top level (see spinel/README.md).
          Color.set(colors)
        end
      end

      # A flat `[r, g, b]` or `[r, g, b, a]` numeric array — the array form a
      # single color takes (an array of *colors* is a `Color::Set`, and its
      # elements are never bare Numerics). `while`, not blocks — this guards
      # the per-draw-call render path and block calls dominate on wasm mruby.
      def rgba_array?(colors)
        return false unless colors.is_a?(Array)

        n = colors.length
        return false unless n == 3 || n == 4

        i = 0
        while i < n
          return false unless colors[i].is_a?(Numeric)
          i += 1
        end
        true
      end

      # Check if the string is a valid hex color value
      # Byte comparisons, not slicing: `valid?` calls this on every `Color.new`
      # and on every per-vertex color of every immediate-mode draw, and the
      # readable form (`[0]`, `[1..]`, `.chars`, plus a fresh literal for the
      # allowed set) allocated about ten short-lived strings each time.
      def hex?(color_string)
        return false unless color_string.instance_of?(String) &&
                            color_string.getbyte(0) == 35 # '#'

        len = color_string.length
        return false unless len == 4 || len == 7 || len == 9

        i = 1
        while i < len
          b = color_string.getbyte(i)
          return false unless (b >= 48 && b <= 57) ||   # 0-9
                              (b >= 65 && b <= 70) ||   # A-F
                              (b >= 97 && b <= 102)     # a-f

          i += 1
        end
        true
      end

      # Check if the value is a valid color
      def valid?(color)
        color.is_a?(Color) ||             # color object
          NAMED_COLORS.key?(color) ||     # keyword
          hex?(color) ||                  # hexadecimal value
          (                               # [r, g, b] or [r, g, b, a] numbers
            color.instance_of?(Array) &&
            (color.length == 3 || color.length == 4) &&
            color.all? { |el| el.is_a?(Numeric) }
          )
      end

      # Parse a color string into a frozen `[r, g, b, a]` tuple, caching the
      # result. Named colors and hex strings are cached; `'random'` is not.
      # Callers must not mutate the returned array.
      def parse_string(color)
        # Check the cache first so the hot path (a previously-seen named or hex
        # color) returns before the `'random'` literal comparison, which would
        # otherwise allocate a fresh `'random'` string on every call. `'random'`
        # is never cached, so it still falls through to a fresh value below.
        cached = @parse_cache[color]
        return cached if cached

        return [rand, rand, rand, 1.0] if color == 'random'

        source = hex?(color) ? color : NAMED_COLORS[color]
        rgba = hex_to_f(source).freeze
        @parse_cache.shift if @parse_cache.size >= PARSE_CACHE_MAX
        @parse_cache[color] = rgba
      end

      private

      # Convert a hex color (e.g. #FFF, #FFF000, #FFF000FF) to [r, g, b, a]
      # floats in 0.0..1.0.
      def hex_to_f(hex_color)
        hex = hex_color[1..]
        hex = hex.chars.map { |c| c * 2 }.join if hex.length == 3
        rgba = hex.chars.each_slice(2).map { |pair| pair.join.to_i(16) }
        rgba << 255 if rgba.length == 3
        rgba.map { |n| n / 255.0 }
      end
    end

    # Get the opacity
    def opacity
      @a
    end

    # Set the opacity. Must be a single number; per-vertex opacity (an array)
    # is only supported by shapes that handle it explicitly, such as Polyline.
    # The value is clamped to 0.0..1.0 so an animation that momentarily drives
    # opacity out of range degrades to fully transparent/opaque rather than
    # wrapping the Uint8 alpha cast into a wrong, near-opaque byte.
    def opacity=(opacity)
      unless opacity.is_a?(Numeric)
        raise ArgumentError, "opacity must be a number between 0.0 and 1.0, got #{opacity.inspect}"
      end

      @a = opacity.clamp(0.0, 1.0)
      _touch
    end

    # Return the color components as an array
    def to_a
      [@r, @g, @b, @a]
    end

    # The color for the i-th vertex. A single `Color` represents "every vertex
    # is the same color," so every index returns self. Mirrors `Color::Set#vertex`
    # so per-vertex rendering code can call `color.vertex(i)` without branching.
    def vertex(_i)
      self
    end

    # Overwrite all four channels with the same validation `Color.new` applies
    # to a numeric array (out-of-range warns once and clamps). Backs the
    # `for_render` scratch instance; deliberately leaves `_rev` alone, since
    # that instance is never cached against. Internal.
    def _set_channels(r, g, b, a)
      # In-range is the overwhelmingly common case; check it inline so the
      # per-draw-call path pays one method call, not four.
      if r >= 0.0 && r <= 1.0 && g >= 0.0 && g <= 1.0 &&
         b >= 0.0 && b <= 1.0 && a >= 0.0 && a <= 1.0
        @r = r.to_f
        @g = g.to_f
        @b = b.to_f
        @a = a.to_f
      else
        @r = channel(r)
        @g = channel(g)
        @b = channel(b)
        @a = channel(a)
      end
      self
    end

    # Register the `Color::Set` this color belongs to, so channel changes
    # propagate to the set's revision. A set clones its members on creation,
    # so each color has at most one owner. Internal; returns self.
    def _adopt(owner)
      @_owner = owner
      self
    end

    private

    def _touch
      @_rev += 1
      @_owner._touch if @_owner
    end

    def init_from_string(color)
      @r, @g, @b, @a = self.class.parse_string(color)
    end

    # Interpret a color channel on the 0.0..1.0 scale — the graphics-programming
    # convention also used internally and by the renderer. Both integers and
    # floats are taken at face value on this scale, so `1` is full intensity and
    # `0` is none; for 0..255 byte values, use a hex string like `'#FF8000'`. An
    # out-of-range value warns once and clamps to the nearest bound so the stored
    # color always stays in range.
    def channel(value)
      return value.to_f if value >= 0.0 && value <= 1.0

      Ruby2D.warn("color value #{value} is out of range; components must be 0.0..1.0")
      value < 0.0 ? 0.0 : 1.0
    end
  end

  # Allow British English spelling of color
  Colour = Color
end
