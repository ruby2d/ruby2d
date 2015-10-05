# sound.rb

module Ruby2D
  class Sound
    
    def initialize(window, path)
      unless File.exists? path
        raise Error, "Cannot find sound file!"
      end
      window.create_audio(self, path)
      @window, @path = window, path
    end
    
    def play
      @window.play_audio(self)
    end
    
  end
end
