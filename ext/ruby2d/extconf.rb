require 'mkmf'
require_relative '../../lib/ruby2d/colorize'

S2D_VERSION = '1.1.0'  # Simple 2D minimum version required
$errors = []

def print_errors
  puts "
#{"== #{"Ruby 2D Installation Errors".error} =======================================\n"}
  #{$errors.join("\n  ")}\n
#{"======================================================================="}"
end

def check_s2d_version
  unless Gem::Version.new(`bash simple2d --version`) >= Gem::Version.new(S2D_VERSION)
    $errors << "Simple 2D needs to be updated for this version of Ruby 2D." <<
               "Run the following, then try reinstalling this gem:\n" <<
               "  simple2d update".bold
    print_errors
    exit
  end
end


# Install Simple 2D on supported platforms
case RUBY_PLATFORM

# macOS
when /darwin/

  # Simple 2D not installed
  if `which simple2d`.empty?

    # Homebrew not installed
    if `which brew`.empty?
      $errors << "Ruby 2D uses a native library called Simple 2D, which was not found." <<
                 "On macOS, it can be installed using Homebrew.\n" <<
                 "First, install #{"Homebrew".bold}. See instructions at #{"http://brew.sh".bold}" <<
                 "Then, run the following:\n" <<
                 "  brew tap simple2d/tap".bold <<
                 "  brew install simple2d".bold
      print_errors
      exit

    # Homebrew installed, instruct to install Simple 2D
    else
      $errors << "Ruby 2D uses a native library called Simple 2D, which was not found." <<
                 "Install it with Homebrew using:\n" <<
                 "  brew tap simple2d/tap".bold <<
                 "  brew install simple2d".bold
      print_errors
      exit
    end
  end

# Linux and Windows / MinGW
when /linux|mingw/

  # Simple 2D not installed
  if `which simple2d`.empty?
    $errors << "Ruby 2D uses a native library called Simple 2D, which was not found." <<
    "To install, follow the instructions at #{"ruby2d.com/learn".bold}"
    print_errors
    exit
  end
end


check_s2d_version

# Add flags
$CFLAGS << ' -std=c11 -I/usr/local/include'
if `cat /etc/os-release` =~ /raspbian/  # Raspberry Pi
  $CFLAGS << ' -I/opt/vc/include'
end
$LDFLAGS << ' ' << `bash simple2d --libs`
$LDFLAGS.gsub!(/\n/, ' ')  # remove newlines in flags, they cause problems

create_makefile('ruby2d/ruby2d')
