require 'mkmf'

S2D_VERSION = '0.4.1'  # Simple 2D minimum version required
$errors = []

class String
  def colorize(c); "\e[#{c}m#{self}\e[0m" end
  def bold; colorize('1')   end
  def red; colorize('1;31') end
end

def print_errors
  puts "
#{"== #{"Ruby 2D Installation Errors".red} =====================================\n"}
  #{$errors.join("\n  ")}\n
#{"===================================================================="}"
end

def check_s2d_version
  unless Gem::Version.new(`simple2d --version`) >= Gem::Version.new(S2D_VERSION)
    $errors << "Simple 2D needs to be updated for this version of Ruby 2D." <<
               "Run the following, then try reinstalling this gem:\n" <<
               "  simple2d update".bold
    print_errors
    exit
  end
end


# Install Simple 2D on supported platforms

# OS X
if RUBY_PLATFORM =~ /darwin/
  
  # Simple 2D not installed
  if `which simple2d`.empty?
    
    # Homebrew not installed
    if `which brew`.empty?
      $errors << "Ruby 2D uses a native library called Simple 2D." <<
                 "On OS X, this can be installed using Homebrew.\n" <<
                 "First, install #{"Homebrew".bold}. See instructions at #{"http://brew.sh".bold}" <<
                 "Then, run the following:\n" <<
                 "  brew tap simple2d/tap".bold <<
                 "  brew install simple2d".bold
      print_errors
      exit
      
    # Homebrew installed, instruct to install Simple 2D
    else
      $errors << "Ruby 2D uses a native library called Simple 2D." <<
                 "Install with Homebrew using:\n" <<
                 "  brew tap simple2d/tap".bold <<
                 "  brew install simple2d".bold
      print_errors
      exit
    end
  end
  
# Linux
elsif RUBY_PLATFORM =~ /linux/
  
  # Simple 2D not installed
  if `which simple2d`.empty?
    $errors << "Ruby 2D uses a native library called Simple 2D.\n" <<
               "To install Simple 2D on Linux, follow the instructions" <<
               "in the README: #{"https://github.com/simple2d/simple2d".bold}"
    print_errors
    exit
  end
  
  $CFLAGS << ' -std=c99'

# Windows / MinGW
elsif RUBY_PLATFORM =~ /mingw/
  # Add flags
  $CFLAGS  << ' -std=c99 -I/usr/local/include'
  $LDFLAGS << ' -Dmain=SDL_main -L/usr/local/lib -lmingw32 -lsimple2d -lSDL2main -lSDL2 -lSDL2_image -lSDL2_mixer -lSDL2_ttf -lopengl32 -lglew32 -mwindows'
end

unless RUBY_PLATFORM =~ /mingw/
  # Simple 2D installed, check version
  check_s2d_version

  # Add flags
  $LDFLAGS << ' ' << `simple2d --libs`
end


$LDFLAGS.gsub!(/\n/, ' ')  # Remove newlines in flags, they cause problems

create_makefile('ruby2d/ruby2d')
