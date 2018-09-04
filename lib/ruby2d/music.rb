# music.rb

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

    def play
      ext_play
    end

    def pause
      ext_pause
    end

    def resume
      ext_resume
    end

    def stop
      ext_stop
    end

    def fadeout(ms)
      ext_fadeout(ms)
    end
  end
end
