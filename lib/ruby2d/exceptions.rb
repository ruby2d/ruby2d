# exceptions.rb

module Ruby2D
  class Error < StandardError
    def initialize(msg)
      super(msg)
      puts msg
      puts "Occurred in:"
      puts "  " + caller.last, "\n"
    end
  end
end
