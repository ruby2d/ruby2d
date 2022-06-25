# frozen_string_literal: true

# Ruby2D::Pixmap

module Ruby2D
  # Error when failed to load an image
  class InvalidImageFileError < Ruby2D::Error
    def initialize(file_path)
      super("Failed to load image file: #{file_path}")
    end
  end

  # Error finding image file
  class UnknownImageFileError < Ruby2D::Error
    def initialize(file_path)
      super "Cannot find image file `#{file_path}`"
    end
  end

  #
  # A pixmap represents an image made up of pixel data of fixed width and height.
  class Pixmap
    attr_reader :width, :height, :path

    def initialize(file_path)
      file_path = file_path.to_s
      raise UnknownImageFileError, file_path unless File.exist? file_path

      ext_load_pixmap(file_path)
      raise InvalidImageFileError, file_name unless @ext_pixel_data

      @path = file_path
    end

    def texture
      @texture ||= Texture.new(@ext_pixel_data, @width, @height)
    end
  end
end
