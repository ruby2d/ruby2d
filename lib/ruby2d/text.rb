# Ruby2D::Text

module Ruby2D
  # A text string drawn with a specified font and size
  class Text
    include Renderable

    # Font style name → TTF style flag bit (mirrors SDL3_ttf's `TTF_STYLE_*`).
    STYLE_FLAGS = {
      normal: 0, bold: 1, italic: 2, underline: 4, strikethrough: 8
    }.freeze

    # Frozen NUL string for the content scan below. A bare `"\0"` literal would
    # allocate a throwaway string on every `content=` — 360×/frame under a
    # dynamic-text HUD — since the library doesn't enable frozen string literals.
    NUL = "\0".freeze

    attr_reader :content, :size, :font, :style
    attr_accessor :rotate

    # Set the x position. Pass a symbol (`:left`, `:center`, `:right`) to
    # set alignment intent — resolved at draw time against the window.
    def x=(value)
      return self.x_align = value if value.is_a?(Symbol)
      @x_align = nil unless @_resolving_alignment
      @x = value
    end

    # Set the y position. Pass a symbol (`:top`, `:center`, `:bottom`) to
    # set alignment intent — resolved at draw time against the window.
    def y=(value)
      return self.y_align = value if value.is_a?(Symbol)
      @y_align = nil unless @_resolving_alignment
      @y = value
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

    # Create a text object
    def initialize(content, size: 20, style: nil, font: Font.default,
                   x: 0, y: 0, z: 0,
                   rotate: 0, rx: nil, ry: nil, color: nil, colour: nil,
                   opacity: nil, add: true, visible: true,
                   padding: nil, padding_top: nil, padding_right: nil,
                   padding_bottom: nil, padding_left: nil)
      x, y = _extract_alignment(x, y)
      _apply_padding(padding, padding_top, padding_right, padding_bottom, padding_left)
      @x = x
      @y = y
      @z = z
      @content = validate_content(content).dup.freeze
      @size = validate_size(size)
      @rotate = rotate
      @_user_rx = rx
      @_user_ry = ry
      @style = style
      @style_flags = compute_style_flags(style)
      @font = normalize_font_path(font)

      self.color = color || colour || 'white'
      self.opacity = opacity unless opacity.nil?
      Ext.text_create(self)

      @visible = visible
      self.add if add
    end

    # Set the text content. A no-op when the content is unchanged — rebuilding
    # the texture is the expensive part, and per-frame assignments of the same
    # string (HUDs, score counters) are common. Validation still runs first so
    # invalid input raises regardless; the frozen copy is only allocated when
    # the content actually changes, so a same-string per-frame assignment costs
    # a coerce and a compare, not a string copy.
    def content=(msg)
      str = validate_content(msg)
      return if str == @content

      @content = str.dup.freeze
      Ext.text_create(self)
    end

    # Set the font size. A no-op when unchanged, like `content=` — rebuilding
    # the texture is the expensive part, and per-frame assignments of the same
    # value are common.
    def size=(size)
      size = validate_size(size)
      return if size == @size

      @size = size
      Ext.text_create(self)
    end

    # Set the font style. Accepts `:normal`, `:bold`, `:italic`, `:underline`,
    # `:strikethrough`, an array combining them (e.g. `[:bold, :italic]`), or
    # `nil` for normal. Re-renders the text; a no-op when the computed style
    # flags are unchanged (`:bold` and `[:bold]` are the same style).
    def style=(style)
      flags = compute_style_flags(style)
      @style = style
      return if flags == @style_flags

      @style_flags = flags
      Ext.text_create(self)
    end

    # Set the font, given a path to a `.ttf` file. Re-renders the text; a
    # no-op when the resolved path is unchanged.
    def font=(font)
      font = normalize_font_path(font)
      return if font == @font

      @font = font
      Ext.text_create(self)
    end

    # Render the text. Called with overrides for one-shot rendering inside a
    # render block; with no arguments it draws the same frame the scene graph
    # does (delegating to `_render_scene`).
    def render(x: nil, y: nil, rotate: nil, color: nil, colour: nil, opacity: nil)
      if x.nil? && y.nil? && rotate.nil? && color.nil? && colour.nil? && opacity.nil?
        return _render_scene
      end

      Window.render_ready_check

      saved_x, saved_y = @x, @y
      saved_rotate = @rotate
      saved_color = @color

      @x = x if x
      @y = y if y
      @rotate = rotate if rotate

      c = color || colour
      if c || opacity
        @color = c ? Color.new(c) : Color.new(saved_color)
        @color.opacity = opacity if opacity
      end

      begin
        Ext.text_draw(self, rx, ry)
      ensure
        @x, @y = saved_x, saved_y
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
      _resolve_alignment
      Ext.text_draw(self, rx, ry)
    end
    public :_render_scene

    # Coerce a font argument to a usable path: stringify, expand a leading `~`
    # on CRuby, and raise a clear error if the file is missing.
    def normalize_font_path(font)
      font = font.to_s
      font = File.expand_path(font) if RUBY_ENGINE == 'ruby' && font.start_with?('~')
      raise Error, "Font file `#{font}` not found" unless File.exist?(font)

      font
    end

    # Ensure the font size is a positive number, raising a clear error instead
    # of letting an invalid value reach the native font loader (where it would
    # surface as a cryptic `TypeError`/`TTF_OpenFont failed`). Coerce to the same
    # integer the native renderer uses (truncation toward zero) so the `size`
    # reader equals the size actually rendered — e.g. `size: 10.9` renders and
    # reports 10, not 10.9.
    def validate_size(size)
      unless size.is_a?(Numeric) && size > 0
        raise Error, "Text size must be a positive number, got #{size.inspect}"
      end

      size.to_i
    end

    # Coerce content to a string and reject embedded NUL bytes. NUL has no glyph
    # and SDL_ttf cannot render it — passing one to the native rasterizer
    # hangs/over-allocates on U+0000 — while silently truncating at the NUL (the
    # historical behavior) hides the caller's corrupt data. So fail loudly.
    # Returns the coerced string as-is (which may be the caller's own object for
    # a String argument); callers that store it own the `dup.freeze`, so the
    # cheap no-op comparison in `content=` runs before anything is allocated.
    # Freezing at the store site stops in-place mutation (`text.content << 'x'`)
    # from desyncing the native surface, which only rerasterizes via `content=`.
    def validate_content(content)
      str = content.to_s
      raise Error, 'Text content cannot contain NUL (\0) bytes' if str.include?(NUL)

      str
    end

    # Combine a style (nil, a symbol, a string, or an array of them) into the
    # integer TTF style flags the native renderer expects. Raises a clear error
    # on an unknown style name rather than silently ignoring it.
    def compute_style_flags(style)
      return 0 if style.nil?

      Array(style).reduce(0) do |flags, s|
        bit = STYLE_FLAGS[s.to_s.to_sym]
        if bit.nil?
          raise Error,
                "Unknown text style #{s.inspect}; expected one of #{STYLE_FLAGS.keys}"
        end
        flags | bit
      end
    end
  end
end
