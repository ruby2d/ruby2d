# Run one example from ../examples on CRuby, mruby and Spinel, and report what
# each engine costs per frame.
#
#   ruby spinel/tools/fps.rb [name] [frames]     # or `cd spinel && rake fps[name]`
#   ruby spinel/tools/fps.rb balls               # the default
#   ruby spinel/tools/fps.rb fountain 300
#
# ## What is measured, and why it is not fps
#
# **Wall-clock fps cannot answer this on a desktop.** `SDL_RenderPresent` blocks
# at the display's refresh rate whatever the fps cap says — measured at ~120fps
# for 5 balls and for 3000, with vsync off *and* with a finite 10,000fps cap.
# All three engines tie at the refresh rate and the number says nothing.
# `benchmark/README.md` says as much for the native harness and solves it by
# subtracting present out with two harness-only method wrappers; that is runtime
# monkey-patching, which cannot work on an AOT target.
#
# So this times the Ruby side: the example's `update` block, plus the
# scene-graph dispatch that draws every object. Present and the GPU are
# identical across the three engines and sit outside the timed region.
#
# ## How, without the example knowing
#
# The harness below is spliced in ahead of `show`. It takes the procs the
# example already registered, re-registers its own around them, and reads the
# clock at two points that bracket exactly the right work:
#
#   update  — first thing the frame loop runs, so the clock starts before any
#             of the example's per-frame code
#   render  — `Window#render_objects` runs the `render` block *after* every
#             object's `_render_scene` (at the default `z: :foreground`), so
#             the clock stops after the scene has been dispatched
#
# The example is not edited, and needs to know nothing about being measured.

require 'fileutils'
require_relative 'spinel_env'

ROOT = File.expand_path('../..', __dir__)
EXAMPLES = File.join(ROOT, 'spinel/examples')
DIR = File.join(ROOT, 'spinel/scratch/fps')

NAME = (ARGV[0] || 'balls').sub(/\.rb\z/, '')
MEASURE_FRAMES = (ARGV[1] || '600').to_i
WARMUP_FRAMES = 120
REPEATS = 3

APP = File.join(EXAMPLES, "#{NAME}.rb")
unless File.exist?(APP)
  available = Dir.children(EXAMPLES).grep(/\.rb\z/).map { |f| File.basename(f, '.rb') }.sort
  abort "\n  no example #{NAME.inspect} — available: #{available.join(', ')}\n\n"
end

# `--spinel` needs the compiler; the other two do not. Resolved up front so the
# run fails before building anything rather than halfway through the table, and
# exported so the `ruby2d` subprocess finds the same one.
SPINEL = resolve_spinel
ENV['RUBY2D_SPINEL'] = SPINEL

ENGINES = [
  ['CRuby',  nil],
  ['mruby',  '--native'],
  ['Spinel', '--spinel']
].freeze

# Spliced in ahead of `show`. Locals only, and no reopened classes: this has to
# compile on the AOT target too, where the whole program is one compilation unit
# and a redefined method is not a patch but a conflict.
#
# A proc is only fetched and called back if the example registered one. When it
# did not, `Window#initialize`'s own `proc {}` is sitting in that ivar, and
# calling *that* through `instance_variable_get` **crashes the Spinel build**
# with a SIGBUS about a dozen frames later — the same block written literally in
# the example is fine, and so is a user-registered proc fetched the same way, so
# it is specific to the default one. Not reduced; see README.md.
def harness(wraps_update:, wraps_render:)
  <<~RUBY
    # --- spinel/tools/fps.rb: measurement harness, spliced in ---
    __w = Ruby2D::DSL.window
    #{wraps_update ? '__user_update = __w.instance_variable_get(:@update_proc)' : ''}
    #{wraps_render ? '__user_render = __w.instance_variable_get(:@render_proc)' : ''}
    __n = 0
    __t0 = 0.0
    __work = 0.0

    update do |dt|
      __n += 1
      __t0 = __w.elapsed
      #{wraps_update ? '__user_update.call(dt)' : ''}
    end

    render do
      #{wraps_render ? '__user_render.call' : ''}
      __work += __w.elapsed - __t0 if __n > FPS_WARMUP && __n <= FPS_WARMUP + FPS_MEASURE
      __w.close if __n >= FPS_WARMUP + FPS_MEASURE
    end
  RUBY
end

REPORT = <<~'RUBY'

  __per_frame = __work / FPS_MEASURE
  puts "RESULT frames=#{FPS_MEASURE} work=#{__work} per_frame=#{__per_frame} wall_fps=#{__w.fps} objects=#{__w.instance_variable_get(:@objects).size}"
RUBY

# The example, with the frame counts defined ahead of it and the harness spliced
# in around its own procs. `show` is the seam every Ruby 2D script has.
#
# Whether the example registers each block is read off its source: a top-level
# `update`/`render` at column zero. That is what decides whether the harness
# calls back into it, so an example that has neither still measures — it just
# measures a scene that only draws.
def instrument(source)
  header = "FPS_WARMUP = #{WARMUP_FRAMES}\nFPS_MEASURE = #{MEASURE_FRAMES}\n"
  out = source.sub(/^require 'ruby2d'$/, "require 'ruby2d'\n\n#{header}")
  raise "#{NAME}.rb: no `require 'ruby2d'` to anchor to" if out == source

  h = harness(wraps_update: source.match?(/^update\b/), wraps_render: source.match?(/^render\b/))
  spliced = out.sub(/^show$/, "#{h}\nshow\n#{REPORT}")
  raise "#{NAME}.rb: no top-level `show` to splice at" if spliced == out

  spliced
end

def parse(out)
  line = out.lines.find { |l| l.start_with?('RESULT ') }
  abort "\n  no RESULT line:\n#{out}" unless line

  line.split.drop(1).to_h { |pair| pair.split('=', 2) }
end

# One run of one engine. CRuby runs the script directly; the other two compile
# it first and run the binary.
def measure(flag, dir)
  if flag
    out, status, code = Dir.chdir(dir) { run_capped(['ruby2d', 'build', flag, 'app.rb'], seconds: 900) }
    abort "\n  build failed:\n#{out}" unless status == :ok && code&.zero?
    cmd = [File.join(dir, 'build/native/app')]
  else
    cmd = ['ruby', File.join(dir, 'app.rb')]
  end

  out, status, code = Dir.chdir(dir) { run_capped(cmd, seconds: 600) }
  abort "\n  run hung" if status == :timeout
  abort "\n  run failed (exit #{code}):\n#{out}" unless code&.zero?

  parse(out)
end

FileUtils.rm_rf(DIR)
FileUtils.mkdir_p(DIR)
File.write(File.join(DIR, 'app.rb'), instrument(File.read(APP)))

puts "\nspinel: #{SPINEL}"
puts "  #{NAME}.rb — #{WARMUP_FRAMES} warmup, #{MEASURE_FRAMES} measured, #{REPEATS} runs each, fastest reported\n\n"

results = ENGINES.map do |name, flag|
  print "  #{name}… "
  runs = Array.new(REPEATS) { measure(flag, DIR) }
  best = runs.min_by { |r| r['per_frame'].to_f }
  FileUtils.rm_rf(File.join(DIR, 'build'))
  puts format('%.0f µs/frame', best['per_frame'].to_f * 1e6)
  [name, best]
end

# Object counts come from the run rather than the source, since an example may
# build its scene over time. They are only comparable if the engines agree.
counts = results.map { |(_, r)| r['objects'].to_i }
objects = counts.uniq.size == 1 ? counts.first : nil
slowest = results.map { |(_, r)| r['per_frame'].to_f }.max

puts "\n  #{NAME}: update and scene dispatch per frame"
puts(objects ? "  #{objects} objects at the end of the run\n\n"
             : "  objects at the end of the run differ (#{counts.join(', ')}) — per-object omitted\n\n")

header = objects ? format('  %-8s %14s %14s %10s', 'engine', 'µs/frame', 'µs/object', 'relative')
                 : format('  %-8s %14s %10s', 'engine', 'µs/frame', 'relative')
puts header
results.sort_by { |(_, r)| r['per_frame'].to_f }.each do |name, r|
  per_frame = r['per_frame'].to_f
  puts(if objects
         format('  %-8s %13.0f %14.2f %9.2fx', name, per_frame * 1e6,
                per_frame * 1e6 / objects, slowest / per_frame)
       else
         format('  %-8s %13.0f %9.2fx', name, per_frame * 1e6, slowest / per_frame)
       end)
end

# Reported to make the point that it is not the comparison, rather than to hide
# it: all three sit at the refresh rate whatever the cap says.
puts "\n  wall clock, all present-bound:"
results.each { |name, r| puts format('  %-8s %13.1f fps', name, r['wall_fps'].to_f) }
puts
