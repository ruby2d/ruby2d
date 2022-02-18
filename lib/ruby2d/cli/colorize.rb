# String#ruby2d_colorize

# Extend `String` to include some fancy colors
class String
  def ruby2d_colorize(c); "\e[#{c}m#{self}\e[0m" end
  def bold;    ruby2d_colorize('1')    end
  def info;    ruby2d_colorize('1;34') end
  def warn;    ruby2d_colorize('1;33') end
  def success; ruby2d_colorize('1;32') end
  def error;   ruby2d_colorize('1;31') end
end
