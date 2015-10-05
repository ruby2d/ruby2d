require 'mkmf'

errors = []

class String
  def colorize(c); "\e[#{c}m#{self}\e[0m" end
  def error; colorize('1;31') end
  def bold; colorize('1') end
end

def print_errors(errors)
  puts "
#{"== Ruby 2D Installation Errors =============================".bold}
  
  Ruby 2D found some problems and was not installed:
  
    #{errors.join("\n  ").error}
  
#{"============================================================".bold}

"
end


# Add space to flags
$LDFLAGS << ' '

# Mac OS
if RUBY_PLATFORM =~ /darwin/
  
  # if `which simple2d`.empty? && has brew
  #   brew tap simple2d/tap
  #   brew install simple2d
  # end
  
  if `which simple2d`.empty?
    errors << "Simple 2D not found!"
    print_errors(errors)
    exit
  end
  
  $LDFLAGS << `simple2d --libs`
  
# Windows
elsif RUBY_PLATFORM =~ /mingw/
  
# Linux
else
  
  # if `which simple2d`.empty?
  #   install simple2d using script
  # end
  
  $LDFLAGS << `simple2d --libs`
  
end

# Remove any newlines in flags
$LDFLAGS.gsub!(/\n/, ' ')

create_makefile('ruby2d/ruby2d')
