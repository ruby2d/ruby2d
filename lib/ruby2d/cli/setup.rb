# Build Ruby 2D's native dependencies (the SDL3 + mruby static libraries) for
# the current platform. The gem bundles prebuilt libraries for the common
# RELEASE_PLATFORMS; this builds them for everything else (e.g. Linux, Intel
# macOS) into a per-user cache outside the — possibly read-only — gem, where
# `ruby2d build --native` then resolves them (see cli/build's deps_platform_dir).

# Requires only extension-free pieces (gem_paths, not ruby2d) so `setup` can run
# to build the native extension when it doesn't exist yet.
require 'ruby2d/gem_paths'
require 'fileutils'
require 'ruby2d/cli/colorize'
require 'ruby2d/cli/messages'
require 'ruby2d/version'
require_relative '../../../assets/target'


# A ruby-red diamond banner, matching the `ruby2d` CLI and `rake` output.
def setup_step(title)
  puts "\n  #{'◆'.ruby2d_red} #{title.bold}"
end


# A friendly label for the platform being built (e.g. "macOS (x86_64)"). Reads
# the resolved target rather than the host: RUBY2D_ASSETS_OS/ARCH redirect setup
# at another platform's directory, and naming the host would then describe a
# build that isn't happening. Any toolchain is left to the target id printed
# alongside it.
def setup_platform_label
  os, arch, = AssetsTarget.resolved_target
  name = { 'macos' => 'macOS', 'windows' => 'Windows',
           'linux' => 'Linux', 'bsd' => 'BSD' }.fetch(os, os)
  "#{name} (#{arch})"
end


# Abbreviate a home-relative path to `~/…` for tidy, portable output.
def setup_tildify(path)
  home = Dir.home
  path.start_with?(home) ? path.sub(home, '~') : path
end


# Whether a command is on PATH. Unix only — setup's preflight runs there; on
# Windows the assets Rakefile bootstraps git/cmake via MSYS2 pacman itself.
def setup_command?(cmd)
  system("command -v #{cmd} >/dev/null 2>&1")
end


# Whether a pkg-config module's development files are installed. Used by the
# Linux preflight to find missing display libraries before SDL's CMake aborts
# on them — a wall of text several seconds into the build.
def setup_pkg_config?(mod)
  system("pkg-config --exists #{mod} >/dev/null 2>&1")
end


# Check the host build toolchain up front and, if something's missing, print a
# platform-specific hint and stop — rather than failing partway through a
# multi-minute build. No-op on Windows, where the assets Rakefile offers to
# install git/cmake via pacman during its own preflight.
def setup_preflight!
  return if AssetsTarget.host_os == 'windows'

  cc = ENV['CC'] || 'cc'
  linux = AssetsTarget.host_os == 'linux'
  missing = []
  missing << 'git'   unless setup_command?('git')
  missing << 'cmake' unless setup_command?('cmake')
  missing << cc      unless setup_command?(cc)
  # SDL's Linux build finds Wayland (and much else) through pkg-config, and the
  # display-library check below needs it to answer — so require it here.
  missing << 'pkg-config' if linux && !setup_command?('pkg-config')

  unless missing.empty?
    hint = case AssetsTarget.host_os
           when 'macos'
             'Install the Xcode Command Line Tools (`xcode-select --install`) and CMake (`brew install cmake`).'
           when 'linux'
             'Install a C toolchain, CMake, Git, and pkg-config — e.g. `sudo apt install build-essential cmake git pkg-config`.'
           else
             'Install a C toolchain, CMake, and Git with your system package manager (e.g. `pkg install cmake git`).'
           end

    error "Missing build tools: #{missing.join(', ')}", spaced: true
    puts "  #{hint}"
    exit 1
  end

  # SDL won't build a desktop windowing backend without X11 or Wayland
  # development libraries; its CMake mirrors this exact check, but only after
  # cloning and configuring — so catch it here with a clean, actionable message
  # instead of that error's wall of text. pkg-config is guaranteed present
  # above, so it can answer for both. Linux only: the fix (apt packages, the
  # SDL wiki) is Debian-shaped, and BSD's expert audience is served by CMake's.
  if linux && !setup_pkg_config?('x11') && !setup_pkg_config?('wayland-client')
    error 'SDL needs X11 or Wayland development libraries; neither was found.', spaced: true
    puts "  Install SDL's build dependencies for your distribution, then re-run #{'ruby2d setup'.bold}:"
    puts '  https://wiki.libsdl.org/SDL3/README-linux'
    exit 1
  end
end


# Ask before doing the involved work, after printing what it entails. Enter
# accepts (the user asked for this by typing the command — the prompt is there
# to surface the cost, not to second-guess). Skipped by `--yes`, and when stdin
# isn't a TTY (CI, pipelines) where there's nobody to answer.
def setup_confirm!(yes:)
  return if yes || !$stdin.tty?

  print "\n  Continue? #{'[Y/n]'.dim} "
  # A bare Enter accepts; EOF (Ctrl-D) does not — closing the input is a way
  # out of the prompt, not a way to start a multi-minute build.
  answer = $stdin.gets
  return if answer && (answer.strip.empty? || %w[y yes].include?(answer.strip.downcase))

  puts "\n  Cancelled.\n\n"
  exit 0
end


# List the static libraries and binaries a build produced under `dir`.
def setup_list_artifacts(dir)
  Dir.glob(File.join(dir, 'lib', '*.a')).map { |f| File.basename(f) }.sort.each { |f| puts "    lib/#{f}" }
  Dir.glob(File.join(dir, 'bin', '*')).map { |f| File.basename(f) }.sort.each { |f| puts "    bin/#{f}" }
end


# Remove this platform's cache build: the libraries, shared headers, and the
# regenerable intermediates and downloaded sources.
def setup_clean(yes: false)
  cache = AssetsTarget.cache_root
  platform = AssetsTarget.platform_dir(root: cache)

  # Nothing cached for this platform — say so rather than confirming a no-op.
  unless Dir.exist?(platform)
    setup_step 'Nothing to remove'
    puts "    #{"no cached dependencies for #{setup_platform_label}".dim}"
    puts "\n  #{setup_tildify(platform)} doesn't exist.\n\n"
    return
  end

  setup_step 'Remove cached dependencies'
  puts "    #{"for #{setup_platform_label}".dim}"
  puts "\n  This removes #{setup_tildify(platform)} and its build files."
  puts "  Rebuilding them with #{'ruby2d setup'.bold} takes several minutes."
  setup_confirm!(yes: yes)

  [platform,
   AssetsTarget.include_dir(root: cache),
   AssetsTarget.build_dir(root: cache),
   AssetsTarget.sources_dir(root: cache)].each { |dir| FileUtils.rm_rf dir }

  puts "\n  Removed #{setup_tildify(platform)}.\n\n"
end


# Build the native SDL3 + mruby static libraries for the current platform.
def setup(force: false, clean: false, yes: false)
  if clean
    # `--clean` is standalone: it only removes. Say so rather than letting a
    # combined `--force` look like it did something (matches `build --clean`).
    note '`--clean` only removes the built libraries; `--force` was ignored.' if force
    return setup_clean(yes: yes)
  end

  target = AssetsTarget.target_id
  cache  = AssetsTarget.cache_root
  cache_platform = AssetsTarget.platform_dir(root: cache)
  stamp = File.join(cache_platform, '.ruby2d-version')

  # Already provided? The gem bundles prebuilt libraries for RELEASE_PLATFORMS.
  bundled = AssetsTarget.platform_dir(root: Ruby2D.assets)
  bundled_exists = File.exist?(File.join(bundled, 'lib', 'libSDL3.a'))
  if !force && bundled_exists
    setup_step 'Native dependencies ready'
    puts "    #{"#{setup_platform_label} — bundled with the gem".dim}"
    puts "\n  Nothing to build. Run #{'ruby2d build --native <app>.rb'.bold} to build an app.\n\n"
    return
  end

  # Already built for this ruby2d version? Skip unless --force.
  built = File.exist?(File.join(cache_platform, 'lib', 'libSDL3.a')) &&
          File.exist?(stamp) && File.read(stamp).strip == Ruby2D::VERSION
  if built && !force
    setup_step 'Native dependencies ready'
    puts "    #{"#{setup_platform_label} — built at #{setup_tildify(cache_platform)}".dim}"
    puts "\n  Already built. Re-run with #{'--force'.bold} to rebuild, or #{'ruby2d build --native <app>.rb'.bold} to build an app.\n\n"
    return
  end

  setup_preflight!

  # Header — surface the platform and cache location up front (again at the
  # end), spell out what the build entails, and confirm before starting: this
  # downloads sources, compiles for minutes, and rebuilds the installed gem.
  setup_step 'Set up native dependencies'
  puts
  puts "    #{'Platform'.dim}   #{setup_platform_label}  #{"(#{target})".dim}"
  puts "    #{'Location'.dim}   #{setup_tildify(cache_platform)}"
  puts "\n  #{'This will:'.bold}"
  if AssetsTarget.host_os == 'windows'
    puts '    • Offer to install any missing build tools (git, CMake) via MSYS2'
  end
  puts '    • Download the SDL3 and mruby sources with git'
  puts '    • Compile them into static libraries — this takes several minutes'
  puts "    • Rebuild the Ruby 2D extension with #{'gem pristine ruby2d'.bold}"
  puts "\n  Sources and build files go under the location above; only the last"
  puts '  step touches anything outside it.'

  # SDL links a lot of the system's development libraries — windowing, audio,
  # and more — and the full set is distro-specific and long, so point at SDL's
  # own list rather than trying to enumerate it. Preflight has already confirmed
  # the one hard requirement (X11 or Wayland); this covers the rest, whose
  # absence quietly disables features (e.g. no audio) instead of failing loudly.
  if AssetsTarget.host_os == 'linux'
    note "SDL builds against your system's development libraries — windowing,", spaced: true
    puts '  audio, and more. Install the packages for your distribution before continuing:'
    puts '  https://wiki.libsdl.org/SDL3/README-linux'
  end

  # Only `--force` gets here on a platform the gem already bundles, and a build
  # resolves bundled libraries first (see cli/build's deps_platform_dir) — so
  # this build won't be linked against. Worth saying before spending minutes on
  # it, rather than refusing: rebuilding is still a fair way to check the
  # pinned sources compile on this machine.
  if bundled_exists
    warning "This platform's libraries are bundled with the gem, and a", spaced: true
    puts "  build prefers those — so #{'ruby2d build'.bold} won't link what this produces."
  end

  setup_confirm!(yes: yes)

  setup_step 'Building native dependencies'
  puts "    #{'$ rake sdl mruby'.dim}\n\n"

  # Redirect sources, intermediates, and output to the cache so nothing is
  # written into the gem dir. Scope the override to the build subprocess (env
  # hash) so it doesn't leak into the `gem pristine` below — that step needs the
  # standard bundled -> cache resolution. The assets Rakefile carries the pinned
  # versions, the cmake/mruby build steps, and (on Windows) the pacman bootstrap.
  ok = Dir.chdir(Ruby2D.assets) do
    system({ 'RUBY2D_ASSETS_ROOT' => cache }, 'rake', 'sdl', 'mruby')
  end

  unless ok
    error 'Failed to build the native dependencies. See the output above.', spaced: true
    exit 1
  end

  # Stamp the build so `ruby2d build` and extconf only link it against a matching
  # gem version — a later upgrade may pin newer SDL/mruby.
  File.write(stamp, Ruby2D::VERSION)

  setup_step 'Built the native dependencies'
  puts "\n    #{"Native (#{target})".bold}"
  setup_list_artifacts(cache_platform)
  puts "\n  Built to #{setup_tildify(cache_platform)}"

  # Build (or rebuild) the CRuby native extension through RubyGems' standard
  # path now that the libraries exist — extconf resolves this cache build. This
  # keeps the extension entirely on RubyGems' rails; setup builds no extension
  # itself.
  setup_step 'Building the Ruby 2D extension'
  puts "    #{'$ gem pristine ruby2d'.dim}\n\n"
  if system('gem', 'pristine', 'ruby2d')
    puts "\n  #{'Ready!'.bold} #{"require 'ruby2d'".bold} now works — run #{'ruby2d build --native <app>.rb'.bold} to build an app.\n\n"
  else
    warning "Couldn't rebuild the extension automatically.", spaced: true
    puts "  Run #{'gem pristine ruby2d'.bold} yourself to finish.\n\n"
  end
end
