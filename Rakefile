require_relative 'lib/ruby2d/cli/colorize'
require_relative 'lib/ruby2d/cli/messages'

# `assets/` is a git submodule, empty on a clone made without
# `--recurse-submodules`. Nearly every task below reaches into it — the first
# by way of `cli/launch` — so name the command that fixes it rather than
# failing in a `require_relative` backtrace.
unless File.exist?(File.expand_path('assets/target.rb', __dir__))
  abort_error "The assets submodule isn't initialized.\n" \
              "  Run #{'git submodule update --init'.bold} first.\n\n",
              spaced: true, indent: 2
end

require 'rspec/core/rake_task'
require_relative 'lib/ruby2d/cli/examples'
require_relative 'lib/ruby2d/cli/launch'
require_relative 'lib/ruby2d/lib_files'
require_relative 'assets/target'
require_relative 'lib/ruby2d/version'

# Helpers ######################################################################

# A task banner: a ruby-red diamond and a bold title. `spaced` adds a blank
# line beneath the banner so it stays separate from the output that follows;
# pass `spaced: false` when a `run_cmd` echo follows, since that supplies the
# gap itself and the command should sit tight under the title.
def print_task(task, spaced: true)
  print "\n", "  #{'◆'.ruby2d_red} #{task.bold}", "\n"
  puts if spaced
end

def run_cmd(cmd)
  puts "  #{"$ #{cmd}".dim}\n\n"
  system(cmd) || exit(1)
rescue Interrupt
  # Ctrl-C — the user stopped the running command (e.g. the `launch` web
  # server). Exit quietly with the conventional SIGINT status (130) instead of
  # dumping a backtrace.
  exit(130)
end

def interactive_tests
  Dir.glob('test/*.rb')
    .reject { |path| File.basename(path) == 'style.rb' }
    .sort
    .map    { |path| File.basename(path, '.rb') }
end

def examples
  Dir.glob('examples/*.rb')
    .sort
    .map { |path| File.basename(path, '.rb') }
end

# Terminate a spawned process cross-platform. Windows has no graceful
# TERM signal — Process.kill('TERM', ...) raises Errno::EINVAL — so go
# straight to KILL (TerminateProcess) there. On Unix, ask politely with
# TERM first and escalate to KILL if it's still alive after a second.
def terminate_process(pid)
  require 'timeout'
  if AssetsTarget.host_os == 'windows'
    Process.kill('KILL', pid) rescue nil
    Process.waitpid(pid)      rescue nil
  else
    begin
      Process.kill('TERM', pid)
      Timeout.timeout(1) { Process.waitpid(pid) }
    rescue Timeout::Error
      Process.kill('KILL', pid) rescue nil
      Process.waitpid(pid)      rescue nil
    rescue Errno::ESRCH
      # process already gone
    end
  end
end

def print_test_help
  tests = interactive_tests
  puts "\n  #{'Ruby 2D'.ruby2d_red.bold} — Tests #{'in test/'.dim}\n\n"
  tests.each { |t| puts "    #{t}" }
  puts "\n  #{'Usage:'.bold}\n\n"
  puts "    rake test #{'<name>'.dim}           # Run with CRuby (standard Ruby)"
  puts "    rake test:ruby #{'<name>'.dim}      # Run with CRuby (standard Ruby)"
  puts "    rake test:native #{'<name>'.dim}    # Run as a native executable (mruby)"
  puts "    rake test:web #{'<name>'.dim}       # Run as a web app (mruby + WebAssembly)"
  puts "    rake test:all #{'[target]'.dim}     # Run all tests sequentially (target: native, web)"
  puts "    rake test:auto             # Auto-run each test briefly (for CI)"
  puts ''
end

def print_examples_help
  names = examples
  puts "\n  #{'Ruby 2D'.ruby2d_red.bold} — Examples #{'in examples/'.dim}\n\n"
  names.each { |n| puts "    #{n}" }
  puts "\n  #{'Usage:'.bold}\n\n"
  puts "    rake examples #{'<name>'.dim}          # Run an example with CRuby (standard Ruby)"
  puts "    rake examples:ruby #{'<name>'.dim}     # Run with CRuby (standard Ruby)"
  puts "    rake examples:native #{'<name>'.dim}   # Run as a native executable (mruby)"
  puts "    rake examples:web #{'<name>'.dim}      # Run as a web app (mruby + WebAssembly)"
  puts "    rake examples:all #{'[target]'.dim}    # Run all examples sequentially (target: native, web)"
  puts "    rake examples:auto            # Auto-run each example briefly (for CI)"
  puts ''
end

# Rake treats extra command-line words (e.g. `rake test shapes`) as more tasks
# to invoke — define a no-op task for each so they're inert, and return the
# first one, the task's name or target argument (nil if none was given).
def consume_arg_names
  ARGV[1..].each { |arg| task arg.to_sym do ; end }
  ARGV[1]
end

# Yield the example name passed on the command line (e.g. `rake examples logo`),
# or print the help and skip the task body if none was given.
def with_example_name
  (example = consume_arg_names) ? yield(example) : print_examples_help
end

# Yield the test name passed on the command line (e.g. `rake test shapes`),
# or print the help and skip the task body if none was given.
def with_test_name
  (test_file = consume_arg_names) ? yield(test_file) : print_test_help
end

# Run every test or example in sequence for one target — 'ruby' (default),
# 'native', or 'web' from the command line. The test/example differences come
# in as arguments: the item names, the labels for messaging, how to run one
# with CRuby, and how to build one for a bundled target.
def run_all_task(names, label:, item:, run_ruby:, build:)
  target = consume_arg_names || 'ruby'

  unless %w[ruby native web].include?(target)
    error "Unknown target: #{target}"
    puts 'Use one of: ruby, native, web'
    exit 1
  end

  print_task "Running #{names.length} #{label} with #{target}"
  if target == 'web'
    puts "View each #{item} in the browser, then press Enter here to advance.".dim
  else
    puts 'Press Esc to close the current window and start the next.'.dim
  end
  puts "#{'Press Ctrl+C in this terminal to abort.'.dim}\n\n"

  names.each_with_index do |name, i|
    print_task "[#{i + 1}/#{names.length}] #{name}"
    case target
    when 'ruby'
      run_ruby.call(name)
    when 'native'
      system(launch_native_cmd(build.call(:native, name)))
    when 'web'
      pid = spawn('ruby2d', 'launch', '--web', chdir: build.call(:web, name))
      print "\nPress Enter to advance to the next #{item}..."
      $stdin.gets
      terminate_process(pid)
    end
  end

  print_task "All #{label} complete"
end

# Auto-run each test or example briefly to catch crashes (for CI/agents).
# `spawn_item` starts one by name and returns its pid; exiting nonzero before
# the timeout counts as a failure, surviving until the timeout as a pass.
def auto_run_task(names, label:, item:, timeout_env:, &spawn_item)
  require 'timeout'

  timeout = Float(ENV[timeout_env] || 1)
  print_task "Auto-running #{names.length} #{label} (#{timeout}s each)"

  failures = []

  names.each_with_index do |name, i|
    pid = spawn_item.call(name)

    crashed = false
    exit_status = nil

    begin
      Timeout.timeout(timeout) { Process.waitpid(pid) }
      exit_status = $?
      crashed = !exit_status.success?
    rescue Timeout::Error
      terminate_process(pid)
    end

    entry = "[#{i + 1}/#{names.length}] #{name}"
    if crashed
      puts "  #{'✗'.error} #{entry} #{"(#{exit_status.inspect})".dim}"
      failures << name
    else
      puts "  #{'✓'.success} #{entry}"
    end
  end

  puts ''
  if failures.empty?
    print_task "All #{names.length} #{label} ran without crashing"
  else
    print_task "#{failures.length} #{item}(s) failed: #{failures.join(', ')}"
    exit 1
  end
end

# Copy a test file to work_dir, rewriting media path interpolations so the
# bundled (mruby/WASM) build can resolve them relative to its own asset layout.
def prepare_portable_test(test_file, work_dir)
  source = File.read("test/#{test_file}.rb")
  source.gsub!('#{Ruby2D.test_media}', 'media')
  source.gsub!('#{Ruby2D.test_audio}', 'media/audio')
  source.gsub!('#{Ruby2D.test_images}', 'media/images')
  source.gsub!('#{Ruby2D.test_spritesheets}', 'media/spritesheets')
  source.gsub!('#{Ruby2D.assets}/resources/fonts', 'ruby2d/fonts')
  source.gsub!(/^.*Ruby2D\.gem_dir.*\n/, '')
  File.write(File.join(work_dir, "#{test_file}.rb"), source)
end

# Build a test for a target (:native or :web) in test/build/<target>; returns
# the working directory. The rewritten test source and the test media are
# staged into the work dir, and `--assets media` bundles the media for either
# target (prepare_portable_test rewrites the test's media references to
# match). `ruby2d build` bundles the default fonts on its own.
def build_test(target, test_file)
  work_dir = File.expand_path("test/build/#{target}", __dir__)
  FileUtils.rm_rf(work_dir)
  FileUtils.mkdir_p(work_dir)
  prepare_portable_test(test_file, work_dir)
  FileUtils.cp_r(File.expand_path('assets/test_media', __dir__), File.join(work_dir, 'media'))
  run_cmd "( cd #{work_dir} && ruby2d build --#{target} --assets media #{test_file}.rb --debug )"
  work_dir
end

# Shell command to launch a built native app (tests and examples).
def launch_native_cmd(work_dir)
  if AssetsTarget.host_os == 'windows'
    "( cd #{work_dir}/build/native && app.exe )"
  else
    "( cd #{work_dir}/build/native && ./app )"
  end
end

# Print an example's header comment (title, description, controls) the same way
# `ruby2d examples` does, so a launched example announces itself.
def show_example_header(example)
  parsed = Ruby2D::CLI::Examples.find(example)
  Ruby2D::CLI::Examples.print_header(parsed) if parsed
end

# Asset directories an example declares with `# ruby2d:assets <dir>` directives
# (the same lines `ruby2d build` reads). The build resolves these against its
# working directory, so build_example mirrors them into the work dir first.
def example_asset_dirs(example)
  File.foreach("examples/#{example}.rb").filter_map do |line|
    line[/\A\s*#\s*ruby2d:assets\s+(\S.*?)\s*\z/, 1]
  end
end

# Build an example for a target (:native or :web) in examples/build/<target>,
# the way tests build in test/build/. Returns the working directory. Any asset
# dirs the example declares (repo-relative, e.g. assets/resources/...) are
# mirrored into the work dir at the same relative path — `ruby2d build`
# resolves and bundles them from its working directory, which is what
# otherwise forced the build to run at the repo root. `--debug` echoes the
# compile commands (as `rake test` does).
def build_example(target, example)
  work_dir = File.expand_path("examples/build/#{target}", __dir__)
  FileUtils.rm_rf(work_dir)
  FileUtils.mkdir_p(work_dir)
  example_asset_dirs(example).each do |dir|
    src = File.expand_path(dir, __dir__)
    next unless Dir.exist?(src) # a missing dir fails cleanly in `ruby2d build`

    FileUtils.mkdir_p(File.join(work_dir, File.dirname(dir)))
    FileUtils.cp_r(src, File.join(work_dir, dir))
  end
  run_cmd "( cd #{work_dir} && ruby2d build --#{target} ../../#{example}.rb --debug )"
  work_dir
end

# Tasks ########################################################################

task default: 'all'

desc "Generate .clangd from the active Ruby (for the C-extension LSP)"
task :clangd do
  content = <<~YAML
    # Generated by `rake clangd`; do not edit. Regenerated on `rake` whenever
    # the active Ruby's header paths change (e.g. after `rbenv local <ver>`).
    CompileFlags:
      Add:
        - -I../../assets/platform/include
        - -I#{RbConfig::CONFIG['rubyhdrdir']}
        - -I#{RbConfig::CONFIG['rubyarchhdrdir']}
  YAML

  path = File.expand_path('.clangd', __dir__)
  # Keep the content above ASCII-only: a non-ASCII byte makes String#==
  # encoding-sensitive, which fails this check on Windows and rewrites every run.
  next if File.exist?(path) && File.read(path) == content

  File.write(path, content)
  puts "  #{"Generated .clangd for Ruby #{RUBY_VERSION}".dim}"
end

desc "Uninstall gem"
task :uninstall do
  print_task "Uninstalling", spaced: false
  run_cmd "gem uninstall ruby2d --executables"
end

desc "Build gem"
task :build do
  print_task "Building", spaced: false
  run_cmd 'gem build ruby2d.gemspec --verbose'
end

desc "Install gem"
task :install do
  print_task "Installing", spaced: false
  # `--with-bundled-libs` tells extconf this is a local build, so it links the
  # working tree's `assets/platform` (packaged by `rake build`) and fails rather
  # than falling back to a `ruby2d setup` cache or system SDL3. Override with
  # `CONFIGURE_ARGS=--with-system-libs rake`, which takes precedence.
  run_cmd "gem install ruby2d-#{Ruby2D::VERSION}.gem --local --verbose -- --with-bundled-libs"
end

desc "Update submodules"
task :update do
  run_cmd "git submodule update --init --remote --depth 1"
end

namespace :deps do
  desc "Build dependencies (SDL3 libraries and mruby) from source"
  task :build do
    print_task "Building dependencies from source", spaced: false
    run_cmd "( cd assets && rake build )"
  end
end

desc "Run the RSpec tests"
RSpec::Core::RakeTask.new(:spec) do
  print_task "Running RSpec"
end

desc "Run a test with CRuby (or use test:native/web/all/auto)"
task :test => 'test:ruby'

namespace :test do
  desc "Run a test with CRuby (standard Ruby interpreter)"
  task :ruby do
    with_test_name do |test_file|
      print_task "Running `#{test_file}.rb` with CRuby (standard Ruby interpreter)", spaced: false
      run_cmd "( cd test/ && ruby -I ../lib -w #{test_file}.rb )"
    end
  end

  desc "Run a test as a native executable (mruby)"
  task :native do
    with_test_name do |test_file|
      print_task "Running `#{test_file}.rb` as a native executable (mruby)", spaced: false
      work_dir = build_test(:native, test_file)
      run_cmd launch_native_cmd(work_dir)
    end
  end

  desc "Run a test as a web app (mruby + WebAssembly)"
  task :web do
    with_test_name do |test_file|
      print_task "Running `#{test_file}.rb` as a web app (mruby + WebAssembly)", spaced: false
      work_dir = build_test(:web, test_file)
      run_cmd "( cd #{work_dir} && ruby2d launch --web )"
    end
  end

  desc "Run all interactive tests sequentially (optional target: native, web)"
  task :all do
    run_all_task interactive_tests, label: 'interactive tests', item: 'test',
                 run_ruby: ->(name) { system("( cd test/ && ruby -I ../lib -w #{name}.rb )") },
                 build: method(:build_test)
  end

  desc "Auto-run each interactive test briefly to catch crashes (for CI/agents)"
  task :auto do
    auto_run_task interactive_tests, label: 'interactive tests', item: 'test',
                  timeout_env: 'RUBY2D_TEST_AUTO_TIMEOUT' do |name|
      spawn('ruby', '-I', '../lib', '-w', "#{name}.rb", chdir: 'test/')
    end
  end
end

desc "Run an example with CRuby (or use examples:native/web/all/auto)"
task :examples => 'examples:ruby'

namespace :examples do
  desc "Run an example with CRuby (standard Ruby interpreter)"
  task :ruby do
    with_example_name do |example|
      print_task "Running `#{example}.rb` with CRuby (standard Ruby interpreter)", spaced: false
      show_example_header(example)
      # Run from the repo root so examples that reference bundled assets by a
      # repo-relative path (e.g. `sprite_sheets` → `assets/resources/...`) resolve.
      run_cmd "ruby -I lib -w examples/#{example}.rb"
    end
  end

  desc "Run an example as a native executable (mruby)"
  task :native do
    with_example_name do |example|
      print_task "Running `#{example}.rb` as a native executable (mruby)", spaced: false
      show_example_header(example)
      work_dir = build_example(:native, example)
      run_cmd launch_native_cmd(work_dir)
    end
  end

  desc "Run an example as a web app (mruby + WebAssembly)"
  task :web do
    with_example_name do |example|
      print_task "Running `#{example}.rb` as a web app (mruby + WebAssembly)", spaced: false
      show_example_header(example)
      work_dir = build_example(:web, example)
      run_cmd "( cd #{work_dir} && ruby2d launch --web )"
    end
  end

  desc "Run all examples sequentially (optional target: native, web)"
  task :all do
    run_all_task examples, label: 'examples', item: 'example',
                 run_ruby: ->(name) { system("ruby -I lib -w examples/#{name}.rb") },
                 build: method(:build_example)
  end

  desc "Auto-run each example briefly to catch crashes (for CI/agents)"
  task :auto do
    auto_run_task examples, label: 'examples', item: 'example',
                  timeout_env: 'RUBY2D_EXAMPLES_AUTO_TIMEOUT' do |name|
      spawn('ruby', '-I', 'lib', '-w', "examples/#{name}.rb")
    end
  end
end

desc "Generate and serve RDoc documentation"
task :docs do
  require 'rdoc/rdoc'

  output_dir = 'docs'

  print_task 'Generating RDoc'
  FileUtils.rm_rf(output_dir)
  RDoc::RDoc.new.document([
    '--output', output_dir,
    '--title', 'Ruby 2D API Documentation',
    '--main', 'README.md',
    '--markup', 'markdown',
    'lib/ruby2d',
    'README.md'
  ])

  print_task 'Serving docs'
  serve(dir: File.expand_path(output_dir), port: 8808)
end

BENCHMARKS = {
  baseline:           'empty window (frame-loop overhead ceiling)',
  retained:           'retained-mode rendering (objects added once)',
  mutation:           'retained-mode with per-frame attribute mutation',
  immediate:          'immediate-mode rendering (draw calls per frame)',
  immediate_gradient: 'immediate-mode rendering with per-vertex gradient colors',
  circles:            'circle rendering (high geometry count)',
  images:             'image/texture rendering (single source texture)',
  images_multi:       'image rendering across multiple source textures (rebind cost)',
  sprites:            'animated sprite rendering (clip-rect updates per frame)',
  text:               'text/font rendering',
  text_dynamic:       'text/font rendering with per-frame content changes',
  bitmap_text_dynamic: 'bitmap-font text with per-frame content changes',
  tiles:              'tileset rendering throughput (re-randomised per frame)',
  tiles_static:       'tileset rendering of a fixed map (common-case counterpart)',
  canvas:             'canvas drawing throughput (full clear + repaint per frame)',
  canvas_incremental: 'canvas incremental stamps onto a persistent surface',
  mixed:              'representative 2D game scene with mixed primitives'
}.freeze

def print_benchmark_help
  width = BENCHMARKS.keys.map { |n| n.to_s.length }.max
  puts "\n  #{'Ruby 2D'.ruby2d_red.bold} — Benchmarks #{'in benchmark/'.dim}\n\n"
  BENCHMARKS.each do |name, description|
    puts "    #{name.to_s.ljust(width)}  #{description.dim}"
  end
  puts "\n  #{'Usage:'.bold}\n\n"
  puts "    rake benchmark:#{'<name>'.dim}      # Run a specific benchmark"
  puts "    rake benchmark:all         # Run all benchmarks sequentially"
  puts ''
end

desc "List available benchmarks"
task :benchmark do
  print_benchmark_help
end

namespace :benchmark do
  BENCHMARKS.each do |name, description|
    desc "Benchmark: #{description}"
    task name do
      print_task "Benchmark: #{name}", spaced: false
      run_cmd "( cd benchmark/ && ruby -I ../lib -w #{name}.rb )"
    end
  end

  desc "Run all benchmarks sequentially"
  task all: BENCHMARKS.keys

  desc "Run a benchmark on the wasm/web build in headless Chrome, e.g. benchmark:web[retained]"
  task :web, [:name, :warmup, :duration] do |_t, args|
    name = args[:name] || 'retained'
    print_task "Web benchmark: #{name}", spaced: false
    run_cmd "ruby benchmark/web/run.rb #{name} #{args[:warmup]} #{args[:duration]}".strip
  end
end

namespace :try do
  desc "Build the 'Try Ruby 2D' interactive webpage"
  task :build do
    print_task "Building 'Try Ruby 2D' webpage", spaced: false
    run_cmd "ruby try/build.rb"
  end

  desc "Serve the 'Try Ruby 2D' interactive webpage locally"
  task :serve do
    print_task "Serving 'Try Ruby 2D' webpage"
    serve(dir: File.expand_path('try/build', __dir__), port: 8080, path: 'try.html')
  end
end

desc "Uninstall, build, install, and test"
task all: %w[clangd uninstall build install spec]

# Release ######################################################################

# Platform targets the 1.0 gem bundles via the `assets` submodule. Each must
# have a populated `assets/platform/<id>/` — the SDL3 + mruby static libs and
# an `mrbc` binary — or the packaged gem would silently omit that platform.
# IDs follow `AssetsTarget.target_id` ("<os>-<arch>[-<toolchain>]"), which is
# also how the build resolves the libs at compile time.
RELEASE_PLATFORMS = %w[
  macos-arm64
  windows-x86_64-mingw-ucrt
  windows-arm64-mingw-ucrt
].freeze

# Static libraries every platform dir must ship (mirrors assets/Rakefile).
RELEASE_PLATFORM_LIBS = %w[
  libSDL3.a libSDL3_image.a libSDL3_mixer.a libSDL3_ttf.a libmruby.a
].freeze

# The web target ships alongside the native ones — `assets/platform/wasm/lib`
# goes into the gem, and `ruby2d build --web` links against it — but it isn't a
# `RELEASE_PLATFORMS` entry: it has no `bin/mrbc` of its own (the host's is used
# to compile the bytecode), so it needs its own, lighter check.
RELEASE_WASM_DIR = 'wasm'

# Machines a release is verified on by hand before it goes out. This is the
# canonical list — RELEASING.md describes what to run and why, and defers here
# for the platforms themselves, so the two can't disagree.
RELEASE_TEST_PLATFORMS = [
  'macOS on Apple Silicon',
  'Windows on ARM, in both the arm64 and x64 terminals',
  'Ubuntu on x86_64',
  'Ubuntu on arm64'
].freeze

# The GitHub repo a release is tagged and announced in.
RELEASE_REPO = 'ruby2d/ruby2d'

# The branch a release is cut from. Preparation can happen anywhere, but the
# tag has to land on the branch the released code actually lives on.
RELEASE_BRANCH = 'main'

# The files ruby2d.com serves from `assets/try/`. The built `try.html` is
# deliberately not among them: it's the local smoke page (`try/test.html`),
# while the production page lives in the site repo as `_pages/try.html`.
TRY_ARTIFACTS = %w[app.js app.wasm app.data].freeze

# Where ruby2d.com keeps the example sources it renders. Only files already
# there are refreshed: not every example behaves in a browser, so the site
# publishes a curated subset, and which ones make the cut is the site's call —
# the sync updates what it finds, adds nothing, and removes nothing.
RUBY2D_COM_EXAMPLES = '_includes/examples'

# The ruby2d.com checkout the "Try Ruby 2D" build is deployed to, assumed to sit
# alongside this repo. Override with `RUBY2D_COM=/path/to/ruby2d.com rake release`.
def ruby2d_com_dir
  File.expand_path(ENV['RUBY2D_COM'] || '../ruby2d.com', __dir__)
end

# Platforms the `assets` submodule is missing artifacts for, described one per
# entry. Empty means the submodule can ship every platform the gem bundles.
def release_platform_problems
  problems = RELEASE_PLATFORMS.filter_map do |id|
    dir = File.join(release_platform_root, id)
    next "#{id} (directory missing)" unless Dir.exist?(dir)

    missing_libs = RELEASE_PLATFORM_LIBS.reject { |lib| File.exist?(File.join(dir, 'lib', lib)) }
    has_mrbc = !Dir.glob(File.join(dir, 'bin', 'mrbc*')).empty?

    lacking = []
    lacking << "libs: #{missing_libs.join(', ')}" unless missing_libs.empty?
    lacking << 'bin/mrbc' unless has_mrbc
    "#{id} (missing #{lacking.join('; ')})" unless lacking.empty?
  end

  wasm_dir = File.join(release_platform_root, RELEASE_WASM_DIR)
  if !Dir.exist?(wasm_dir)
    problems << "#{RELEASE_WASM_DIR} (directory missing)"
  else
    missing = RELEASE_PLATFORM_LIBS.reject { |lib| File.exist?(File.join(wasm_dir, 'lib', lib)) }
    problems << "#{RELEASE_WASM_DIR} (missing libs: #{missing.join(', ')})" unless missing.empty?
  end

  problems
end

def release_platform_root
  File.expand_path('assets/platform', __dir__)
end

# Platform dirs the submodule actually ships, so a mismatch against
# `RELEASE_PLATFORMS` is easy to spot by eye.
def present_release_platforms
  return [] unless Dir.exist?(release_platform_root)

  Dir.children(release_platform_root)
     .select { |c| File.directory?(File.join(release_platform_root, c)) }
     .reject { |c| c == 'include' }
     .sort
end

# Release state ################################################################

# Two steps leave nothing behind to check against — a passing test run, and a
# platform someone verified by hand. Record the commit each was confirmed at,
# filed under the version being released, so re-running `rake release` keeps the
# tick. The file is per-machine and gitignored, which is what the platform ticks
# want — each box tracks the runs it actually did.
RELEASE_STATE_FILE = File.expand_path('.release-state', __dir__)

def release_state
  require 'json'
  @release_state ||= begin
    JSON.parse(File.read(RELEASE_STATE_FILE))
  rescue StandardError
    {}
  end
end

# Read fresh every time rather than memoized: step 2 exists to send you off to
# commit something, and step 5 asks for a commit of its own, so HEAD moves
# mid-run as a matter of course. A value captured when the checklist first
# printed would file step 3 and 4's ticks against a commit whose tree was never
# the one tested — and then retire them on the next run for having "changed".
def git_head
  `git rev-parse HEAD 2>/dev/null`.chomp
end

# A tick holds only while HEAD is where it was — a ✓ earned against different
# code is worse than no ✓ at all. The one exception is the version bump: it
# lands between the testing steps and the release, and a commit that touches
# nothing but version.rb changes no behaviour those steps covered. An empty
# diff counts too, which is what an amend or a rebase onto identical content
# leaves behind. Anything else retires the tick.
def release_confirmed?(key)
  recorded = release_state.dig(release_version, key)
  head = git_head
  return false if recorded.nil? || head.empty?
  return true if recorded == head
  return false unless git_quiet('git', 'cat-file', '-e', "#{recorded}^{commit}")

  changed = `git diff --name-only #{recorded} #{head}`.split("\n")
  changed.all? { |path| path == 'lib/ruby2d/version.rb' }
end

def release_confirm!(key)
  (release_state[release_version] ||= {})[key] = git_head
  File.write(RELEASE_STATE_FILE, JSON.pretty_generate(release_state))
end

# Release checks ###############################################################

# The version being released — `VERSION` with any `.dev` taken off. The whole
# checklist is framed in these terms: the tag, the gem filename, and the state
# file's key all name the release rather than the working version, so they stay
# put across the bump in step 5 instead of shifting halfway through and
# stranding everything recorded before it.
def release_version
  Ruby2D::VERSION.sub(/\.dev\z/, '')
end

def release_tag
  "v#{release_version}"
end

def release_gem
  "ruby2d-#{release_version}.gem"
end

# Run a command for its exit status alone. Takes argv rather than one string so
# nothing reaches a shell: `^` in a git revision (`<sha>^{commit}`) is cmd.exe's
# escape character and would be eaten on Windows, and a bare `which` isn't there
# at all. Returns nil when the executable is missing, false when it failed.
def git_quiet(*cmd)
  system(*cmd, out: File::NULL, err: File::NULL)
end

# The three checks that leave the machine are asked repeatedly in a single pass
# over the checklist — once for the mark, once for the note, once to pick the
# next pending step. Hold each answer for the length of a pass; `release_fresh!`
# drops them after a step acts, since acting is what changes the answer.
def release_cached(key)
  cache = (@release_cache ||= {})
  cache.key?(key) ? cache[key] : (cache[key] = yield)
end

def release_fresh!
  @release_cache = {}
end

# The commit origin's release tag points at: a SHA, `nil` when the tag isn't
# there, or `:unreachable` when the remote couldn't be asked. `ls-remote` exits
# 0 with no output for a tag that simply doesn't exist and non-zero when it
# couldn't ask, so "no tag" and "don't know" stay distinct. An annotated tag
# adds a peeled `^{}` row naming the commit itself — that's the one to compare.
def release_tag_sha
  release_cached(:tag_sha) do
    out = `git ls-remote --tags origin #{release_tag} 2>/dev/null`
    next :unreachable unless $?.success?

    rows = out.lines.map(&:split)
    peeled = rows.find { |(_, ref)| ref&.end_with?('^{}') }
    (peeled || rows.first)&.first
  end
end

# Whether the release tag is on origin *and* points at the commit checked out
# here. Existence alone isn't enough: a release created before the version-bump
# commit was pushed, or aimed at the wrong branch in GitHub's form, leaves a tag
# that doesn't contain the code the gem was built from — and a ✓ that would say
# otherwise, permanently.
def release_tag_pushed?
  sha = release_tag_sha
  return nil if sha == :unreachable

  sha == git_head
end

# The checked-out branch, or 'HEAD' when the checkout is detached.
def current_branch
  `git rev-parse --abbrev-ref HEAD 2>/dev/null`.chomp
end

def on_release_branch?
  current_branch == RELEASE_BRANCH
end

# Tracked files with uncommitted changes, as `git status` short lines.
def git_dirty_files
  `git status --porcelain --untracked-files=no`.lines.map(&:chomp)
end

# Untracked files that a gemspec glob would sweep up. `s.files` globs the
# working tree rather than asking git, so an untracked file under `lib/` or
# `ext/` ships in the gem without ever having been committed.
def untracked_gem_files
  untracked = `git ls-files --others --exclude-standard`.lines.map(&:chomp)
  return [] if untracked.empty?

  # Loading the gemspec re-globs `assets/platform/**/*` over the whole vendored
  # tree, so hold the file list for the pass rather than paying for it per call.
  packaged = release_cached(:gem_files) do
    Gem::Specification.load('ruby2d.gemspec').files
  rescue StandardError
    nil
  end
  packaged ? untracked & packaged : []
end

# Whether this version is already on rubygems.org. Network-dependent, so a
# failure answers `nil` — "don't know" — rather than "not published"; the
# checklist shows the step pending with the reason instead of asserting a fact
# it couldn't actually check.
def published_to_rubygems?
  release_cached(:rubygems) do
    require 'net/http'
    require 'json'
    uri = URI('https://rubygems.org/api/v1/versions/ruby2d.json')
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: true,
                               open_timeout: 3, read_timeout: 5) { |http| http.get(uri.path) }
    next nil unless response.is_a?(Net::HTTPSuccess)

    JSON.parse(response.body).any? { |v| v['number'] == release_version }
  rescue StandardError
    nil
  end
end

# Whether the release already exists on GitHub, or `nil` if `gh` isn't around
# to say — the same "don't know" convention as the rubygems check. Probed by
# running `gh` rather than by looking for it on PATH: `which` doesn't exist on
# Windows, and the release is verified there too.
def github_release_exists?
  release_cached(:gh_release) do
    next nil if git_quiet('gh', '--version').nil?

    git_quiet('gh', 'release', 'view', release_tag, '--repo', RELEASE_REPO)
  end
end

def site_examples_dir
  File.join(ruby2d_com_dir, RUBY2D_COM_EXAMPLES)
end

def site_example_names
  return [] unless Dir.exist?(site_examples_dir)

  Dir.children(site_examples_dir).select { |name| name.end_with?('.rb') }.sort
end

def repo_example_path(name)
  File.expand_path("examples/#{name}", __dir__)
end

# Published examples paired with their source here. A site file with no
# counterpart is left out of the pairing — copying can't fix an example that
# was deleted from the repo, so it's reported instead.
def site_example_pairs
  site_example_names.filter_map do |name|
    source = repo_example_path(name)
    [source, File.join(site_examples_dir, name)] if File.exist?(source)
  end
end

def stale_site_examples
  site_example_pairs.reject { |source, published| FileUtils.identical?(source, published) }
end

# Published examples whose source has been deleted from this repo — the site
# would still be rendering code for an example that no longer ships.
def orphaned_site_examples
  site_example_names.reject { |name| File.exist?(repo_example_path(name)) }
end

# Examples here that the site doesn't carry. Not a problem — the subset is
# deliberate — but worth naming, since a newly added example stays invisible
# on ruby2d.com until someone puts it there on purpose.
def unpublished_examples
  return [] unless Dir.exist?(site_examples_dir)

  published = site_example_names
  Dir.children(File.expand_path('examples', __dir__))
     .select { |name| name.end_with?('.rb') && !published.include?(name) }
     .sort
end

# Source files the "Try Ruby 2D" build is compiled from — the same library list
# the build itself reads, plus the C extension and the build's own inputs.
def try_source_files
  Ruby2D::LIB_FILES.map { |f| File.expand_path("lib/ruby2d/#{f}.rb", __dir__) } +
    Dir[File.expand_path('ext/ruby2d/*.{c,h}', __dir__)] +
    [File.expand_path('try/try_main.c', __dir__), File.expand_path('try/build.rb', __dir__)]
end

# Whether ruby2d.com already carries a current "Try Ruby 2D" build. Matching
# content isn't sufficient on its own: `try/build/` still holds whatever was
# deployed last time, so a second release from the same machine would match
# itself and skip the rebuild — and the artifacts carry no version to give it
# away, since `version.rb` isn't among the files compiled in. So the build has
# to be newer than everything it was built from, and the deployed copy has to
# match it byte for byte.
def try_synced?
  require 'digest'
  dest = File.join(ruby2d_com_dir, 'assets', 'try')
  built = TRY_ARTIFACTS.map { |name| File.expand_path("try/build/#{name}", __dir__) }
  return false unless built.all? { |path| File.exist?(path) }

  newest_source = try_source_files.select { |f| File.exist?(f) }.map { |f| File.mtime(f) }.max
  return false if newest_source && built.map { |f| File.mtime(f) }.min < newest_source

  built.all? do |src|
    dst = File.join(dest, File.basename(src))
    File.exist?(dst) && Digest::SHA256.file(src) == Digest::SHA256.file(dst)
  end
end

# Release output ###############################################################

# Ask a yes/no question with a default. A bare Enter takes the default; EOF
# answers no, so a run whose stdin closed underneath it stops rather than
# consenting to something on the user's behalf.
def ask?(question, default: true)
  print "    #{question} #{"[#{default ? 'Y/n' : 'y/N'}]".dim} "
  answer = $stdin.gets
  return false if answer.nil?

  answer = answer.strip.downcase
  answer.empty? ? default : answer.start_with?('y')
end

# Hold the walkthrough at a step it can't perform itself. Enter re-checks and
# moves on; Ctrl-C leaves the checklist exactly where it stands. The terminal
# echoes the Enter, so one `puts` is all it takes to leave a single blank line
# behind — whatever comes next brings its own leading gap.
def pause
  print "\n    #{'Press Enter to re-check, or Ctrl-C to stop here...'.dim}"
  $stdin.gets
  puts
end

# A command for the user to run themselves. Bold, and without the dim `$` that
# `run_cmd` prints — that prefix marks a command the task is running, and these
# are precisely the ones it deliberately isn't.
def print_cmd(cmd)
  puts "      #{cmd.bold}"
end

# Release steps ################################################################

# One line of the checklist. `check` answers true, false, or nil for "couldn't
# tell"; `detail` is the dim note beside the title; `stop` marks a step that
# ends the run when its action reports having rewritten the version this run was
# built around. `key` identifies a step across re-derivations of the list, which
# the walkthrough leans on to tell "ran and didn't land" from "not reached yet".
ReleaseStep = Struct.new(:key, :title, :check, :detail, :action, :stop, keyword_init: true)

# Rewrite the VERSION constant in place, leaving the rest of version.rb alone.
def write_version(version)
  path = File.expand_path('lib/ruby2d/version.rb', __dir__)
  source = File.read(path)
  updated = source.sub(/VERSION = '[^']*'/, "VERSION = '#{version}'")
  if updated == source
    error "Couldn't find the VERSION constant in lib/ruby2d/version.rb.", indent: 4
    return false
  end

  File.write(path, updated)
  puts "    #{'wrote'.dim} lib/ruby2d/version.rb #{"(#{version})".dim}"
  true
end

# The `.dev` version to return to after a release — the next minor, since that's
# the usual next line of work. Offered as a default; anything typed wins.
def next_dev_version
  major, minor, = release_version.split('.').map(&:to_i)
  "#{major}.#{minor + 1}.0.dev"
end

# Step 1 — the gem bundles prebuilt libraries per platform, and a missing
# platform dir doesn't fail the build, it just quietly ships without support
# for that target. `rake update` pulls the submodule fresh, which is the fix
# whenever the assets repo has the artifacts and this checkout doesn't.
def release_check_platforms
  print_task 'Assets submodule platforms'
  release_platform_problems.each { |p| puts "    #{'✗'.error} #{p}" }
  present = present_release_platforms
  puts "\n    Present: #{present.empty? ? '(none)' : present.join(', ')}\n\n"
  puts '    Update the assets repo (see its README), or correct RELEASE_PLATFORMS'
  puts "    in the Rakefile if these IDs are no longer the ones that ship.\n\n"
  Rake::Task['update'].invoke if ask?('Run `rake update` to refresh the submodule?')
  pause
end

# Step 2 — releases are cut from one branch, and the gem is packed from the
# working tree rather than from git, so anything uncommitted ships as part of
# it. Untracked files count too: the gemspec globs the tree.
def release_check_repo
  print_task 'Branch and working tree'
  dirty = git_dirty_files
  untracked = untracked_gem_files
  printed = false

  unless on_release_branch?
    branch = current_branch
    where = branch == 'HEAD' ? 'is a detached HEAD' : "is on `#{branch}`"
    puts "    Releases are cut from `#{RELEASE_BRANCH}` — that's the branch the tag lands on."
    puts "    This checkout #{where}. Merge the work in and check it out."
    printed = true
  end

  unless dirty.empty?
    puts '' if printed
    puts "    Uncommitted changes — the gem is packed from the tree, not from git:\n\n"
    dirty.each { |line| puts "      #{line}" }
    printed = true
  end

  unless untracked.empty?
    puts '' if printed
    puts "    Untracked, but inside a gemspec glob — these would ship uncommitted:\n\n"
    untracked.each { |path| puts "      #{path}" }
  end

  pause
end

# Step 3 — the default task: uninstall, rebuild the C extension, reinstall, and
# run RSpec. The local gate before going near four machines; the gem it leaves
# behind is still the working version's, so step 7 rebuilds after the bump.
def release_build_and_test
  print_task 'Build, install, and test'
  Rake::Task['all'].invoke
  release_confirm!('test')
end

# Step 4 — the one part of a release nothing here can attest to. Ask about each
# platform in turn and record the ones confirmed. The ticks are per-machine, so
# each box tracks what it actually ran; `release_confirmed?` decides how long
# one survives.
def release_verify_platforms
  print_task 'Verify each platform by hand'
  puts "    On each, with the latest Ruby installed, run all four:\n\n"
  print_cmd 'rake'
  print_cmd 'rake test:all'
  print_cmd 'rake test:all native'
  print_cmd 'rake test:all web'
  puts "\n    Press Esc to advance a window; Enter in the terminal for the web runs.\n\n"

  RELEASE_TEST_PLATFORMS.each do |platform|
    key = "platform:#{platform}"
    if release_confirmed?(key)
      puts "    #{'✓'.success} #{platform}"
    elsif ask?("#{'○'.dim} #{platform} — all four passed?", default: false)
      release_confirm!(key)
    end
  end
  puts ''
end

# Step 5 — take the `.dev` off. This is the last commit before the tag, and it
# comes after the testing rather than before it: nothing has been published yet,
# so a platform that fails above costs a re-test, not a stray "Version 1.0.0"
# commit sitting in the history. `Ruby2D::VERSION` was read into the constant
# when this Rakefile loaded, so the run can't continue against the new number —
# write the file, hand over the commit, and ask for a fresh `rake release`.
def release_set_version
  print_task "Set the version to #{release_version}"
  puts '    Between releases the version carries `.dev` so a source install is'
  puts '    clearly distinct from a published gem. Releasing takes it off, and'
  puts "    this is the commit the tag will point at.\n\n"
  return unless ask?("Write #{release_version} to lib/ruby2d/version.rb?")
  return unless write_version(release_version)

  puts "\n    Commit it, then start the checklist again:\n\n"
  print_cmd "git commit -am 'Version #{release_version}'"
  print_cmd 'rake release'
  puts ''
  # Only now is the constant this run was built around out of date. Declining
  # the prompt changes nothing, so the walk carries on and re-reports the step.
  :rewrote_version
end

# Step 6 — the tag and the announcement are one action: GitHub creates the tag
# when the release is published, so the marker and the notes land together. It
# can only tag a commit it can see, hence the push first. Ahead of the gem, so
# the commit a release was built from is public before the artifact is.
def release_tag_and_announce
  print_task "Tag and announce #{release_tag}"
  puts "    Push the commit GitHub will tag:\n\n"
  print_cmd "git push origin #{RELEASE_BRANCH}"
  puts "\n    Then create the release against tag `#{release_tag}`, and write a"
  puts "    little release note — GitHub makes the tag when you publish it:\n\n"
  print_cmd "https://github.com/#{RELEASE_REPO}/releases/new?tag=#{release_tag}"
  puts "\n    Or with `gh`, which prompts for the title and notes:\n\n"
  print_cmd "gh release create #{release_tag} --repo #{RELEASE_REPO}"
  pause
end

# Step 7 — the point of no return: a pushed version can be yanked, but never
# replaced. Everything above it is undoable, which is why it sits this late.
# The gem is built here rather than carried down from step 3, which ran before
# the bump and so produced the working version's gem, not the release's.
def release_publish_gem
  print_task 'Build the release gem'
  # Scoped to this gem's own artifacts — the repo root isn't ours to sweep.
  stale = Dir.glob('ruby2d-*.gem') - [release_gem]
  unless stale.empty?
    stale.each { |f| FileUtils.rm(f) }
    puts "    #{"removed #{stale.join(', ')}".dim}"
  end
  # A rake task runs at most once per process, and step 3's `all` may already
  # have invoked `build` in this run — in which case `invoke` alone would
  # silently do nothing and leave whatever gem step 3 produced sitting there
  # as the thing to push. Re-enable it so this always builds.
  Rake::Task['build'].reenable
  Rake::Task['build'].invoke

  print_task 'Push to RubyGems'
  puts "    This one is permanent. Push the gem just built:\n\n"
  print_cmd "gem push #{release_gem}"
  pause
end

# Step 8 — rebuild the WebAssembly "Try Ruby 2D" page against the released
# source and copy the artifacts into the site repo. Only the three build outputs
# move: the page around them is the site's own.
def release_sync_try
  print_task 'Build and sync "Try Ruby 2D"'
  dest = File.join(ruby2d_com_dir, 'assets', 'try')
  unless Dir.exist?(dest)
    error "No #{dest}", indent: 4
    puts "    Set RUBY2D_COM if the ruby2d.com checkout isn't alongside this repo.\n\n"
    return
  end

  Rake::Task['try:build'].invoke
  print_task 'Syncing to ruby2d.com'
  TRY_ARTIFACTS.each do |name|
    FileUtils.cp(File.expand_path("try/build/#{name}", __dir__), File.join(dest, name))
    puts "    #{'copied'.dim} assets/try/#{name}"
  end

  # The copy is what this step checks for, so it's already satisfied — the pause
  # is there to keep the site commit from being scrolled past on the way to the
  # last step, since nothing here can verify it happened.
  puts "\n    Commit them in the site repo:\n\n"
  print_cmd "cd #{ruby2d_com_dir}"
  print_cmd 'git add assets/try'
  print_cmd "git commit -m 'Update Try Ruby 2D for #{release_version}'"
  pause
end

# Step 9 — refresh the example sources ruby2d.com renders from. Deliberately a
# one-way update of what's already published and nothing more: not every example
# behaves in a browser, so the site carries a curated subset, and adding to it is
# a judgement about the web that belongs with the site, not with a release task.
# So an example missing from the site stays missing, and one whose source has
# been deleted here is reported rather than removed.
def release_sync_examples
  print_task 'Sync examples to ruby2d.com'
  unless Dir.exist?(site_examples_dir)
    error "No #{site_examples_dir}", indent: 4
    puts "    Set RUBY2D_COM if the ruby2d.com checkout isn't alongside this repo.\n\n"
    return
  end

  stale = stale_site_examples
  stale.each do |source, published|
    FileUtils.cp(source, published)
    puts "    #{'copied'.dim} #{File.basename(source)}"
  end

  report_example_drift

  return if stale.empty?

  puts "\n    Commit them in the site repo:\n\n"
  print_cmd "cd #{ruby2d_com_dir}"
  print_cmd "git add #{RUBY2D_COM_EXAMPLES}"
  print_cmd "git commit -m 'Update examples for #{release_version}'"
  pause
end

# The two ways the directories can drift that copying can't settle. Neither
# blocks the release — both are decisions about what the site should carry —
# but a release is the moment they're worth seeing.
def report_example_drift
  print_drift(orphaned_site_examples,
              'published but no longer in `examples/` — remove from the site:')
  print_drift(unpublished_examples,
              'in `examples/` but not published — add any that work in a browser:')
end

# List filenames under a heading, capped so a wide drift doesn't bury the step.
# The count leads the heading, so a truncated list still says how many.
def print_drift(names, heading, limit: 8)
  return if names.empty?

  puts "\n    #{names.length} #{heading}\n\n"
  names.first(limit).each { |name| puts "      #{name}" }
  puts "      #{"…and #{names.length - limit} more".dim}" if names.length > limit
end

# Step 10 — back to `.dev`, which closes the release: this run was built around
# the release version, and the next `rake release` belongs to the next one.
def release_start_next_dev
  suggested = next_dev_version
  print_task 'Back to a development version'
  puts "    With #{release_version} out, the version returns to `.dev` so a"
  puts "    source install stays distinct from the published gem.\n\n"
  print "    Next version #{"[#{suggested}]".dim} "
  answer = $stdin.gets
  return if answer.nil?

  version = answer.strip
  version = suggested if version.empty?

  # Whatever is typed here goes straight into the constant, so a typo would
  # leave the tree claiming a version that isn't one — and dropping the `.dev`
  # would leave it claiming to be releasable, which is the opposite of what
  # this step is for. Both are worth catching before the write.
  unless version.match?(/\A\d+\.\d+\.\d+.*\.dev\z/)
    error "`#{version}` isn't a `.dev` version (e.g. #{suggested}).", spaced: true, indent: 4
    puts "    Leaving lib/ruby2d/version.rb alone.\n\n"
    return
  end

  return unless write_version(version)

  release_state.delete(release_version)
  File.write(RELEASE_STATE_FILE, JSON.pretty_generate(release_state))

  puts "\n    Commit it, and that's the release:\n\n"
  print_cmd "git commit -am 'Version #{version}'"
  print_task "Ruby 2D #{release_version} is out 🎉"
  :rewrote_version
end

def release_steps
  [
    ReleaseStep.new(
      key: 'assets',
      title: 'Assets submodule carries every platform',
      check: -> { release_platform_problems.empty? },
      detail: lambda {
        problems = release_platform_problems
        next "#{problems.length} incomplete" unless problems.empty?

        "#{RELEASE_PLATFORMS.length} platforms + wasm"
      },
      action: -> { release_check_platforms }
    ),
    ReleaseStep.new(
      key: 'repo',
      title: "On `#{RELEASE_BRANCH}` with a clean working tree",
      check: -> { on_release_branch? && git_dirty_files.empty? && untracked_gem_files.empty? },
      detail: lambda {
        notes = []
        notes << "on `#{current_branch}`" unless on_release_branch?
        pending = git_dirty_files.length + untracked_gem_files.length
        notes << "#{pending} uncommitted file#{'s' if pending != 1}" if pending.positive?
        notes.join(', ') unless notes.empty?
      },
      action: -> { release_check_repo }
    ),
    ReleaseStep.new(
      key: 'tested',
      title: 'Built, installed, and tested',
      check: -> { release_confirmed?('test') },
      detail: -> { 'no run recorded against this commit' unless release_confirmed?('test') },
      action: -> { release_build_and_test }
    ),
    ReleaseStep.new(
      key: 'platforms',
      title: 'Verified on every platform',
      check: -> { RELEASE_TEST_PLATFORMS.all? { |p| release_confirmed?("platform:#{p}") } },
      detail: lambda {
        done = RELEASE_TEST_PLATFORMS.count { |p| release_confirmed?("platform:#{p}") }
        "#{done} of #{RELEASE_TEST_PLATFORMS.length}"
      },
      action: -> { release_verify_platforms }
    ),
    ReleaseStep.new(
      key: 'version',
      title: 'Version set to a release version',
      check: -> { !Ruby2D::VERSION.end_with?('.dev') },
      detail: -> { Ruby2D::VERSION if Ruby2D::VERSION.end_with?('.dev') },
      action: -> { release_set_version },
      stop: true
    ),
    ReleaseStep.new(
      key: 'tagged',
      # Checked by the tag on origin rather than by `gh`: publishing a GitHub
      # release is what creates and pushes the tag, so the tag being there is
      # the evidence, and it holds whether or not `gh` is installed. `gh` only
      # sharpens the note — a tag pushed by hand leaves the notes unwritten.
      title: "Tagged and announced as #{release_tag}",
      check: -> { release_tag_pushed? },
      detail: lambda {
        next "couldn't reach origin" if release_tag_pushed?.nil?
        next 'tag is on a different commit' if release_tag_sha && !release_tag_pushed?
        next '`gh` not installed — check the notes by hand' if github_release_exists?.nil?

        'tag pushed, but no release notes' if release_tag_pushed? && !github_release_exists?
      },
      action: -> { release_tag_and_announce }
    ),
    ReleaseStep.new(
      key: 'published',
      title: 'Published to RubyGems',
      check: -> { published_to_rubygems? },
      detail: -> { "couldn't reach rubygems.org" if published_to_rubygems?.nil? },
      action: -> { release_publish_gem }
    ),
    ReleaseStep.new(
      key: 'try',
      title: '"Try Ruby 2D" synced to ruby2d.com',
      check: -> { try_synced? },
      detail: -> { "no #{ruby2d_com_dir}" unless Dir.exist?(ruby2d_com_dir) },
      action: -> { release_sync_try }
    ),
    ReleaseStep.new(
      key: 'examples',
      title: 'Published examples synced to ruby2d.com',
      # Only the files the site already carries are compared, so an example it
      # deliberately doesn't publish can never hold the release up.
      check: -> { Dir.exist?(site_examples_dir) && stale_site_examples.empty? },
      detail: lambda {
        next "no #{site_examples_dir}" unless Dir.exist?(site_examples_dir)

        notes = []
        notes << "#{stale_site_examples.length} to refresh" unless stale_site_examples.empty?
        orphans = orphaned_site_examples.length
        notes << "#{orphans} since deleted" if orphans.positive?
        unpublished = unpublished_examples.length
        notes << "#{unpublished} unpublished" if unpublished.positive?
        notes.join(', ') unless notes.empty?
      },
      action: -> { release_sync_examples }
    ),
    ReleaseStep.new(
      key: 'nextdev',
      title: 'Version back to a `.dev` version',
      # Never satisfiable mid-run, and correct either way it's read: once the
      # version is a release version, this plainly hasn't happened yet; before
      # that, the release hasn't reached step 5, and a ✓ would read as though
      # it had already finished. Once step 9 writes the next `.dev`, the run
      # ends — the checklist that follows belongs to the next version.
      check: -> { false },
      detail: -> { "→ #{next_dev_version}" unless Ruby2D::VERSION.end_with?('.dev') },
      action: -> { release_start_next_dev },
      stop: true
    )
  ]
end

# The checklist itself: every step, marked ✓ when something on disk, in git, or
# on rubygems.org says so, and ○ when it doesn't — including when the check
# couldn't reach far enough to tell, which the dim note says.
def print_release_checklist(steps)
  release_fresh!
  print_task "Ruby 2D #{release_version} — release checklist"
  steps.each_with_index do |step, i|
    mark = step.check.call ? '✓'.success : '○'.dim
    detail = step.detail&.call
    puts "    #{mark} #{"#{i + 1}.".rjust(3)} #{step.title}#{"  #{detail.dim}" if detail}"
  end
  puts ''
end

# Walk the checklist: print it, then keep taking the first step that isn't done.
#
# The pending set is re-derived after every action rather than fixed up front,
# because an action can undo an earlier step — step 1's `rake update` moves the
# submodule pointer, which is exactly the uncommitted change step 2 exists to
# catch. Re-deriving sends the walk back to it instead of carrying on and
# packing a gem around a submodule nobody committed.
#
# A step that runs and still isn't done ends the walk rather than letting the
# next one build on it; there's no point pushing a gem that wasn't built.
# Nothing is lost by stopping — every ✓ is derived from the tree, from git, from
# origin, or from rubygems.org, so the next `rake release` resumes right here.
def release_walkthrough
  print_release_checklist(release_steps)

  unless $stdin.tty?
    puts "    #{'Not a terminal — showing the checklist only.'.dim}\n\n"
    return
  end

  acted = nil
  waived = []

  loop do
    release_fresh!
    step = release_steps.find { |s| !waived.include?(s.key) && !s.check.call }
    break if step.nil? # guard: step 9 is always pending, so this doesn't fire

    if step.key == acted
      # It ran and didn't land. A check that couldn't tell either way is the one
      # worth offering to move past — waiting won't resolve an absent `gh` or a
      # dead network, and the printed command is the real work regardless.
      if step.check.call.nil? && ask?("Couldn't verify that one. Carry on anyway?", default: false)
        waived << step.key
        acted = nil
        next
      end

      print_release_checklist(release_steps)
      todo = "Still to do: #{step.title.downcase}. Re-run `rake release` to continue."
      puts "    #{todo.dim}\n\n"
      return
    end

    acted = step.key
    return if step.action.call == :rewrote_version && step.stop
  end

  print_release_checklist(release_steps)
end

desc "Walk through the release checklist"
task :release do
  release_walkthrough
rescue Interrupt
  puts "\n\n    #{'Stopped — re-run `rake release` to pick up where you left off.'.dim}\n\n"
  exit 130
end
