# Ruby2D::Music

module Ruby2D
  class Music

    attr_reader :path
    attr_accessor :loop, :data

    def initialize(path)

      unless File.exists? path
        raise Error, "Cannot find audio file `#{path}`"
      end

      @path = path
      @loop = false
      ext_init(path)
    end

    # Play the music
    def play
      ext_play
    end

    # Pause the music
    def pause
      ext_pause
    end

    # Resume paused music
    def resume
      ext_resume
    end

    # Stop playing the music, start at beginning
    def stop
      ext_stop
    end

    # Fade out music over provided milliseconds
    def fadeout(ms)
      ext_fadeout(ms)
    end

  end
end
