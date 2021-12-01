require 'mkmf'
require_relative '../../lib/ruby2d/cli/colorize'
require_relative '../../lib/ruby2d/cli/platform'

$errors = []  # Holds errors

# Helper functions #############################################################

# Print installation errors
def print_errors
  puts "
#{"== #{"Ruby 2D Installation Errors".error} =======================================\n"}
  #{$errors.join("\n  ")}\n
#{"======================================================================"}"
end


# Add compiler and linker flags
def add_flags(type, flags)
  case type
  when :c
    $CFLAGS << " #{flags} "
  when :ld
    $LDFLAGS << " #{flags} "
  end
end


# Check for SDL libraries
def check_sdl
  unless have_library('SDL2') && have_library('SDL2_image') && have_library('SDL2_mixer') && have_library('SDL2_ttf')

    $errors << "Couldn't find packages needed by Ruby 2D."

    case $platform
    when :linux, :linux_rpi
      # Fedora and CentOS
      if system('which yum')
        $errors << "Install the following packages using `yum` (or `dnf`) and try again:\n" <<
        "  SDL2-devel SDL2_image-devel SDL2_mixer-devel SDL2_ttf-devel".bold

      # Arch
      elsif system('which pacman')
        $errors << "Install the following packages using `pacman` and try again:\n" <<
        "  sdl2 sdl2_image sdl2_mixer sdl2_ttf".bold

      # openSUSE
      elsif system('which zypper')
        $errors << "Install the following packages using `zypper` and try again:\n" <<
        "  libSDL2-devel libSDL2_image-devel libSDL2_mixer-devel libSDL2_ttf-devel".bold

      # Ubuntu, Debian, and Mint
      # `apt` must be last because openSUSE has it aliased to `zypper`
      elsif system('which apt')
        $errors << "Install the following packages using `apt` and try again:\n" <<
        "  libsdl2-dev libsdl2-image-dev libsdl2-mixer-dev libsdl2-ttf-dev".bold
      end
    when :bsd
      $errors << "Install the following packages using `pkg` and try again:\n" <<
      "  sdl2 sdl2_image sdl2_mixer sdl2_ttf".bold
    end

    $errors << "" << "See #{"ruby2d.com".bold} for additional help."
    print_errors; exit
  end
end


# Set Raspberry Pi flags
def set_rpi_flags
  if $platform == :linux_rpi
    add_flags(:c, '-I/opt/vc/include')
    add_flags(:ld, '-L/opt/vc/lib -lbrcmGLESv2')
  end
end


# Use SDL and other libraries installed by the user (not those bundled with the gem)
def use_usr_libs
  # Add flags
  set_rpi_flags
  add_flags(:c, '-I/usr/local/include')
end


# Configure native extension ###################################################

# Build Ruby 2D native extention using libraries installed by user
# To use install flag: `gem install ruby2d -- libs`
if ARGV.include? 'libs'
  use_usr_libs

# Use libraries provided by the gem (default)
else
  add_flags(:c, '-std=c11')

  case $RUBY2D_PLATFORM

  when :macos
    add_flags(:c, '-I../../assets/include')
    ldir = "#{Dir.pwd}/../../assets/macos/universal"

    add_flags(:ld, "#{ldir}/libSDL2.a #{ldir}/libSDL2_image.a #{ldir}/libSDL2_mixer.a #{ldir}/libSDL2_ttf.a")
    add_flags(:ld, "#{ldir}/libjpeg.a #{ldir}/libpng16.a #{ldir}/libtiff.a #{ldir}/libwebp.a")
    add_flags(:ld, "#{ldir}/libmpg123.a #{ldir}/libogg.a #{ldir}/libFLAC.a #{ldir}/libvorbis.a #{ldir}/libvorbisfile.a #{ldir}/libmodplug.a")
    add_flags(:ld, "#{ldir}/libfreetype.a")
    add_flags(:ld, "-Wl,-framework,Cocoa -Wl,-framework,GameController -Wl,-framework,ForceFeedback")

  when :linux, :linux_rpi, :bsd
    check_sdl

    set_rpi_flags
    add_flags(:ld, "-lSDL2 -lSDL2_image -lSDL2_mixer -lSDL2_ttf -lm")
    if $RUBY2D_PLATFORM == :linux then add_flags(:ld, '-lGL') end

  when :windows
    add_flags(:c, '-I../../assets/include')
    add_flags(:ld, '-L../../assets/mingw/lib -lSDL2 -lSDL2_image -lSDL2_mixer -lSDL2_ttf')
    add_flags(:ld, '-lmingw32 -lopengl32 -lglew32')

  # If can't detect the platform, use libraries installed by the user
  else
    use_usr_libs
  end
end

$LDFLAGS.gsub!(/\n/, ' ')  # remove newlines in flags, they can cause problems

# Create Makefile
create_makefile('ruby2d/ruby2d')
