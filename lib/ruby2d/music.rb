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
      
      init(path)
      @path = path
      @loop = false
    end
    
  end
end
