# sound.rb

module Ruby2D
  class Sound
    
    attr_accessor :data
    attr_reader :path
    
    def initialize(path)
      
      unless RUBY_ENGINE == 'opal'
        unless File.exists? path
          raise Error, "Cannot find audio file `#{path}`"
        end
      end
      
      init(path)
      @path = path
    end
    
  end
end
