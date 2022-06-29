# frozen_string_literal: true

# Ruby2D::Tileset

module Ruby2D
  # Tilesets are images containing multiple unique tiles. These tiles can be drawn to the
  # screen multiple times in interesting combinations to produce things like backgrounds
  # or draw larger objects.
  class Tileset
    DEFAULT_COLOR = Color.new([1.0, 1.0, 1.0, 1.0])

    include Renderable

    # Setup a Tileset with an image.
    # @param path [#to_s] The location of the file to load as an image.
    # @param width [Numeric] The +width+ of image, or default is width from image file
    # @param height [Numeric] The +height+ of image, or default is height from image file
    # @param z [Numeric]
    # @param padding [Numeric]
    # @param spacing [Numeric]
    # @param tile_width [Numeric] Width of each tile in pixels
    # @param tile_height [Numeric] Height of each tile in pixels
    # @param scale [Numeric] Default is 1
    # @param show [Boolean] If +true+ the image is added to +Window+ automatically.
    def initialize(path, tile_width: 32, tile_height: 32, atlas: nil,
                   width: nil, height: nil, z: 0,
                   padding: 0, spacing: 0,
                   scale: 1, show: true)
      @path = path.to_s

      # Initialize the tileset texture
      # Consider input pixmap atlas if supplied to load image file
      @texture = Image.load_image_as_texture @path, atlas: atlas
      @width = width || @texture.width
      @height = height || @texture.height
      @z = z

      @tiles = []
      @tile_definitions = {}
      @padding = padding
      @spacing = spacing
      @tile_width = tile_width
      @tile_height = tile_height
      @scale = scale

      _calculate_scaled_sizes

      add if show
    end

    # Define and name a tile in the tileset image by its position. The actual tiles
    # to be drawn are declared using {#set_tile}
    #
    # @param name [String] A unique name for the tile in the tileset
    # @param x [Numeric] Column position of the tile
    # @param y [Numeric] Row position of the tile
    # @param rotate [Numeric] Angle of the title when drawn, default is 0
    # @param flip [nil, :vertical, :horizontal, :both] Direction to flip the tile if desired
    def define_tile(name, x, y, rotate: 0, flip: nil)
      @tile_definitions[name] = { x: x, y: y, rotate: rotate, flip: flip }
    end

    # Select and "stamp" or set/place a tile to be drawn
    # @param name [String] The name of the tile defined using +#define_tile+
    # @param coordinates [Array<{"x", "y" => Numeric}>] one or more +{x:, y:}+ coordinates to draw the tile
    def set_tile(name, coordinates)
      tile_def = @tile_definitions.fetch(name)
      crop = _calculate_tile_crop(tile_def)

      coordinates.each do |coordinate|
        # Use Vertices object for tile placement so we can use them
        # directly when drawing the textures instead of making them for
        # every tile placement for each draw, and re-use the crop from
        # the tile definition
        vertices = Vertices.new(
          coordinate.fetch(:x), coordinate.fetch(:y),
          @scaled_tile_width, @scaled_tile_height,
          tile_def.fetch(:rotate),
          crop: crop,
          flip: tile_def.fetch(:flip)
        )
        # Remember the referenced tile for if we ever want to recalculate
        # them all due to change to scale etc (currently n/a since
        # scale is immutable)
        @tiles.push({
                      tile_def: tile_def,
                      vertices: vertices
                    })
      end
    end

    # Removes all stamped tiles so nothing is drawn.
    def clear_tiles
      @tiles = []
    end

    def draw
      Window.render_ready_check

      render
    end

    private

    def _calculate_tile_crop(tile_def)
      # Re-use if crop has already been calculated
      return tile_def.fetch(:scaled_crop) if tile_def.key?(:scaled_crop)

      # Calculate the crop for each tile definition the first time a tile
      # is placed/set, so that we can later re-use when placing tiles,
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

    def _calculate_scaled_sizes
      @scaled_padding = @padding * @scale
      @scaled_spacing = @spacing * @scale
      @scaled_tile_width = @tile_width * @scale
      @scaled_tile_height = @tile_height * @scale
      @scaled_width = @width * @scale
      @scaled_height = @height * @scale
    end

    def render
      color = defined?(@color) ? @color : DEFAULT_COLOR
      @tiles.each do |placement|
        vertices = placement.fetch(:vertices)
        @texture.draw(
          vertices.coordinates, vertices.texture_coordinates, color
        )
      end
    end
  end
end
