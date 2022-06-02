# frozen_string_literal: true

# Ruby2D::Music

module Ruby2D
  # Music is for longer pieces which can be played, paused, stopped, resumed,
  # and faded out, like a background soundtrack.
  class Music
    attr_reader :path
    attr_accessor :loop, :data

    #
    # Load music from a file
    # @param [String] path File to load the music from
    # @param [true, false] loop If +true+ playback will loop automatically, default is +false+
    # @raise [Error] if file cannot be found or music could not be successfully loaded.
    def initialize(path, loop: false)
      raise Error, "Cannot find audio file `#{path}`" unless File.exist? path

      @path = path
      @loop = loop
      raise Error, "Music `#{@path}` cannot be created" unless ext_init(@path)
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

    class << self
      # Returns the volume, in percentage
      def volume
        ext_get_volume
      end

      # Set music volume, 0 to 100%
      def volume=(volume)
        # Clamp value to between 0-100
        ext_set_volume(volume.clamp(0, 100))
      end
    end

    # Alias instance methods to class methods
    def volume
      Music.volume
    end

    def volume=(volume)
      Music.volume = (volume)
    end

    # Fade out music over provided milliseconds
    def fadeout(milliseconds)
      ext_fadeout(milliseconds)
    end

    # Returns the length in seconds
    def length
      ext_length
    end
  end
end
