# Ruby2D::Image

module Ruby2D
  #
  # A pixmap is a 2D grid of pixel data of fixed width and height. A pixmap atlas
  # is a dictionary of named pixmaps where each named pixmap is loaded once and can be re-used
  # multiple times without the overhead of repeated loading and multiple copies.
  class PixmapAtlas
    ##
    # Error when a name is already used
    class NameInUseError < StandardError
      def initialize(name)
        super("Name (#{name}) in use with another pixmap")
      end
    end

    def initialize
      @atlas = {} # empty map
    end

    # Empty the atlas, eventually releasing all the loaded
    # pixmaps (except for any that are referenced elsewhere)
    def clear
      @atlas.clear
    end

    def [](name)
      @atlas[name]
    end

    def count
      @atlas.count
    end

    def each(&block)
      @atlas.each(&block)
    end

    # Load a pixmap from an image +file+ and store it +as+ named for later lookup.
    #
    # @throw [NameInUseError] if the name to keep the image +as+ is already in use
    # @throw [Pixmap::InvalidImageFileError] if the image file cannot be loaded
    #
    # @return [Pixmap] the loaded pixmap
    def load_and_keep_image(file_path, as:)
      raise NameInUseError, as if @atlas.member? as

      pixmap = Pixmap.new file_path
      @atlas[as] = pixmap
    end
  end
end
