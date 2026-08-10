require 'mkmf'
require_relative '../../lib/ruby2d/deps_help'
require_relative '../../lib/ruby2d/cli/messages'
require_relative '../../lib/ruby2d/version'

# Helper functions #############################################################

# Add compiler and linker flags
def add_flags(type, flags)
  case type
  when :c  then $CFLAGS  << " #{flags} "
  when :ld then $LDFLAGS << " #{flags} "
  end
end

# Whether all four SDL3 static archives are present in a lib dir
SDL3_STATIC_LIBS = %w[libSDL3.a libSDL3_image.a libSDL3_mixer.a libSDL3_ttf.a].freeze
def static_libs_present?(lib_dir)
  SDL3_STATIC_LIBS.all? { |lib| File.exist?(File.join(lib_dir, lib)) }
end

# A `ruby2d setup` cache build is stamped with the ruby2d version that produced
# it; only reuse it for a matching version (a gem upgrade may pin newer SDL, so
# stale cache libs must not be linked against this version's headers/sources).
def cache_stamp_ok?(platform_dir)
  stamp = File.join(platform_dir, '.ruby2d-version')
  File.exist?(stamp) && File.read(stamp).strip == Ruby2D::VERSION
end

# Install without the native extension: write a do-nothing Makefile so `gem
# install` still completes, surface the recovery guidance, and exit cleanly. The
# user finishes with `ruby2d setup`, or a package-manager install + `gem pristine
# ruby2d`. Far friendlier than aborting the whole install — and the `ruby2d` CLI
# (including `setup`) keeps working without the extension.
def skip_build(reason, guidance: Ruby2D::DepsHelp.notice)
  notice = "Ruby 2D: #{reason}\n#{guidance}"

  # RubyGems runs extconf via Open3.popen2e and hides the captured stdout/stderr
  # on a successful (exit-0) install, so a plain `puts` never reaches the user.
  # Write straight to the controlling terminal — which popen2e leaves attached —
  # to surface the guidance on an interactive install. Best-effort: with no tty
  # (CI, piped) it's skipped, and the same guidance still shows at run time via
  # the LoadError rescue in lib/ruby2d/core.rb.
  begin
    File.open('/dev/tty', 'w') { |tty| tty.puts notice }
  rescue SystemCallError
    # no controlling terminal — rely on the runtime notice
  end
  puts notice # also captured to the build log (visible with `gem install --verbose`)

  File.write('Makefile', "all:\ninstall:\nclean:\n")
  exit 0
end

# Configure native extension ###################################################

# Resolve SDL3 static libraries: bundled with the gem first, then a `ruby2d
# setup` cache build (version-stamped). Mirrors lib/ruby2d/cli/build.rb.
#
# `--with-bundled-libs` marks a local `rake` install, where the working tree's
# `assets/platform` — packaged into the gem by `rake build` — is the only
# sanctioned source. This script can't otherwise tell a developer's `rake` from
# a user's `gem install`, and falling through to a `ruby2d setup` cache or to
# system SDL3 would silently link libraries the developer never built.
use_system_libs  = with_config('system-libs')
use_bundled_libs = with_config('bundled-libs')

static_platform =
  if use_system_libs
    nil
  elsif static_libs_present?(File.join(AssetsTarget.platform_dir, 'lib'))
    AssetsTarget.platform_dir
  elsif use_bundled_libs
    abort_error "No SDL3 static libraries for #{AssetsTarget.target_id} " \
                "in the gem's assets/platform.\n\n" \
                "  A local build links only those. Build them with #{'rake deps:build'.bold}, or\n" \
                "  link system-installed SDL3 instead with " \
                "#{'CONFIGURE_ARGS=--with-system-libs rake'.bold}.\n\n",
                spaced: true, indent: 2
  else
    cache = AssetsTarget.platform_dir(root: AssetsTarget.cache_root)
    cache if static_libs_present?(File.join(cache, 'lib')) && cache_stamp_ok?(cache)
  end

# Name the source that won. Bundled and cache libs both land in the branch
# above, and linking the wrong one is otherwise invisible in the build log.
if use_system_libs
  puts 'Ruby 2D: Using system-installed SDL3 libraries (--with-system-libs).'
elsif static_platform.nil?
  puts 'Ruby 2D: No bundled or cached static libraries; trying system-installed SDL3.'
elsif static_platform == AssetsTarget.platform_dir
  puts "Ruby 2D: Using the static libraries bundled in #{static_platform}."
else
  puts "Ruby 2D: Using `ruby2d setup` cache libraries in #{static_platform}."
end

if static_platform

  # Bundled or cache-built static libraries. List the dependent archives before
  # the base `libSDL3.a` so single-pass GNU ld (MinGW) resolves their symbols;
  # macOS's order-independent ld64 is unaffected.
  ldir        = File.join(static_platform, 'lib')
  include_dir = File.join(File.dirname(static_platform), 'include')

  add_flags(:c, "-I#{include_dir}")
  add_flags(:ld, "#{ldir}/libSDL3_image.a #{ldir}/libSDL3_mixer.a #{ldir}/libSDL3_ttf.a #{ldir}/libSDL3.a")

  case AssetsTarget.host_os
  when 'macos'
    # System frameworks the bundled SDL3 static libs reference. Must match the
    # authoritative list in assets/Rakefile (PLATFORM_LIBS) — a missing one
    # leaves unresolved symbols that only happen to resolve via CRuby's
    # `-Wl,-undefined,dynamic_lookup` at load time.
    frameworks = %w[
      AVFoundation AudioToolbox Carbon Cocoa CoreAudio CoreHaptics
      CoreMedia ForceFeedback GameController IOKit Metal QuartzCore
      UniformTypeIdentifiers
    ]
    add_flags(:ld, frameworks.map { |fw| "-Wl,-framework,#{fw}" }.join(' '))

  when 'windows'
    add_flags(:ld, '-lgdi32 -lhid -limm32 -lole32 -loleaut32 -lrpcrt4 -lsetupapi -lusp10 -luuid -lversion -lwinmm')

  end

else

  # System-installed SDL3 libraries
  # Try pkg-config first — provides accurate include paths and link flags
  sdl3_pkgs = 'sdl3 sdl3-image sdl3-mixer sdl3-ttf'

  if system("pkg-config --exists #{sdl3_pkgs} 2>#{File::NULL}")
    puts 'Ruby 2D: Configuring SDL3 via pkg-config.'
    add_flags(:c,  `pkg-config --cflags #{sdl3_pkgs}`.chomp)
    add_flags(:ld, `pkg-config --libs   #{sdl3_pkgs}`.chomp)

  elsif !(have_library('SDL3') && have_library('SDL3_image') &&
          have_library('SDL3_mixer') && have_library('SDL3_ttf'))
    # No static libs, no pkg-config, and not in the standard system paths —
    # install without the extension and tell the user how to finish.
    skip_build('no bundled, cached, or system SDL3 libraries found.')
  end

  # Ruby 2D requires SDL 3.4+ (e.g. `SDL_SCALEMODE_PIXELART`), and some distros
  # still ship 3.2 — which would otherwise surface as bare compiler errors deep
  # in `make`. Check the headers up front for a clear message instead. The
  # bundled and cache libraries are pinned in assets/deps.yaml, so only system
  # libraries need this.
  unless try_compile(<<~SRC)
    #include <SDL3/SDL_version.h>
    #if !SDL_VERSION_ATLEAST(3, 4, 0)
    #error SDL3 older than 3.4
    #endif
    int main(void) { return 0; }
  SRC
    found = `pkg-config --modversion sdl3 2>#{File::NULL}`.strip
    found = nil if found.empty?
    skip_build("system-installed SDL3 is older than the required 3.4#{" (#{found} found)" if found}.",
               guidance: Ruby2D::DepsHelp.notice_old_sdl(found))
  end

  case AssetsTarget.host_os
  when 'linux', 'bsd'
    add_flags(:ld, '-lm')
  end

end

# Remove newlines in flags, they can cause problems
$CFLAGS.gsub!(/\n/, ' ')
$LDFLAGS.gsub!(/\n/, ' ')

# Create Makefile
create_makefile('ruby2d/ruby2d')
