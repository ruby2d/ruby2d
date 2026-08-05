# Run a Ruby 2D benchmark on the wasm/web build and print its report.
#
#   ruby benchmark/web/run.rb <name> [warmup_s] [duration_s]
#
# Pipeline: inline the harness + the named scene into one self-contained source
# (the web build has no `require` and doesn't bundle `benchmark.rb`), compile it
# with `ruby2d build --web`, then run it in headless Chrome via `drive.js` and
# capture the printed report. The web build compiles the *installed* gem's lib,
# so run `rake` after editing `lib/` before benchmarking a lib change here.
#
# Requires: emcc (Emscripten), node (>= 22), and Google Chrome. On web, read the
# CPU-build *averages*, not percentiles — `performance.now()` is ~1ms-quantized
# in the browser, so percentiles are too coarse; averaging many frames recovers
# sub-ms precision. Software WebGL (SwiftShader) is slower than a real GPU but
# consistent, so relative A/B comparisons hold.

ROOT     = File.expand_path('../..', __dir__)
WEB_DIR  = __dir__
BUILD    = File.join(WEB_DIR, '.build')
name     = ARGV[0] || 'retained'
warmup   = (ARGV[1] || 5).to_i
duration = (ARGV[2] || 3).to_i

scene_path = File.join(ROOT, 'benchmark', "#{name}.rb")
abort "No such benchmark: #{name} (#{scene_path} not found)" unless File.exist?(scene_path)

# Tool check — fail early with a clear message rather than deep in the build.
def tool?(cmd) = system("command -v #{cmd} > /dev/null 2>&1")
chrome = ENV['CHROME'] || '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'
missing = []
missing << 'emcc (Emscripten)'   unless tool?('emcc')
missing << 'node'                unless tool?('node')
missing << 'Google Chrome'       unless File.exist?(chrome)
abort "Missing required tool(s): #{missing.join(', ')}" unless missing.empty?

# Inline harness + scene into one self-contained source. Strip every `require`
# (mruby has none, and the harness isn't in the bundled lib), and inject the
# web-scaled warmup/duration into the scene's `Benchmark.run(...)` call.
harness = File.read(File.join(ROOT, 'lib', 'ruby2d', 'benchmark.rb'))
scene   = File.read(scene_path)
              .gsub(/^\s*require\s.*$/, '')
              .sub(/Ruby2D::Benchmark\.run\((\s*'[^']*'|\s*"[^"]*")\)/,
                   "Ruby2D::Benchmark.run(\\1, warmup: #{warmup}, duration: #{duration})")

require 'fileutils'
FileUtils.rm_rf(BUILD)
FileUtils.mkdir_p(BUILD)
merged = File.join(BUILD, "#{name}_web.rb")
File.write(merged, "# Auto-generated self-contained web benchmark.\n#{harness}\n#{scene}")

puts "Building #{name} for web (warmup #{warmup}s, measure #{duration}s)..."
Dir.chdir(BUILD) do
  abort 'ruby2d build --web failed' unless system('ruby2d', 'build', '--web', File.basename(merged))
end

out = File.join(BUILD, 'build', 'web')
abort "Build produced no #{out}/app.html" unless File.exist?(File.join(out, 'app.html'))

puts "Running in headless Chrome...\n\n"
ok = system('node', File.join(WEB_DIR, 'drive.js'), out, 'app.html')
exit(ok ? 0 : 1)
