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

    # Returns the length in seconds
    def length
      ext_length
    end

    # Get the volume of the sound
    def volume
      ext_get_volume
    end

    # Set the volume of the sound
    def volume=(v)
      # Clamp value to between 0-100
      if v < 0 then v = 0 end
      if v > 100 then v = 100 end
      ext_set_volume(v)
    end

    # Get the volume of the sound mixer
    def self.mix_volume
      ext_get_mix_volume
    end

    # Set the volume of the sound mixer
    def self.mix_volume=(v)
      # Clamp value to between 0-100
      if v < 0 then v = 0 end
      if v > 100 then v = 100 end
      ext_set_mix_volume(v)
    end
  end
end
