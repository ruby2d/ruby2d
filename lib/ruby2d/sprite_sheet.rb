# Ruby2D::SpriteSheet

module Ruby2D
  # A texture atlas / sprite sheet loaded from a Sparrow XML or TexturePacker
  # JSON file. Owns one shared `Image` so every `Sprite` built against the
  # sheet draws from the same GPU texture.
  class SpriteSheet
    attr_reader :path, :image_path, :texture

    # The sampling mode Sprites built from this sheet start with. Each copies
    # it at construction, so change it per Sprite after that.
    def scale_mode
      @texture.scale_mode
    end

    # Load a sprite sheet. `path` is the atlas file (`.xml` or `.json`); the
    # texture image referenced inside the atlas is resolved relative to that
    # file's directory. `scale_mode:` becomes the default for every Sprite
    # built from the sheet; a Sprite can still override it.
    def initialize(path, scale_mode: nil)
      @path = path.to_s
      raise Error, "SpriteSheet file `#{@path}` not found" unless File.exist?(@path)

      atlas = AtlasParser.parse_file(@path)
      @frames = atlas[:frames] || {}

      atlas_image = atlas[:image_path]
      raise Error, "SpriteSheet `#{@path}` does not specify an image path" unless atlas_image

      @image_path = resolve_image_path(@path, atlas_image)
      @texture = Image.new(@image_path, add: false, scale_mode: scale_mode)
    end

    # All frame names, in declaration order
    def frame_names
      @frames.keys
    end

    # Look up a frame's region by name. Always returns at least
    # `{ x:, y:, width:, height: }`. When the atlas carries trim or
    # rotation metadata, the hash also includes `source_width`,
    # `source_height`, `trim_x`, `trim_y`, and/or `rotated: true`.
    # Returns `nil` if no such frame exists.
    def frame(name)
      @frames[name.to_s]
    end
    alias [] frame

    # Whether the sheet contains a frame with the given name
    def frame?(name)
      @frames.key?(name.to_s)
    end

    private

    def resolve_image_path(atlas_path, image_name)
      # Prefer the texture sitting next to the atlas file — the documented
      # contract — so a like-named file in the process's working directory
      # can't shadow it. Only fall back to `image_name` as given (an absolute
      # path, or one relative to the working directory) when no atlas-relative
      # file exists.
      atlas_relative = File.join(File.dirname(atlas_path), image_name)
      return atlas_relative if File.exist?(atlas_relative)

      image_name
    end
  end

  # Naming alias — both names refer to the same class.
  TextureAtlas = SpriteSheet
end
