module Ruby2D
  class Audio
    attr_reader :path

    # Create an audio object from a file
    def initialize(path, loop: false)
      @path = path.to_s
      raise Error, "Cannot find audio file `#{@path}`" unless File.exist? @path

      @loop = loop ? true : false
      @ext_audio = Ext.audio_load(@path)
    end

    # Play the sound
    def play
      Ext.audio_play(@ext_audio, @loop)
    end

    # Pause the music
    def pause
      Ext.audio_pause(@ext_audio)
    end

    # Resume paused music
    def resume
      Ext.audio_resume(@ext_audio)
    end

    # Stop the sound
    def stop(ms_fade = 0)
      Ext.audio_stop(@ext_audio, ms_fade)
    end

    # Whether the audio loops on play
    def looping?
      @loop
    end

    # Set looping
    def loop=(value)
      @loop = value ? true : false
      Ext.audio_set_loop(@ext_audio, @loop)
    end

    # Returns the length in seconds
    def length
      Ext.audio_length(@ext_audio)
    end

    # Get the volume of the sound, 0.0 to 1.0
    def volume
      Ext.audio_get_volume(@ext_audio)
    end

    # Set the volume of the sound, 0.0 to 1.0
    def volume=(volume)
      Ext.audio_set_volume(@ext_audio, volume.clamp(0.0, 1.0))
    end

    class << self
      # Get the mixer volume, 0.0 to 1.0
      def volume
        Ext.audio_get_mixer_volume
      end

      # Set the mixer volume, 0.0 to 1.0
      def volume=(volume)
        Ext.audio_set_mixer_volume(volume.clamp(0.0, 1.0))
      end
    end

  end
end
