# Ruby2D::Image

module Ruby2D
  # An image drawn in the window
  class Image
    include Renderable
    include TextureScaling

    # Image uses `tint` instead of `color` — the image already has its own
    # colors in the texture; tint modulates them.
    undef_method :color, :color=, :colour, :colour=

    attr_reader :path
    attr_accessor :width, :height, :rotate

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

    # Create an image
    def initialize(path,
                   width: nil, height: nil, x: 0, y: 0, z: 0,
                   rotate: 0, rx: nil, ry: nil, tint: nil,
                   opacity: nil, add: true, visible: true,
                   padding: nil, padding_top: nil, padding_right: nil,
                   padding_bottom: nil, padding_left: nil,
                   scale_mode: nil, _share_from: nil)
      @width = width
      @height = height
      self.scale_mode = scale_mode

      x, y = _extract_alignment(x, y)
      _apply_padding(padding, padding_top, padding_right, padding_bottom, padding_left)
      @x = x
      @y = y
      @z = z
      @rotate = rotate
      @_user_rx = rx
      @_user_ry = ry
      self.tint = tint || 'white'
      self.tint.opacity = opacity unless opacity.nil?

      if _share_from
        # SpriteSheet uses this to give every Sprite the same backing texture
        # without re-decoding the file or re-uploading to the GPU.
        @path        = _share_from.path
        @ext_image   = _share_from.instance_variable_get(:@ext_image)
        # Inherit the sheet's sampling unless this Sprite asked for its own
        @scale_mode ||= _share_from.scale_mode
        @orig_width  = _share_from.instance_variable_get(:@orig_width)
        @orig_height = _share_from.instance_variable_get(:@orig_height)
        @width     ||= @orig_width
        @height    ||= @orig_height
        @clipped     = false
        @clip_x      = 0.0
        @clip_y      = 0.0
        @clip_width  = @orig_width
        @clip_height = @orig_height
      else
        @path = path.to_s
        raise Error, "Image file `#{@path}` not found" unless File.exist?(@path)

        # Preserve user-provided values before image_create may overwrite them
        provided_width = @width
        provided_height = @height
        provided_rotate = @rotate
        Ext.image_create(self)

        @width = provided_width || @width
        @height = provided_height || @height
        @rotate = provided_rotate
      end

      @visible = visible
      self.add if add
    end

    # Re-rasterize the source at a new pixel size and update `width`/`height`.
    # For SVGs this re-runs the vector rasterizer so the image stays crisp at
    # the new size. For raster images it resamples the source to the new size
    # — useful for trimming GPU memory when displaying a large source small.
    # Called with no arguments, re-rasterizes at the current `width`/`height`
    # — handy after assigning to `width=`/`height=` to commit a fresh raster.
    def resize!(width = @width, height = @height)
      unless width.is_a?(Numeric) && height.is_a?(Numeric) && width.positive? && height.positive?
        raise Error, 'Image#resize! requires positive width and height'
      end

      Ext.image_resize(self, width, height)
      @width = width
      @height = height
      self
    end

    # The image's tint color. The image's own texture colors are multiplied
    # by this — `tint: 'red'` makes the image redder, not solid red.
    def tint
      @color
    end

    def tint=(c)
      @color = Color.new(c)
    end

    # Render the image. Called with overrides for one-shot rendering inside a
    # render block; with no arguments it draws the same frame the scene graph
    # does (delegating to `_render_scene`).
    def render(x: nil, y: nil, width: nil, height: nil, rotate: nil,
               tint: nil, opacity: nil)
      if x.nil? && y.nil? && width.nil? && height.nil? && rotate.nil? &&
         tint.nil? && opacity.nil?
        return _render_scene
      end

      Window.render_ready_check

      saved_x = @x
      saved_y = @y
      saved_width = @width
      saved_height = @height
      saved_rotate = @rotate
      saved_color = @color

      @x = x if x
      @y = y if y
      @width = width if width
      @height = height if height
      @rotate = rotate if rotate

      if tint || opacity
        @color = tint ? Color.new(tint) : Color.new(saved_color)
        @color.opacity = opacity if opacity
      end

      begin
        Ext.image_draw(self)
      ensure
        @x = saved_x
        @y = saved_y
        @width = saved_width
        @height = saved_height
        @rotate = saved_rotate
        @color = saved_color
      end
    end

    private

    # Scene-graph draw hook (see Renderable#_render_scene): `render` with no
    # overrides, minus its keyword handling — a zero-arg call into the
    # 7-keyword `render` still pays ~3.4µs of keyword setup on wasm mruby.
    def _render_scene
      _resolve_alignment
      Ext.image_draw(self)
    end
    public :_render_scene
  end
end
