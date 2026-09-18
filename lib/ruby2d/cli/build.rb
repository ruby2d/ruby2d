# Build a compiled Ruby 2D app with mruby

require 'fileutils'
require 'shellwords'
require_relative '../gem_paths'
require_relative '../version'
require_relative '../lib_files'
require_relative '../../../assets/target'
require_relative 'colorize'
require_relative 'messages'
require_relative 'executable'
require_relative 'asset_directives'


# The Ruby 2D library files (shared with the WASM/Try build — see `lib_files.rb`)
@ruby2d_lib_files = Ruby2D::LIB_FILES


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


# Whether `path` is `dir` or lies inside it. Both are real paths (see
# real_path), so a symlinked component on either side doesn't fool the test;
# the root joins as `/` rather than `//`.
def within?(path, dir)
  path == dir || path.start_with?(File.join(dir, ''))
end

# A path with symlinks resolved. The path must exist.
# `File.realpath` alone leaves a bare `/` as `/` on Windows, where the root of
# the current drive is `D:/`, so it would never match a real working directory
# and `check_asset_dir('/')` would pass. Absolute first (without `~`
# expansion, which `Ruby2D.absolute_path` reserves for asset paths).
def real_path(path)
  File.realpath(File.absolute_path(path))
end

# The build output directory, as a real path (`Dir.pwd` reports one).
def build_output_path
  File.join(real_path(Dir.pwd), BUILD_DIR)
end

# An existing path relative to the working directory, or nil when it lies
# outside. Decided on the path as written first, so a project-local symlink
# (`media` pointing at a shared directory) keeps its name, and then on real
# paths, so a path typed through a symlinked component (`/tmp`, a link to
# `/private/tmp` on macOS, where `Dir.pwd` reports the latter) still counts as
# inside.
def path_within_cwd(path)
  full = File.expand_path(path)
  return full.delete_prefix("#{Dir.pwd}/") if within?(full, Dir.pwd)

  full = real_path(path)
  cwd = real_path(Dir.pwd)
  within?(full, cwd) ? full.delete_prefix("#{cwd}/") : nil
end

# The name a compiled app sees as `__FILE__` (and `__dir__` derives from): the
# source path relative to the build's working directory when it sits inside it
# (`main.rb`, `src/main.rb`), which is how CRuby names it when run from there —
# so `File.join(__dir__, 'media/x.png')` resolves against the bundled layout,
# which is laid out relative to that same directory. A source elsewhere is
# named by its basename, as an asset directory elsewhere is (see
# asset_bundle_path): its real path names the developer's machine, not the
# build.
def app_source_name(path)
  path_within_cwd(path) || File.basename(File.expand_path(path))
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

  # mruby has no `__dir__`. A compiled app is one source file, so its directory
  # is known here: that of the name the app is compiled under (see below).
  app_name = app_source_name(ruby2d_app)
  ruby2d_lib << "def __dir__ = File.dirname(#{app_name.inspect})\n"

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

  # Compile the user's source as written: the `require 'ruby2d'` it starts with
  # is answered by the shim in `mruby_compat`, so nothing is rewritten and an
  # `mrbc` diagnostic's line points at the file the user wrote. `mrbc` bakes
  # the path it's given into the bytecode as `__FILE__` (and reports against
  # it), so it's given the name the app should see (see app_source_name): a
  # staging tree under `build/` holds a copy at that name, and `mrbc` runs from
  # its root. Its output is captured so a syntax error prints under the
  # `Error:` line that explains it.
  stage_dir = File.join(BUILD_DIR, 'stage')
  staged = File.join(stage_dir, app_name)
  FileUtils.mkdir_p File.dirname(staged)
  FileUtils.cp ruby2d_app, staged
  app_cmd = "#{shell_escape(mrbc)} #{debug_flag} -Bruby2d_app -o../ruby2d_app.c #{shell_escape(app_name)}"
  cmd_echo("( cd #{stage_dir} && #{app_cmd} )") if @debug
  app_output = Dir.chdir(stage_dir) { `#{app_cmd} 2>&1` }
  app_result = $?
  print app_output unless app_output.empty?
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

  compile(ruby2d_app)

  # Asset directories to bundle: the `--assets` flag plus any `# ruby2d:assets
  # <dir>` directives in the app source, resolved to their bundle paths once
  # here (see Asset bundling below) so a bad declaration fails before either
  # target starts compiling.
  @asset_dirs = resolve_asset_dirs(([@assets_dir] + asset_directives(ruby2d_app)).compact,
                                   native: targets.include?(:native))

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
    FileUtils.rm_rf File.join(BUILD_DIR, 'stage')
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

  # Add compiler flags for each platform
  case AssetsTarget.host_os

  when 'macos'
    %w[AVFoundation AudioToolbox Carbon Cocoa CoreAudio CoreHaptics
       CoreMedia ForceFeedback GameController IOKit Metal QuartzCore
       UniformTypeIdentifiers].each do |name|
      add_ld_flags(ld_flags, name, :framework)
    end

  when 'windows'
    ld_flags << '-lgdi32 -lhid -limm32 -lole32 -loleaut32 -lrpcrt4 -lsetupapi -lusp10 -luuid -lversion -lwinmm -lws2_32'

  when 'linux', 'bsd'
    ld_flags << '-lm'
  end

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
  # reads `ruby2d/fonts/…` relative to its working directory — its own
  # directory, which it changes to at startup — mirroring the WASM preload.
  fonts_src = "#{Ruby2D.assets}/resources/fonts"
  copy_tree fonts_src, 'build/native/ruby2d/fonts' if Dir.exist?(fonts_src)

  # Bundle each declared asset directory at its bundle path next to the
  # executable — the native counterpart to the web build's virtual-filesystem
  # preload. The app resolves it from its working directory, so a reference
  # like `Image.new('media/x.png')` finds it.
  @asset_dirs.each { |src, bundle| copy_tree src, File.join('build/native', bundle) }

  create_macos_bundle if AssetsTarget.host_os == 'macos'
  wrote 'build/native/app'
  wrote 'build/native/App.app' if AssetsTarget.host_os == 'macos'
  puts "    #{'Run `ruby2d launch --native` to view'.dim}"
end


# Asset bundling ###############################################################
#
# A declared asset directory (from `--assets` or a `# ruby2d:assets` directive)
# lands in the build at its *bundle path*, the path the app references it by:
# the web build mounts it there in the virtual filesystem, the native build
# copies it there next to the executable. Both are the app's working directory
# at runtime, so one reference like `Image.new('media/x.png')` resolves in each.

# Names the native build writes beside the bundled assets: the executable and,
# on macOS, the app bundle. Compared without regard to case, since the macOS
# and Windows filesystems don't distinguish it.
RESERVED_BUNDLE_NAMES = %w[app app.exe app.app].freeze

# The bundle path of a declared asset directory: its path relative to the
# build's working directory when it sits inside it (`media`, `assets/media`),
# so the app references it the way CRuby run from there does. A directory
# elsewhere — absolute, or reached through `..` — can't keep its path, which
# names the developer's machine rather than the build; it's bundled under its
# basename, and the note says which name to reference.
def asset_bundle_path(dir)
  bundle = path_within_cwd(dir)
  return bundle if bundle

  base = File.basename(File.expand_path(dir))
  note "assets dir `#{dir}` is outside this directory, so it's bundled as `#{base}`. Reference it by that name (e.g. `#{base}/x.png`)."
  base
end

# Validate a declared asset directory before it's bundled. A missing one aborts
# the build rather than ship an app that can't find its assets. So does one
# that overlaps the build output: one containing it (`.`, `..`, or a symlink
# to either) would be copied into its own descendant, nesting the output in
# itself until a path is too long, and one inside it (`build`, `build/native`)
# is wiped and rewritten by the build, and would be copied into itself the
# same way.
def check_asset_dir(dir)
  unless Dir.exist?(dir)
    error "asset directory not found: #{dir}"
    exit 1
  end

  full = real_path(dir)
  output = build_output_path
  return unless within?(output, full) || within?(full, output)

  error "asset directory `#{dir}` overlaps the build output `#{BUILD_DIR}/`, so bundling it would copy the build into itself. Keep assets in their own directory (e.g. `media`)."
  exit 1
end

# Refuse a bundle path whose first component is a reserved name: the copy
# would replace the executable (`app/` can't be created where `app` is a
# file) or land inside the macOS bundle.
def check_bundle_path(bundle, dir)
  return unless RESERVED_BUNDLE_NAMES.include?(bundle.split('/').first.downcase)

  error "asset directory `#{dir}` would be bundled as `#{bundle}`, but `app`, `app.exe`, and `App.app` are reserved for the native executable and its macOS bundle. Rename it (e.g. `media`)."
  exit 1
end

# Resolve the declared asset directories to `[source, bundle_path]` pairs, in
# declaration order, validating each. A directory declared twice (the flag
# and a directive, or `media` and `./media`) is bundled once, and one inside
# another declared directory, landing inside its bundle path, is dropped: the
# parent's copy includes it, and bundling it again would duplicate its files
# in the web data package. (One inside another but landing elsewhere — the
# parent is outside the working directory, so bundled under its basename —
# is kept: nothing else puts it where the app looks.) Two different
# directories can't share a bundle path (`media` and `../x/media` both land
# at `media`): the copies would merge, with whichever came later replacing
# same-named files, and the web build packages the first — so that is refused
# rather than shipped two ways.
def resolve_asset_dirs(dirs, native:)
  dirs.each { |dir| check_asset_dir(dir) }
  sources = dirs.map { |dir| real_path(dir) }
  dirs = dirs.each_with_index.reject { |_dir, i| sources.index(sources[i]) < i }.map(&:first)
  sources.uniq!
  bundles = dirs.map { |dir| asset_bundle_path(dir) }
  claimed = {}
  dirs.each_with_index.filter_map do |dir, i|
    covered = sources.each_with_index.any? do |other, j|
      j != i && within?(sources[i], other) && within?(bundles[i], bundles[j])
    end
    next if covered

    bundle = bundles[i]
    check_bundle_path(bundle, dir) if native
    if claimed[bundle]
      error "asset directory `#{dir}` would be bundled as `#{bundle}`, which `#{claimed[bundle]}` already is. Rename one of them."
      exit 1
    end
    claimed[bundle] = dir
    [dir, bundle]
  end
end

# Copy a directory's contents into `dest`, creating it if needed and merging
# into it if it exists — where `cp_r dir, dest` on an existing `dest` copies
# the directory *inside* it, a level too deep. That's what a child declared
# before its parent, or an asset directory named `ruby2d` beside the bundled
# fonts, would otherwise hit. Symlinks are followed, so the copy is
# self-contained: a link copied as a link points at the developer's tree, or
# at nothing once the build moves. A link back into a directory being copied
# (a loop), or to a directory the build writes into — the copy's own
# destination, or the build output when the tree copied isn't itself part of
# it, as the macOS bundle's is — is skipped with a warning, as is one pointing
# at nothing; each link is reported once, though both targets copy through
# here (the web build packages the staged copy) so they bundle the same tree.
def copy_tree(src, dest, ancestors = {}, written = nil)
  FileUtils.mkdir_p dest
  ancestors = ancestors.merge(real_path(src) => src)
  written ||= [real_path(dest)].tap do |dirs|
    dirs << build_output_path unless within?(real_path(src), build_output_path)
  end
  Dir.children(src).sort.each do |name|
    from = File.join(src, name)
    to = File.join(dest, name)
    if File.directory?(from)
      real = real_path(from)
      if ancestors[real]
        skip_link from, "a link back into `#{ancestors[real]}`"
      elsif written.any? { |dir| within?(real, dir) || within?(dir, real) }
        skip_link from, 'a link to a directory the build writes into'
      else
        copy_tree(from, to, ancestors, written)
      end
    elsif File.exist?(from)
      FileUtils.copy_file(from, to)
    else
      skip_link from, 'a link to nothing'
    end
  end
end

# Warn once per skipped link, however many targets copy past it.
def skip_link(path, why)
  @skipped_links ||= {}
  return if @skipped_links[path]

  @skipped_links[path] = true
  warning "skipping `#{path}`, #{why}"
end

# An Emscripten `src@dst` file mapping. The packager splits the pair at the
# first `@`, and reads `@@` as a literal one — so a directory like
# `sprites@2x` is escaped on both sides.
def emcc_file_map(src, dst)
  "#{src.gsub('@', '@@')}@#{dst.gsub('@', '@@')}"
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

  # Bundle the default font and each declared asset directory into the virtual
  # filesystem at its bundle path (the `src@dst` map; resolved in `build`). An
  # asset directory is packaged from a staged copy, so the web build carries
  # the same tree the native copy does (Emscripten's packager doesn't follow a
  # symlinked directory). A regular build preloads them into a separate
  # `app.data` the page fetches; `--single-file` embeds them in the code
  # instead, since Emscripten keeps preloaded data outside even a
  # `-sSINGLE_FILE` build, and the point of the option is one file.
  fonts_dir = "#{Ruby2D.assets}/resources/fonts"
  bundle_flag = @single_file ? '--embed-file' : '--preload-file'
  preload_flag = "#{bundle_flag} #{shell_escape(emcc_file_map(fonts_dir, 'ruby2d/fonts'))}"
  @asset_dirs.each do |src, bundle|
    staged = File.join(BUILD_DIR, 'stage', 'assets', bundle)
    copy_tree src, staged
    preload_flag += " #{bundle_flag} #{shell_escape(emcc_file_map(staged, bundle))}"
  end

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
            '-o build/web/app.html'

    unless $?.success?
      error 'Web build failed.'
      exit 1
    end

    wrote 'build/web/app.html'
  else
    run_cmd "emcc -O3 #{mruby_abi_flag} -I#{shell_escape(incl_dir_ruby2d)} -I#{shell_escape(incl_dir_deps)} "\
            "-sUSE_SDL=0 #{memory_flags} #{web_opt_flags} "\
            "build/app.c #{ld_flags} #{preload_flag} "\
            '-o build/web/app.js'

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

  # Bundle the runtime resources (default font) and the declared asset
  # directories (copied next to build/native/app earlier) alongside the
  # executable inside the bundle too, at the same paths. The app chdirs to its
  # own directory at startup, so it resolves them here when launched from
  # Finder (where the working directory is otherwise `/`). Each path is copied
  # once, merging, so an asset directory bundled as `ruby2d` beside the fonts
  # lands once and doesn't nest.
  (['ruby2d'] + @asset_dirs.map { |_, bundle| bundle }).uniq.each do |bundle|
    src = File.join('build/native', bundle)
    copy_tree src, File.join('build/native/App.app/Contents/MacOS', bundle) if Dir.exist?(src)
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
