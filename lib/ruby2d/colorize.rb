# String#colorize

# Extend `String` to include some fancy colors
class String
  def colorize(c); "\e[#{c}m#{self}\e[0m" end
  def bold;  colorize('1')    end
  def info;  colorize('1;34') end
  def warn;  colorize('1;33') end
  def error; colorize('1;31') end
end
