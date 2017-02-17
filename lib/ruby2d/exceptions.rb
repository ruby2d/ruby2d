# exceptions.rb

module Ruby2D
  class Error < StandardError
    def colorize(msg, c); "\e[#{c}m#{msg}\e[0m" end
    def error(msg); colorize(msg, '4;31') end
    def bold(msg); colorize(msg, '1') end
    
    def initialize(msg)
      super(msg)
      puts error("\nRuby 2D Error:") << " #{msg}" <<
      bold("\nOccurred in:\n  #{caller.last}\n")
    end
  end
end
