# Ruby2D::Sound

module Ruby2D
  class Sound

    attr_reader :path
    attr_accessor :data

    def initialize(path)

      unless File.exists? path
        raise Error, "Cannot find audio file `#{path}`"
      end

      @path = path
      ext_init(path)
    end

    # Play the sound
    def play
      ext_play
    end

  end
end
