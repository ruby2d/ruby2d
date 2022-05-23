# frozen_string_literal: true

# Ruby2D::PixmapAtlas

module Ruby2D
  #
  # A pixmap is a 2D grid of pixel data of fixed width and height. A pixmap atlas
  # is a dictionary of named pixmaps where each named pixmap is loaded once and can be re-used
  # multiple times without the overhead of repeated loading and multiple copies.
  class PixmapAtlas
    def initialize
      @atlas = {} # empty map
    end

    # Empty the atlas, eventually releasing all the loaded
    # pixmaps (except for any that are referenced elsewhere)
    def clear
      @atlas.clear
    end

    # Find a previosly loaded Pixmap in the atlas by name
    #
    # @param [String] name
    # @return [Pixmap, nil]
    def [](name)
      @atlas[name]
    end

    # Get the number of Pixmaps in the atlas
    def count
      @atlas.count
    end

    # Iterate through each Pixmap in the atlas
    def each(&block)
      @atlas.each(&block)
    end

    # Load a pixmap from an image +file_path+ and store it +as+ named for later lookup.
    #
    # @param [String] file_path The path to the image file to load as a +Pixmap+
    # @param [String] as The name to associated with the Pixmap; if +nil+ then +file_path+ is used +as+ the name
    #
    # @raise [Pixmap::InvalidImageFileError] if the image file cannot be loaded
    # @return [Pixmap] the new (or existing) Pixmap
    def load_and_keep_image(file_path, as: nil)
      name = as || file_path
      if @atlas.member? name
        @atlas[name]
      else
        pixmap = Pixmap.new file_path
        @atlas[name] = pixmap
      end
    end
  end
end
