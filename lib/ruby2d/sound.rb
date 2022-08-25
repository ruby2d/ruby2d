# frozen_string_literal: true

# Ruby2D::Sound

module Ruby2D
  # Sounds are intended to be short samples, played without interruption, like an effect.
  class Sound
    attr_reader :path
    attr_accessor :loop, :data

    #
    # Load a sound from a file
    # @param [String] path File to load the sound from
    # @param [true, false] loop If +true+ playback will loop automatically, default is +false+
    # @raise [Error] if file cannot be found or music could not be successfully loaded.
    def initialize(path, loop: false)
      raise Error, "Cannot find audio file `#{path}`" unless File.exist? path

      @path = path
      @loop = loop
      raise Error, "Sound `#{@path}` cannot be created" unless ext_init(@path)
    end

    # Play the sound
    def play
      ext_play
    end

    # Stop the sound
    def stop
      ext_stop
    end

    # Returns the length in seconds
    def length
      ext_length
    end

    # Get the volume of the sound
    def volume
      ext_get_volume
    end

    # Set the volume of the sound
    def volume=(volume)
      # Clamp value to between 0-100
      ext_set_volume(volume.clamp(0, 100))
    end

    # Get the volume of the sound mixer
    def self.mix_volume
      ext_get_mix_volume
    end

    # Set the volume of the sound mixer
    def self.mix_volume=(volume)
      # Clamp value to between 0-100
      ext_set_mix_volume(volume.clamp(0, 100))
    end
  end
end
