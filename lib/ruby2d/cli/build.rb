# Build a compiled Ruby 2D app with mruby

require 'ruby2d'
require 'ruby2d/version'
require 'fileutils'
require 'shellwords'
require 'ruby2d/cli/colorize'
require 'ruby2d/cli/messages'
require 'ruby2d/cli/lib_files'
require_relative '../../../assets/target'


# The Ruby 2D library files (shared with the WASM/Try build — see cli/lib_files)
@ruby2d_lib_files = Ruby2D::CLI::LIB_FILES


# Helpers ######################################################################

# Shell-escape a path for safe interpolation into a command string, so a gem or
# asset install location containing spaces (or other shell metacharacters)
# doesn't break the cc/emcc/mrbc invocations. A no-op for ordinary paths.
def shell_escape(path)
  Shellwords.escape(path.to_s)
end

def run_cmd(cmd)
  cmd_echo(cmd) if @debug
  system cmd
end

# Echo a command under `--debug`, abbreviating the gem dir to keep it readable.
# Substitutes both the escaped and plain gem dir so it works whether or not the
# path needed shell-escaping.
def cmd_echo(cmd)
  display_cmd = cmd.gsub(shell_escape(Ruby2D.gem_dir), '$RUBY2D').gsub(Ruby2D.gem_dir, '$RUBY2D')
  puts "  #{"$ #{display_cmd}".dim}\n\n"
end


# Print a build-step banner — a ruby-red diamond and a bold title — to match
# the `ruby2d` CLI and `rake` output. Artifact paths are listed beneath it.
def step(title)
  puts "\n  #{'◆'.ruby2d_red} #{title.bold}"
end


# List a file or bundle the build produced, beneath its step banner. The dim
# `wrote` label marks it as an output without competing with the path itself.
def wrote(path)
  puts "    #{'wrote'.dim} #{path}"
end


# A friendly label for the host platform the native build targets (e.g.
# "macOS (arm64)"). `ruby2d build` doesn't cross-compile — the executable is for
# this machine only — so naming it avoids the "is this a universal binary?" doubt.
def native_target
  os = { 'macos' => 'macOS', 'windows' => 'Windows',
         'linux' => 'Linux', 'bsd' => 'BSD' }.fetch(AssetsTarget.host_os, AssetsTarget.host_os)
  "#{os} (#{AssetsTarget.host_arch})"
end


# Neutralize `require 'ruby2d'` / `require 'ruby2d/core'` lines — the bundled
# build already provides Ruby2D. Blank each one out rather than deleting it, so
# every following line keeps its original number and an `mrbc` compile error
# still points at the right line in the user's source.
def strip_require(file)
  File.foreach(file).map do |line|
    line.match?(/require ('|")ruby2d(\/core)?('|")/) ? "\n" : line
  end.join
end


# Collect the asset directories declared inline with `# ruby2d:assets <dir>`
# directives in the app source — the flag-free equivalent of `--assets`, so an
# app can carry its own bundling instructions instead of relying on the caller
# to remember the flag. One directory per directive; repeat the line for
# several. Paths are relative to the build's working directory, matching
# `--assets`. Returns the directories in source order.
def asset_directives(file)
  File.foreach(file).filter_map do |line|
    m = line.match(/\A\s*#\s*ruby2d:assets\s+(\S.*?)\s*\z/)
    m && m[1]
  end
end


# Locate an executable on PATH. Portable replacement for `which`, which is
# Unix-only (Windows cmd.exe has no `which`); tries Windows executable
# extensions when running there.
def find_executable(name)
  exts = AssetsTarget.host_os == 'windows' ? ['.exe', '.bat', '.cmd', ''] : ['']

  # An explicit path (e.g. `CC=/usr/bin/clang`) is used as-is, not searched on
  # PATH — `File.join(dir, '/usr/bin/clang')` would collapse to a bogus path.
  if name.include?(File::SEPARATOR) || (File::ALT_SEPARATOR && name.include?(File::ALT_SEPARATOR))
    exts.each do |ext|
      candidate = "#{name}#{ext}"
      return candidate if File.file?(candidate) && File.executable?(candidate)
    end
    return nil
  end

  ENV.fetch('PATH', '').split(File::PATH_SEPARATOR).each do |dir|
    next if dir.empty?
    exts.each do |ext|
      candidate = File.join(dir, "#{name}#{ext}")
      return candidate if File.file?(candidate) && File.executable?(candidate)
    end
  end
  nil
end


# Ruby 2D's static libraries (SDL3 + mruby) live in one of two places for the
# current target: bundled inside the gem (the RELEASE_PLATFORMS), or built by
# `ruby2d setup` into the per-user cache (every other platform). These helpers
# resolve which — the compile steps and find_mrbc share them.

# The bundled platform dir inside the gem — populated for RELEASE_PLATFORMS.
def bundled_platform_dir
  AssetsTarget.platform_dir(root: Ruby2D.assets)
end

# The platform dir a `ruby2d setup` build writes into, outside the gem.
def cache_platform_dir
  AssetsTarget.platform_dir(root: AssetsTarget.cache_root)
end

# A cache build is only usable by the ruby2d version that produced it — a gem
# upgrade may pin newer SDL/mruby, and stale cache libs must not be linked
# against fresh headers. `ruby2d setup` stamps the build; require a match.
def cache_stamp_ok?(dir)
  stamp = File.join(dir, '.ruby2d-version')
  File.exist?(stamp) && File.read(stamp).strip == Ruby2D::VERSION
end

# The platform dir holding this target's static libs — bundled first, then a
# stamped cache build. nil if neither has them, in which case the native build
# links system-installed SDL3 + mruby (Linux/BSD, or before `ruby2d setup`).
def deps_platform_dir
  bundled = bundled_platform_dir
  return bundled if File.exist?(File.join(bundled, 'lib', 'libSDL3.a'))

  cache = cache_platform_dir
  return cache if File.exist?(File.join(cache, 'lib', 'libSDL3.a')) && cache_stamp_ok?(cache)

  nil
end

# The SDL3 + mruby headers matching the resolved libraries (platform/include is
# a sibling of the per-target lib dir). Falls back to the bundled headers for
# the system-lib build, where they still describe the pinned API.
def deps_include_dir
  dir = deps_platform_dir
  dir ? File.join(File.dirname(dir), 'include') : "#{Ruby2D.assets}/platform/include"
end

# Find the `mrbc` executable: prefer bundled assets, then a `ruby2d setup` cache
# build, then $PATH.
def find_mrbc
  name = AssetsTarget.host_os == 'windows' ? 'mrbc.exe' : 'mrbc'

  bundled = File.join(bundled_platform_dir, 'bin', name)
  return bundled if File.exist?(bundled)

  cache = cache_platform_dir
  cached_mrbc = File.join(cache, 'bin', name)
  return cached_mrbc if File.exist?(cached_mrbc) && cache_stamp_ok?(cache)

  # Fall back to system-installed mrbc
  find_executable('mrbc')
end


# The system libraries and frameworks SDL3 needs on this platform, independent
# of how Ruby 2D itself was compiled — shared by the mruby and Spinel builds.
def native_platform_flags
  flags = +''
  case AssetsTarget.host_os

  when 'macos'
    %w[AVFoundation AudioToolbox Carbon Cocoa CoreAudio CoreHaptics
       CoreMedia ForceFeedback GameController IOKit Metal QuartzCore
       UniformTypeIdentifiers].each do |name|
      add_ld_flags(flags, name, :framework)
    end

  when 'windows'
    flags << '-lgdi32 -lhid -limm32 -lole32 -loleaut32 -lrpcrt4 -lsetupapi -lusp10 -luuid -lversion -lwinmm -lws2_32'

  when 'linux', 'bsd'
    flags << '-lm'
  end
  flags
end


# Add linker flags
def add_ld_flags(ld_flags, name, type, dir = nil)
  case type
  when :archive
    ld_flags << "#{shell_escape("#{dir}/lib#{name}.a")} "
  when :framework
    ld_flags << "-Wl,-framework,#{name} "
  end
end


# Our build output lives in `build/` under the current directory, and a build
# wipes it first. A hidden marker lets a later build (or `--clean`) tell its own
# output from an unrelated, pre-existing `build/` — CMake, Meson, and many other
# tools default to that name — before deleting anything.
BUILD_DIR = 'build'
BUILD_MARKER = File.join(BUILD_DIR, '.ruby2d')

# Refuse to wipe `build/` when it exists, holds files, and isn't ours — so
# running `ruby2d build` in a project that already uses `build/` for something
# else can't silently delete it. `Dir.glob` skips the dotfile marker, so the
# emptiness check and the delete target stay consistent.
def refuse_if_foreign_build_dir
  return unless Dir.exist?(BUILD_DIR)
  return if File.exist?(BUILD_MARKER)
  return if Dir.glob("#{BUILD_DIR}/*").empty?

  error "A `#{BUILD_DIR}/` directory already exists here and wasn't created by Ruby 2D."
  puts 'Refusing to delete its contents. Remove it yourself, or run `ruby2d build` from a different directory.'
  exit 1
end


# Build Tasks ##################################################################

# Compile Ruby source to mruby bytecode and assemble into a single C file
def compile(ruby2d_app)

  # Check if source file provided is good
  if !ruby2d_app
    error 'Please provide a Ruby file to build.'
    exit 1
  elsif !File.exist? ruby2d_app
    error "Can't find file: #{ruby2d_app}"
    exit 1
  end

  # Add debugging information to produce backtrace
  debug_flag = @debug ? '-g' : ''

  # Clear and create build directory, refusing to wipe a foreign `build/` and
  # marking ours so later builds recognize it.
  refuse_if_foreign_build_dir
  FileUtils.rm_rf Dir.glob("#{BUILD_DIR}/*")
  FileUtils.mkdir_p BUILD_DIR
  FileUtils.touch BUILD_MARKER

  # Compiling Ruby to bytecode is a sub-second internal step with no artifact a
  # user runs — show its banner (and the `mrbc` echoes below) only with `--debug`.
  step "Compiling #{ruby2d_app}" if @debug

  # Assemble Ruby 2D library files into one '.rb' file

  ruby2d_lib_dir = "#{Ruby2D.gem_dir}/lib/ruby2d/"

  ruby2d_lib = ''
  @ruby2d_lib_files.each do |f|
    ruby2d_lib << File.read("#{ruby2d_lib_dir + f}.rb") + "\n\n"
  end

  # Make Ruby2D classes and DSL methods available at the top level
  ruby2d_lib << "include Ruby2D\nextend Ruby2D::DSL\n"

  File.write('build/ruby2d_lib.rb', ruby2d_lib)

  # Assemble the Ruby 2D C extension files into one '.c' file

  ruby2d_ext_dir = "#{Ruby2D.gem_dir}/ext/ruby2d/"

  ruby2d_ext = "#define MRUBY 1\n\n"
  c_files = Dir["#{ruby2d_ext_dir}*.c"].sort
  main_file = c_files.delete("#{ruby2d_ext_dir}ruby2d.c")
  c_files.unshift(main_file) if main_file
  c_files.each { |c_file| ruby2d_ext << File.read(c_file) }

  File.write('build/ruby2d_ext.c', ruby2d_ext)

  # Find the `mrbc` executable
  mrbc = find_mrbc
  unless mrbc
    error "Can't find `mrbc`, the mruby compiler."
    puts 'Run `ruby2d setup` to build it, or install mruby so `mrbc` is on your PATH.'
    exit 1
  end

  # Compile the Ruby 2D lib (`.rb` files) to mruby bytecode. `run_cmd` doesn't
  # check the result, so do it here — a failure means the assembled bytecode
  # files won't exist, and the combine step below would crash on a missing file.
  run_cmd "#{shell_escape(mrbc)} #{debug_flag} -Bruby2d_lib -obuild/ruby2d_lib.c build/ruby2d_lib.rb"
  unless $?.success?
    error 'Failed to compile the Ruby 2D library.'
    exit 1
  end

  # Stage the user's source (requires blanked — see strip_require) and compile it.
  # `mrbc` reports diagnostics against the path it's given, so capture its output
  # and rewrite the staging path back to the original filename: a syntax error
  # then points at `asteroids.rb:LINE`, the file the user wrote, not the internal
  # copy. Line numbers already line up because strip_require preserves them.
  staged = 'build/ruby2d_app.rb'
  File.write(staged, strip_require(ruby2d_app))
  app_cmd = "#{shell_escape(mrbc)} #{debug_flag} -Bruby2d_app -obuild/ruby2d_app.c #{staged}"
  cmd_echo(app_cmd) if @debug
  app_output = `#{app_cmd} 2>&1`
  app_result = $?
  print app_output.gsub(staged) { ruby2d_app } unless app_output.empty?
  unless app_result.success?
    error "Failed to compile #{ruby2d_app}."
    puts 'Check the error above for syntax issues or Ruby features mruby does not support.'
    exit 1
  end

  # Combine contents of C source files and bytecode into one file
  File.open('build/app.c', 'w') do |f|
    ['ruby2d_app', 'ruby2d_lib', 'ruby2d_ext'].each do |c_file|
      f << File.read("build/#{c_file}.c") << "\n\n"
    end
  end

  # `build/app.c` is an intermediate the native/web steps consume, not something
  # the user runs — surface it only with `--debug`, where it's also kept.
  wrote 'build/app.c' if @debug
end


# Build the user's application for one or more targets
def build(targets, ruby2d_app)
  targets = [targets] unless targets.is_a?(Array)

  # `--spinel` is a different compiler for the same native target, not a target
  # of its own: it replaces mruby, so it owns the whole build rather than
  # slotting into the loop below. See cli/spinel.rb.
  if @spinel
    require 'ruby2d/cli/spinel'
    return build_spinel(ruby2d_app)
  end

  compile(ruby2d_app)

  # Asset directories to bundle: the `--assets` flag plus any `# ruby2d:assets
  # <dir>` directives in the app source. Each is bundled at its own relative
  # path — mounted into the WebAssembly virtual filesystem for the web build,
  # copied next to the executable for the native build. Validate once here so a
  # missing directory fails before either target starts compiling.
  @asset_dirs = ([@assets_dir] + asset_directives(ruby2d_app)).compact.uniq
  @asset_dirs.each { |dir| check_asset_dir(dir) }

  targets.each do |target|
    case target
    when :native
      compile_native
    when :web
      compile_web
    end
  end

  # Remove intermediate build files. `--debug` keeps them all — including the
  # assembled `build/app.c`, for anyone who wants to compile it themselves.
  unless @debug
    FileUtils.rm(Dir.glob('build/*.rb'))
    FileUtils.rm(Dir.glob('build/*.c'))
  end

  # Trailing blank line so the output isn't flush against the next shell prompt.
  puts
end


# Create a native executable using the available C compiler
def compile_native

  # Get include directories
  incl_dir_ruby2d = "#{Ruby2D.gem_dir}/ext/ruby2d/"
  incl_dir_deps = deps_include_dir

  # Set C flags, if any
  c_flags = ''

  # Add library search directory
  ld_flags = ''
  # Dependent SDL archives before the base `libSDL3.a` so single-pass GNU ld
  # (MinGW on Windows, and Linux/BSD ld) resolves their symbols; mruby is
  # independent of SDL. Mirrors the order in ext/ruby2d/extconf.rb.
  libs = %w[mruby SDL3_image SDL3_mixer SDL3_ttf SDL3]
  if (platform_dir = deps_platform_dir)
    # Bundled or `ruby2d setup`-built static archives. macOS's ld64 is order-independent.
    ld_dir = File.join(platform_dir, 'lib')
    libs.each { |name| add_ld_flags(ld_flags, name, :archive, ld_dir) }
  else
    # No static libs for this target (Linux/BSD aren't in RELEASE_PLATFORMS and
    # `ruby2d setup` hasn't built them): link system-installed SDL3 + mruby, the
    # same fallback find_mrbc uses for `mrbc`.
    libs.each { |name| ld_flags << "-l#{name} " }
  end

  ld_flags << native_platform_flags

  # Check for a C compiler up front so a missing toolchain gives a clear message
  # instead of a bare `failed` on exit 127 (like the `mrbc` check). A missing C
  # compiler is a hard error — native can't build without it — whereas a missing
  # `emcc` only skips the optional web build. Honor $CC if set, else default `cc`.
  cc = ENV['CC'] || 'cc'
  if find_executable(cc).nil?
    error "Can't find `#{cc}`, a C compiler. Install a C toolchain (e.g. Xcode Command Line Tools or build-essential) or set $CC."
    exit 1
  end

  # Compile the app
  step 'Building native'
  puts "    #{"for #{native_target}".dim}"
  FileUtils.mkdir_p 'build/native'
  run_cmd "#{shell_escape(cc)} #{c_flags} -I#{shell_escape(incl_dir_ruby2d)} -I#{shell_escape(incl_dir_deps)} build/app.c #{ld_flags} -o build/native/app"

  unless $?.success?
    error 'Native build failed.'
    unless deps_platform_dir
      puts "No bundled libraries for #{AssetsTarget.target_id}. Run `ruby2d setup` to build"
      puts 'them, or install SDL3 + mruby with your system package manager.'
    end
    exit 1
  end

  # Bundle the default font next to the executable so apps using the built-in
  # font (`Text.new('…')` with no `font:`) resolve it at runtime. The native app
  # reads `ruby2d/fonts/…` relative to its working directory — which
  # `ruby2d launch --native` sets to `build/native` — mirroring the WASM preload.
  fonts_src = "#{Ruby2D.assets}/resources/fonts"
  if Dir.exist?(fonts_src)
    fonts_dest = 'build/native/ruby2d/fonts'
    FileUtils.mkdir_p fonts_dest
    FileUtils.cp_r "#{fonts_src}/.", fonts_dest
  end

  # Bundle each declared asset directory next to the executable — the native
  # counterpart to the web build's virtual-filesystem preload. The app resolves
  # them at runtime from its working directory (`build/native`, set by
  # `ruby2d launch --native`), so a dir mounts at the same relative path it was
  # given, matching how the app references it (`Image.new('media/x.png')`).
  @asset_dirs.each do |dir|
    dest = File.join('build/native', dir)
    FileUtils.mkdir_p File.dirname(dest)
    FileUtils.cp_r dir, dest
  end

  create_macos_bundle if AssetsTarget.host_os == 'macos'
  wrote 'build/native/app'
  wrote 'build/native/App.app' if AssetsTarget.host_os == 'macos'
  puts "    #{'Run `ruby2d launch --native` to view'.dim}"
end


# Validate an asset directory (from `--assets` or a `# ruby2d:assets` directive)
# before it's bundled. A missing dir aborts the build rather than ship an app
# that can't find its assets. Both builds bundle the dir at the path given —
# the web VFS mounts it there, the native build copies it there next to the
# executable — so an absolute dir lands at that same absolute path, which the
# relative references apps use won't find; warn rather than silently mislead.
def check_asset_dir(dir)
  unless Dir.exist?(dir)
    error "asset directory not found: #{dir}"
    exit 1
  end
  return unless File.absolute_path?(dir)

  warning "assets dir `#{dir}` is absolute, so it's bundled at that same " \
          'path. Reference it by that absolute path, or use a relative dir (e.g. `media`) instead.'
end


# Create a WebAssembly executable using Emscripten
def compile_web
  # When Emscripten is missing: skip the web build for a default `ruby2d build`
  # (so the native app still gets produced), but fail loudly when `--web` was
  # passed explicitly — the user asked for web specifically, so it shouldn't pass
  # silently (e.g. in `ruby2d build --web && deploy`).
  if find_executable('emcc').nil?
    if @web_explicit
      error "Can't find `emcc`. Install the Emscripten SDK and source emsdk_env.sh", spaced: true
      exit 1
    end
    puts "\n  #{'Skipping web build — Emscripten (emcc) not found'.dim}"
    return
  end

  step 'Building web'
  FileUtils.mkdir_p 'build/web'

  incl_dir_ruby2d = "#{Ruby2D.gem_dir}/ext/ruby2d/"
  incl_dir_deps = "#{Ruby2D.assets}/platform/include/"

  wasm_lib_dir = "#{Ruby2D.assets}/platform/wasm/lib"
  ld_flags = Dir["#{wasm_lib_dir}/*.a"].map { |f| shell_escape(f) }.join(' ')

  # Always bundle the default font for WASM builds
  fonts_dir = "#{Ruby2D.assets}/resources/fonts"
  preload_flag = "--preload-file #{shell_escape("#{fonts_dir}@ruby2d/fonts")}"

  # Bundle each requested asset directory — from `--assets` and any
  # `# ruby2d:assets` directive — into the virtual filesystem at its own path
  # (the `src@dst` map uses the same string for both). Validated in `build`.
  @asset_dirs.each { |dir| preload_flag += " --preload-file #{shell_escape("#{dir}@#{dir}")}" }

  # Faster page loads: restrict the JS glue to the browser environment (drops the
  # Node/worker probing) and, for release builds, minify it with Closure. Closure
  # is slow, so skip it for --debug (keep iteration fast and the glue readable);
  # the environment trim is cheap and always applied.
  web_opt_flags = '-sENVIRONMENT=web'
  web_opt_flags += ' --closure 1' unless @debug

  # The vendored wasm libmruby.a is built with MRB_NO_BOXING (floats inline in
  # mrb_value — the default 32-bit word boxing heap-allocates every Float).
  # The boxing mode is ABI: app.c includes the mruby headers, so it must define
  # the same mode or values are read with mismatched layouts at runtime.
  mruby_abi_flag = '-DMRB_NO_BOXING'

  # Start the wasm heap at 64MB instead of Emscripten's 16MB default. Growing
  # is kept as a safety valve, but each mid-game `memory.grow` detaches and
  # recopies the heap — a visible frame hitch — and reaching 64MB from 16MB
  # takes ~8 geometric growth steps scattered through early gameplay. Memory
  # isn't stored in the binary, so this doesn't change the download size;
  # browsers commit the pages lazily.
  memory_flags = '-sINITIAL_MEMORY=64MB -sALLOW_MEMORY_GROWTH'

  if @single_file
    # A custom template becomes Emscripten's shell file (it must contain the
    # `{{{ SCRIPT }}}` placeholder); otherwise emcc emits its default shell.
    shell_flag = @template ? "--shell-file #{shell_escape(@template)} " : ''
    run_cmd "emcc -O3 #{mruby_abi_flag} -I#{shell_escape(incl_dir_ruby2d)} -I#{shell_escape(incl_dir_deps)} "\
            "-sUSE_SDL=0 -sSINGLE_FILE #{memory_flags} #{web_opt_flags} #{shell_flag}"\
            "build/app.c #{ld_flags} #{preload_flag} "\
            "-o build/web/app.html"

    unless $?.success?
      error 'Web build failed.'
      exit 1
    end

    wrote 'build/web/app.html'
  else
    run_cmd "emcc -O3 #{mruby_abi_flag} -I#{shell_escape(incl_dir_ruby2d)} -I#{shell_escape(incl_dir_deps)} "\
            "-sUSE_SDL=0 #{memory_flags} #{web_opt_flags} "\
            "build/app.c #{ld_flags} #{preload_flag} "\
            "-o build/web/app.js"

    unless $?.success?
      error 'Web build failed.'
      exit 1
    end

    # Use the caller's template if given, else the bundled default. Either way
    # it must load `app.js` (see the bundled `template.html` for the contract).
    FileUtils.cp(@template || "#{Ruby2D.assets}/resources/web/template.html", 'build/web/app.html')
    wrote 'build/web/app.html'
    wrote 'build/web/app.js'
    wrote 'build/web/app.wasm'
    wrote 'build/web/app.data'
  end
  puts "    #{'Run `ruby2d launch --web` to view'.dim}"
end


# Build an app bundle for macOS
def create_macos_bundle

  # Property list source for the bundle
  info_plist = %(
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>app</string>
  <key>CFBundleIconFile</key>
  <string>app.icns</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>NSHighResolutionCapable</key>
  <string>True</string>
</dict>
</plist>
)

  # Create directories
  FileUtils.mkpath 'build/native/App.app/Contents/MacOS'
  FileUtils.mkpath 'build/native/App.app/Contents/Resources'

  # Create Info.plist and copy over assets
  File.open('build/native/App.app/Contents/Info.plist', 'w') { |f| f.write(info_plist) }
  FileUtils.cp 'build/native/app', 'build/native/App.app/Contents/MacOS/'

  # Bundle the runtime resources (default font) next to the executable. The app
  # chdirs to its own directory at startup, so it resolves `ruby2d/fonts/…`
  # here when launched from Finder (where the working directory is otherwise `/`).
  if Dir.exist?('build/native/ruby2d')
    FileUtils.cp_r 'build/native/ruby2d', 'build/native/App.app/Contents/MacOS/'
  end

  # Bundle any declared asset directories (copied next to build/native/app
  # earlier) alongside the executable inside the bundle too, preserving their
  # relative paths, so a Finder-launched app resolves them the same way.
  @asset_dirs.each do |dir|
    src = File.join('build/native', dir)
    next unless Dir.exist?(src)

    dest = File.join('build/native/App.app/Contents/MacOS', dir)
    FileUtils.mkdir_p File.dirname(dest)
    FileUtils.cp_r src, dest
  end

  # Bundle the icon referenced by CFBundleIconFile (the Ruby 2D default), so the
  # plist's `app.icns` reference resolves instead of dangling.
  icon = "#{Ruby2D.assets}/resources/icons/icon.icns"
  FileUtils.cp icon, 'build/native/App.app/Contents/Resources/app.icns' if File.exist?(icon)
end


# Clean up the build directory
def clean_up(cmd = nil)
  if cmd == :all
    refuse_if_foreign_build_dir
    step 'Cleaning build directory'
    FileUtils.rm_rf Dir.glob("#{BUILD_DIR}/*")
    puts
  end
end
