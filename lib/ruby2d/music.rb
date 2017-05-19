# music.rb

module Ruby2D
  class Music

    attr_accessor :data, :loop
    attr_reader :path

    def initialize(path)

      unless RUBY_ENGINE == 'opal'
        unless File.exists? path
          raise Error, "Cannot find audio file `#{path}`"
        end
      end

      @path = path
      @loop = false
      ext_music_init(path)
    end

    def play
      ext_music_play
    end

    def pause
      ext_music_pause
    end

    def resume
      ext_music_resume
    end

    def stop
      ext_music_stop
    end

    def fadeout(ms)
      ext_music_fadeout(ms)
    end
  end
end
