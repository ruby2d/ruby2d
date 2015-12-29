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
  
  #{"Ruby 2D found some problems and was not installed:".error}
  
  #{errors.join("\n  ")}
  
#{"============================================================".bold}"
end


# OS X
if RUBY_PLATFORM =~ /darwin/
  
  # Simple 2D not installed
  if `which simple2d`.empty?
    # Homebrew not installed, print and quit
    if `which brew`.empty?
      errors << "Ruby 2D uses a library called Simple 2D." <<
                "On OS X, this can be installed using Homebrew." <<
                "Install Homebrew, then try installing this gem again.\n" <<
                "Learn more at http://brew.sh"
      print_errors(errors)
      exit
    # Install Simple 2D using Homebrew
    else
      `brew tap simple2d/tap`
      `brew install simple2d`
    end
    
  # Simple 2D installed, update to latest version
  else
    # Homebrew not installed
    if `which brew`.empty?
      # TODO: Check for latest version manually and update
    # Homebrew installed, get latest version of Simple 2D
    else
      # An alternative, but slower and updates all formulas:
      #   `brew update`
      #   `brew upgrade simple2d`
      
      `brew untap simple2d/tap`
      `brew tap simple2d/tap`
      `brew upgrade simple2d`
    end
  end
  
# Linux
elsif RUBY_PLATFORM =~ /linux/
  # If Simple 2D not installed
  if `which simple2d`.empty?
    errors << "Ruby 2D uses a library called Simple 2D." <<
              "There's a script to make installation easy on Linux.\n" <<
              "Follow the instructions in the README to get started:" <<
              "  https://github.com/simple2d/simple2d"
    print_errors(errors)
    exit
  end
  
# Windows
elsif RUBY_PLATFORM =~ /mingw/
  puts "Ruby 2D doesn't support Windows yet :("
  exit
end


$LDFLAGS << ' ' << `simple2d --libs`
$LDFLAGS.gsub!(/\n/, ' ')  # remove newlines in flags, they cause problems

create_makefile('ruby2d/ruby2d')
