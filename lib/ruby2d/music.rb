# Ruby2D::Music

module Ruby2D
  class Music

    attr_reader :path
    attr_accessor :loop, :data

    def initialize(path)

      unless RUBY_ENGINE == 'opal'
        unless File.exist? path
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

    # Returns the previous volume setting, in percentage
    def self.volume
      self.ext_volume(-1)
    end

    # Set music volume, 0 to 100%
    def self.volume=(v)
      # If a negative value, volume will be 0
      if v < 0 then v = 0 end
      self.ext_volume(v)
    end

    # Alias instance methods to class methods
    def volume; Music.volume end
    def volume=(v); Music.volume=(v) end

    # Fade out music over provided milliseconds
    def fadeout(ms)
      ext_fadeout(ms)
    end

  end
end
