# Ruby2D::Tileset

module Ruby2D
  # An image containing multiple tiles that can be drawn at various positions
  class Tileset
    DEFAULT_TINT = Color.new([1.0, 1.0, 1.0, 1.0])

    include Renderable

    # Tileset uses `tint` instead of `color` — the tileset has its own pixel
    # data in the source texture; tint multiplies all placed tiles when drawn
    # (white = untinted).
    undef_method :color, :color=, :colour, :colour=

    # The tint color, multiplied against the texture. Defaults to white.
    # Copy `DEFAULT_TINT` on first read so each instance owns its tint —
    # otherwise two default-tinted tilesets would share (and mutate) the
    # single class-level Color.
    def tint
      @tint ||= Color.new(DEFAULT_TINT)
    end

    def tint=(c)
      @tint = Color.new(c)
    end

    # Create a tileset from an image
    def initialize(path, tile_width: 32, tile_height: 32, z: 0,
                   padding: 0, spacing: 0,
                   scale: 1, add: true, visible: true)
      # `scale` and the tile dimensions feed the UV denominator
      # (`@scaled_*` sizes); a non-positive value collapses them to zero and
      # divides into NaN/Inf texture coordinates, so reject it up front.
      unless scale.is_a?(Numeric) && scale.positive?
        raise ArgumentError, "Tileset scale must be positive, got #{scale}"
      end
      unless tile_width.is_a?(Numeric) && tile_width.positive?
        raise ArgumentError, "Tileset tile_width must be positive, got #{tile_width}"
      end
      unless tile_height.is_a?(Numeric) && tile_height.positive?
        raise ArgumentError, "Tileset tile_height must be positive, got #{tile_height}"
      end

      @path = path.to_s

      # Initialize the tileset texture image (not added to the window)
      @texture = Image.new(@path, add: false)
      # The tile UV coordinates are normalized against the source texture's
      # true pixel dimensions, so `@width`/`@height` always track the texture.
      @width = @texture.width
      @height = @texture.height
      @z = z

      @tiles = {}
      @tile_definitions = {}
      # Cached per-frame draw batch (geometry only; tint is applied separately
      # in C each frame). Rebuilt lazily in `render` whenever a placement
      # changes — see `mark_batch_dirty`.
      @coords_batch = []
      @tex_coords_batch = []
      @batch_dirty = true
      @padding = padding
      @spacing = spacing
      @x = 0
      @y = 0
      @tile_width = tile_width
      @tile_height = tile_height
      @scale = scale

      calculate_scaled_sizes

      @visible = visible
      self.add if add
    end

    # Define a named tile type at the given grid position in the tileset image
    def define(name, x, y, rotate: 0, flip: nil)
      @tile_definitions[name] = { x: x, y: y, rotate: rotate, flip: flip }
    end

    # Place a named tile at one or more world coordinates. `coordinates` is an
    # array of `[x, y]` pairs. Existing placements at the same coordinate are
    # replaced.
    def place(name, coordinates)
      coordinates.each { |x, y| place_one(name, x, y) }
    end

    # Place a single tile at (x, y), replacing any existing placement
    def []=(x, y, name)
      place_one(name, x, y)
    end

    # Look up the tile name placed at (x, y), or nil if none
    def [](x, y)
      placement = @tiles[[x, y]]
      placement && placement.fetch(:name)
    end

    # Remove the placement at (x, y)
    def delete(x, y)
      removed = @tiles.delete([x, y])
      mark_batch_dirty if removed
      removed
    end

    # Remove all placements
    def clear
      @tiles = {}
      mark_batch_dirty
    end

    # Render the tileset. Called with no arguments from the scene-graph loop,
    # or from a render block for one-shot rendering.
    def render
      Window.render_ready_check
      return if @tiles.empty?

      # Batch every placed tile into one draw call: they share the source
      # texture and tint, so the per-tile geometry (memoized in each Vertices)
      # is collected and handed to a single `SDL_RenderGeometry` pass. The
      # collected batch is cached and only rebuilt when a placement changes,
      # so a static tile field costs nothing per frame beyond the native draw
      # — worth ~2.6× on the `tiles_static` render slice, so keep the guard.
      if @batch_dirty
        @coords_batch.clear
        @tex_coords_batch.clear
        @tiles.each_value do |placement|
          vertices = placement.fetch(:vertices)
          @coords_batch << vertices.coordinates
          @tex_coords_batch << vertices.texture_coordinates
        end
        @batch_dirty = false
      end

      Ext.image_draw_quads(@texture, @coords_batch, @tex_coords_batch, tint)
    end

    # Scene-graph draw hook (see Renderable#_render_scene). Tileset's `render`
    # is already zero-arg, so the hook is the same method under the scene name.
    alias_method :_render_scene, :render

    private

    def place_one(name, x, y)
      tile_def = @tile_definitions.fetch(name) do
        raise Error, "Tile `#{name}` is not defined; call `define(...)` first"
      end
      crop = calculate_tile_crop(tile_def)

      # Use Vertices object for tile placement so we can use them
      # directly when drawing the textures instead of making them for
      # every tile placement for each draw, and re-use the crop from
      # the tile definition
      vertices = Vertices.new(
        x, y,
        @scaled_tile_width, @scaled_tile_height,
        tile_def.fetch(:rotate),
        crop: crop,
        flip: tile_def.fetch(:flip)
      )

      @tiles[[x, y]] = { name: name, vertices: vertices }
      mark_batch_dirty
    end

    # Invalidate the cached draw batch so the next `render` rebuilds it. Called
    # from every placement mutation (`place_one`, `delete`, `clear`).
    def mark_batch_dirty
      @batch_dirty = true
    end

    def calculate_tile_crop(tile_def)
      # Re-use if crop has already been calculated
      return tile_def.fetch(:scaled_crop) if tile_def.key?(:scaled_crop)

      # Calculate the crop for each tile definition the first time a tile
      # is placed, so that we can later re-use when placing tiles,
      # avoiding creating the crop object for every placement.
      tile_def[:scaled_crop] = {
        x: @scaled_padding + (tile_def.fetch(:x) * (@scaled_spacing + @scaled_tile_width)),
        y: @scaled_padding + (tile_def.fetch(:y) * (@scaled_spacing + @scaled_tile_height)),
        width: @scaled_tile_width,
        height: @scaled_tile_height,
        image_width: @scaled_width,
        image_height: @scaled_height
      }.freeze
    end

    def calculate_scaled_sizes
      @scaled_padding = @padding * @scale
      @scaled_spacing = @spacing * @scale
      @scaled_tile_width = @tile_width * @scale
      @scaled_tile_height = @tile_height * @scale
      @scaled_width = @width * @scale
      @scaled_height = @height * @scale
    end

  end
end
