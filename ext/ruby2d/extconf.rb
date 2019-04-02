require 'mkmf'
require_relative '../../lib/ruby2d/colorize'

S2D_VERSION = '1.1.0'  # Simple 2D minimum version required
$errors = []  # Array to capture errors

# Print installation errors
def print_errors
  puts "
#{"== #{"Ruby 2D Installation Errors".error} =======================================\n"}
  #{$errors.join("\n  ")}\n
#{"======================================================================"}"
end

# Check that Simple 2D is installed and meets minimum version requirements
def check_s2d

  # Simple 2D not installed
  if `which simple2d`.empty?
    $errors << "Ruby 2D uses a native library called Simple 2D, which was not found." <<
    "To install, follow the instructions at #{"ruby2d.com/learn".bold}"
    print_errors
    exit

  # Simple 2D installed, checking version
  else
    unless Gem::Version.new(`bash simple2d --version`) >= Gem::Version.new(S2D_VERSION)
      $errors << "Simple 2D needs to be updated for this version of Ruby 2D." <<
                 "Run the following, then try reinstalling this gem:\n" <<
                 "  simple2d update".bold
      print_errors
      exit
    end
  end
end

# Use the Simple 2D, SDL, and other libraries installed by the user (not those bundled with the gem)
def use_usr_libs
  check_s2d

  # Add flags
  $CFLAGS << ' -std=c11 -I/usr/local/include'
  if `cat /etc/os-release` =~ /raspbian/  # Raspberry Pi
    $CFLAGS << ' -I/opt/vc/include'
  end
  $LDFLAGS << ' ' << `bash simple2d --libs`
  $LDFLAGS.gsub!(/\n/, ' ')  # remove newlines in flags, they cause problems
end


# Build Ruby 2D native extention using libraries installed by user
# To use install flag: `gem install ruby2d -- libs`
if ARGV.include? 'libs'
  use_usr_libs

# Use libraries provided by the gem (default)
else
  $CFLAGS << ' -std=c11 -I../../assets/include'
  case RUBY_PLATFORM

  # macOS
  when /darwin/
    # $LDFLAGS << " -L../../assets/macos/lib -lsimple2d -lSDL2 -lSDL2_image -lSDL2_mixer -lSDL2_ttf -ljpeg -lpng16 -ltiff -lwebp -lmpg123 -logg -lflac -lvorbis -lvorbisfile -lfreetype -Wl,-framework,Cocoa -Wl,-framework,ForceFeedback"

    ldir = "#{Dir.pwd}/../../assets/macos/lib"
    $LDFLAGS << " #{ldir}/libsimple2d.a #{ldir}/libSDL2.a #{ldir}/libSDL2_image.a #{ldir}/libSDL2_mixer.a #{ldir}/libSDL2_ttf.a \
                  #{ldir}/libjpeg.a #{ldir}/libpng16.a #{ldir}/libtiff.a #{ldir}/libwebp.a \
                  #{ldir}/libmpg123.a #{ldir}/libogg.a #{ldir}/libflac.a #{ldir}/libvorbis.a #{ldir}/libvorbisfile.a \
                  #{ldir}/libfreetype.a -Wl,-framework,Cocoa -Wl,-framework,ForceFeedback"

  # Linux
  when /linux/
    # TODO: Implement static compilation for Linux
    use_usr_libs

  # Windows / MinGW
  when /mingw/
    $LDFLAGS << " -L../../assets/mingw/lib -lsimple2d -lSDL2 -lSDL2_image -lSDL2_mixer -lSDL2_ttf -lmingw32 -lopengl32 -lglew32"

  # If can't detect the platform, use libraries installed by the user
  else
    use_usr_libs
  end
end


# Create the Makefile
create_makefile('ruby2d/ruby2d')
