# Ruby2D::BitmapText

module Ruby2D
  # Text drawn with the built-in bitmap font (no TTF file needed)
  class BitmapText
    include Renderable
    include TextureScaling

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
      @content = content.to_s
      @scale = validate_scale(scale)

      self.color = color || colour || 'white'
      self.opacity = opacity unless opacity.nil?
      Ext.bitmap_text_create(self)

      @visible = visible
      self.add if add
    end

    # Set the text content. A no-op when the content is unchanged — rebuilding
    # the texture is the expensive part, and per-frame assignments of the same
    # string (HUDs, score counters) are common.
    def content=(msg)
      msg = msg.to_s
      return if msg == @content

      @content = msg
      Ext.bitmap_text_create(self)
    end

    # Set the scale. A no-op when unchanged, like `content=` — rebuilding the
    # texture is the expensive part.
    def scale=(s)
      s = validate_scale(s)
      return if s == @scale

      @scale = s
      Ext.bitmap_text_create(self)
    end

    # Render the text. Called with overrides for one-shot rendering inside a
    # render block; with no arguments it draws the same frame the scene graph
    # does (delegating to `_render_scene`).
    def render(x: nil, y: nil, scale: nil, rotate: nil, color: nil, colour: nil, opacity: nil)
      if x.nil? && y.nil? && scale.nil? && rotate.nil? && color.nil? && colour.nil? && opacity.nil?
        return _render_scene
      end

      Window.render_ready_check

      saved_x, saved_y = @x, @y
      saved_scale = @scale
      saved_rotate = @rotate
      saved_color = @color

      @x = x if x
      @y = y if y
      @scale = validate_scale(scale) if scale
      @rotate = rotate if rotate

      c = color || colour
      if c || opacity
        @color = c ? Color.new(c) : Color.new(saved_color)
        @color.opacity = opacity if opacity
      end

      begin
        Ext.bitmap_text_draw(self, rx, ry)
      ensure
        @x, @y = saved_x, saved_y
        @scale = saved_scale
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

    def _validate_coordinate(axis, value)
      unless value.is_a?(Numeric)
        raise Error,
              "BitmapText #{axis} must be a number; symbolic alignment " \
              "(e.g. #{axis}: :center) is not supported — use Text instead"
      end
      value
    end

    # Ensure the scale is a positive number, raising a clear error instead of
    # letting an invalid value reach the native renderer (where a non-numeric
    # value surfaces as a cryptic `TypeError` and zero/negative silently builds
    # a blank, zero-or-negative-sized texture). Coerce to the same integer the
    # native renderer uses (truncation toward zero) so the `scale` reader equals
    # the scale actually rendered — e.g. `scale: 2.9` renders and reports 2.
    def validate_scale(scale)
      unless scale.is_a?(Numeric) && scale > 0
        raise Error, "BitmapText scale must be a positive number, got #{scale.inspect}"
      end

      scale.to_i
    end
  end
end
