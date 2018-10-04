# Ruby2D::Music

module Ruby2D
  class Music

    attr_reader :path
    attr_accessor :loop, :data

    def initialize(path)

      unless RUBY_ENGINE == 'opal'
        unless File.exists? path
          raise Error, "Cannot find audio file `#{path}`"
        end
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

    # Set music volume, 0-100%. If no parameters given, return current volume.
    def volume(percentage = -1)
      (ext_volume(percentage)/128.0)*100
    end

    # Fade out music over provided milliseconds
    def fadeout(ms)
      ext_fadeout(ms)
    end

  end
end
