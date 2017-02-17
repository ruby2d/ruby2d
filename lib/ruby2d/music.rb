# music.rb

module Ruby2D
  class Music
    
    attr_accessor :data, :loop
    attr_reader :path
    
    def initialize(path)
      # TODO: Check if file exists
      init(path)
      @path = path
      @loop = false
    end
    
  end
end
