# Ruby2D::Sound

module Ruby2D
  class Sound

    attr_reader :path
    attr_accessor :data

    def initialize(path)
      unless File.exist? path
        raise Error, "Cannot find audio file `#{path}`"
      end
      @path = path
      unless ext_init(@path)
        raise Error, "Sound `#{@path}` cannot be created"
      end
    end

    # Play the sound
    def play
      ext_play
    end

  end
end
