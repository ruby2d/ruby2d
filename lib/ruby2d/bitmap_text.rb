# Ruby2D::BitmapText

module Ruby2D
  # Text drawn with the built-in bitmap font (no TTF file needed)
  class BitmapText
    include Renderable
    include TextureScaling

    # Frozen NUL string for the content scan, as in `Text` — a bare literal
    # would allocate on every `content=`.
    NUL = "\0".freeze

    attr_reader :content, :scale, :x, :y
    attr_accessor :rotate

    # Set the x position. BitmapText has no symbolic alignment, so x must be a
    # number — a symbol would otherwise crash with a type error at draw time.
    def x=(value)
      @x = _validate_coordinate(:x, value)
    end

    # Set the y position (numeric only — see `x=`).
    def y=(value)
      @y = _validate_coordinate(:y, value)
    end

    # Get the rotation center x coordinate (defaults to the text's center)
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

    # Create a bitmap text object
    def initialize(content, x: 0, y: 0, z: 0, scale: 3,
                   rotate: 0, rx: nil, ry: nil,
                   color: nil, colour: nil, opacity: nil,
                   add: true, visible: true, scale_mode: nil)
      self.scale_mode = scale_mode
      self.x = x
      self.y = y
      @z = z
      @rotate = rotate
      @_user_rx = rx
      @_user_ry = ry
      @content = validate_content(content).dup.freeze
      @scale = validate_scale(scale)

      self.color = color || colour || 'white'
      self.opacity = opacity unless opacity.nil?
      Ext.bitmap_text_create(self)

      @visible = visible
      self.add if add
    end

    # Set the text content. A no-op when the content is unchanged — rebuilding
    # the texture is the expensive part, and per-frame assignments of the same
    # string (HUDs, score counters) are common. The stored string is a frozen
    # copy, as in `Text`: the width and height are measured here, and a
    # caller's string mutated in place (a reused buffer) would change what's
    # drawn without updating them — and read as unchanged when assigned back.
    def content=(msg)
      str = validate_content(msg)
      return if str == @content

      previous = @content
      @content = str.dup.freeze
      begin
        Ext.bitmap_text_create(self)
      rescue StandardError => e
        @content = previous
        raise e
      end
    end

    # Set the scale. A no-op when unchanged, like `content=` — rebuilding the
    # texture is the expensive part. Both setters restore their attribute when
    # the native call raises, as `Text`'s do, so the object keeps describing
    # what it measured.
    def scale=(s)
      s = validate_scale(s)
      return if s == @scale

      previous = @scale
      @scale = s
      begin
        Ext.bitmap_text_create(self)
      rescue StandardError => e
        @scale = previous
        raise e
      end
    end

    # Render the text. Called with overrides for one-shot rendering inside a
    # render block, it draws as the scene would draw a text holding those
    # values — a `scale:` override rotates about the scaled text's center —
    # and then puts the text back, even when the draw raises. With no
    # arguments it draws the same frame the scene graph does (delegating to
    # `_render_scene`).
    def render(x: nil, y: nil, scale: nil, rotate: nil, color: nil, colour: nil, opacity: nil)
      if x.nil? && y.nil? && scale.nil? && rotate.nil? && color.nil? && colour.nil? && opacity.nil?
        return _render_scene
      end

      Window.render_ready_check
      x = _validate_coordinate(:x, x) if x
      y = _validate_coordinate(:y, y) if y
      scale = validate_scale(scale) if scale
      color = _override_color(color || colour, opacity, @color)

      saved_x, saved_y = @x, @y
      saved_scale = @scale
      saved_width, saved_height = @width, @height
      saved_rotate = @rotate
      saved_color = @color

      begin
        @x = x if x
        @y = y if y
        if scale
          # The glyph grid scales linearly (see `bitmap_text_create`), so the
          # size the default rotation center is measured against does too.
          @width  = @width  * scale / saved_scale
          @height = @height * scale / saved_scale
          @scale  = scale
        end
        @rotate = rotate if rotate
        @color = color if color
        Ext.bitmap_text_draw(self, rx, ry)
      ensure
        @x, @y = saved_x, saved_y
        @scale = saved_scale
        @width, @height = saved_width, saved_height
        @rotate = saved_rotate
        @color = saved_color
      end
    end

    private

    # Scene-graph draw hook (see Renderable#_render_scene): `render` with no
    # overrides, minus its keyword handling — a zero-arg call into a
    # keyword-heavy `render` still pays microseconds of keyword setup on wasm
    # mruby.
    def _render_scene
      Ext.bitmap_text_draw(self, rx, ry)
    end
    public :_render_scene

    # Coerce content to a string and reject embedded NUL bytes, as `Text`
    # does. The native side measures and draws the string to its terminator,
    # so a NUL silently cut off everything after it; the placeholder the font
    # draws for other unsupported characters never saw the suffix.
    def validate_content(content)
      str = content.to_s
      raise Error, 'BitmapText content cannot contain NUL (\0) bytes' if str.include?(NUL)

      str
    end

    def _validate_coordinate(axis, value)
      unless value.is_a?(Numeric)
        raise Error,
              "BitmapText #{axis} must be a number; symbolic alignment " \
              "(e.g. #{axis}: :center) is not supported — use Text instead"
      end
      value
    end

    # Ensure the scale is a number of at least 1, raising a clear error
    # instead of letting an invalid value reach the native renderer (where a
    # non-numeric value surfaces as a cryptic `TypeError` and zero/negative
    # silently builds a blank, zero-or-negative-sized texture). Coerce to the
    # same integer the native renderer uses (truncation toward zero) so the
    # `scale` reader equals the scale actually rendered — e.g. `scale: 2.9`
    # renders and reports 2; a value below 1 would truncate to a scale of 0.
    def validate_scale(scale)
      unless scale.is_a?(Numeric) && scale >= 1 && (scale.is_a?(Integer) || scale.finite?)
        raise Error, "BitmapText scale must be a number of at least 1, got #{scale.inspect}"
      end

      scale.to_i
    end
  end
end
