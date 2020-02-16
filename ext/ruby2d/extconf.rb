require 'mkmf'
require_relative '../../lib/ruby2d/cli/colorize'

S2D_VERSION = '1.2.0'  # Simple 2D minimum version required
$errors = []  # Holds errors

# Set the OS platform
case RUBY_PLATFORM
when /darwin/
  $platform = :macos
when /linux/
  $platform = :linux
  if `cat /etc/os-release` =~ /raspbian/
    $platform = :linux_rpi
  end
when /mingw/
  $platform = :windows
else
  $platform = nil
end


# Helper functions #############################################################

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
               "To install, follow the instructions at #{"ruby2d.com".bold}"
    print_errors; exit

  # Simple 2D installed, checking version
  else
    unless Gem::Version.new(`bash simple2d --version`) >= Gem::Version.new(S2D_VERSION)
      $errors << "Simple 2D needs to be updated for this version of Ruby 2D." <<
                 "Run the following, then try reinstalling this gem:\n" <<
                 "  simple2d update".bold
      print_errors; exit
    end
  end
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


# Check SDL libraries on Linux
def check_sdl_linux
  unless have_library('SDL2') && have_library('SDL2_image') && have_library('SDL2_mixer') && have_library('SDL2_ttf')

    $errors << "Couldn't find packages needed by Ruby 2D."

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


# Use the Simple 2D, SDL, and other libraries installed by the user (not those bundled with the gem)
def use_usr_libs
  check_s2d

  # Add flags
  set_rpi_flags
  add_flags(:c, '-I/usr/local/include')
  add_flags(:ld, `bash simple2d --libs`)
end


# Configure native extension ###################################################

# Build Ruby 2D native extention using libraries installed by user
# To use install flag: `gem install ruby2d -- libs`
if ARGV.include? 'libs'
  use_usr_libs

# Use libraries provided by the gem (default)
else
  add_flags(:c, '-std=c11')

  case $platform

  when :macos
    add_flags(:c, '-I../../assets/include')
    ldir = "#{Dir.pwd}/../../assets/macos/lib"

    add_flags(:ld, "#{ldir}/libsimple2d.a")
    add_flags(:ld, "#{ldir}/libSDL2.a #{ldir}/libSDL2_image.a #{ldir}/libSDL2_mixer.a #{ldir}/libSDL2_ttf.a")
    add_flags(:ld, "#{ldir}/libjpeg.a #{ldir}/libpng16.a #{ldir}/libtiff.a #{ldir}/libwebp.a")
    add_flags(:ld, "#{ldir}/libmpg123.a #{ldir}/libogg.a #{ldir}/libFLAC.a #{ldir}/libvorbis.a #{ldir}/libvorbisfile.a")
    add_flags(:ld, "#{ldir}/libfreetype.a")
    add_flags(:ld, "-Wl,-framework,Cocoa -Wl,-framework,ForceFeedback")

  when :linux, :linux_rpi
    check_sdl_linux
    simple2d_dir = "#{Dir.pwd}/../../assets/linux/simple2d"

    `(cd #{simple2d_dir} && make)`

    set_rpi_flags
    add_flags(:c, "-I#{simple2d_dir}/include")
    add_flags(:ld, "#{simple2d_dir}/build/libsimple2d.a -lSDL2 -lSDL2_image -lSDL2_mixer -lSDL2_ttf -lm")
    if $platform == :linux then add_flags(:ld, '-lGL') end

  when :windows
    add_flags(:c, '-I../../assets/include')
    add_flags(:ld, '-L../../assets/mingw/lib -lsimple2d -lSDL2 -lSDL2_image -lSDL2_mixer -lSDL2_ttf')
    add_flags(:ld, '-lmingw32 -lopengl32 -lglew32')

  # If can't detect the platform, use libraries installed by the user
  else
    use_usr_libs
  end
end

$LDFLAGS.gsub!(/\n/, ' ')  # remove newlines in flags, they can cause problems

# Create the Makefile
create_makefile('ruby2d/ruby2d')
