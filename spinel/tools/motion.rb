# Does a built example actually animate, or is it drawing a frozen scene?
#
#   cd spinel && rake motion              # every example, both engines
#   ruby spinel/tools/motion.rb nbody     # one, both engines
#
# The other checks ask whether the target compiles, runs and draws. All three
# pass for a program whose motion is silently gone: `examples/fireworks.rb` and
# `examples/bouncing_balls.rb` built, ran at full frame rate, and drew a correct
# opening frame while nothing on screen ever moved, because the update block's
# `dt` argument arrived as Integer 0 (issues/33). Nothing that asks "did it
# draw?" can see that — only "did it change?" can.
#
# It works by injecting a frame counter and two screenshots into the example's
# own `update` block, so the example itself is unmodified on disk and the
# comparison is between frame 5 and frame 60 of the same program. mruby is run
# the same way as the control: an example that legitimately holds still would
# report frozen on both, and only a difference between the engines is a finding.

require 'fileutils'
require_relative 'spinel_env'

ROOT = File.expand_path('../..', __dir__)
Dir.chdir(ROOT)
SCRATCH = 'spinel/scratch/motion'
ENV['RUBY2D_SPINEL'] = resolve_spinel

# `spinel_unsupported_uses` is the preflight's own scan, read here so the list
# of examples this checks can't drift from the list the CLI accepts.
# `cli/spinel.rb` expects the surrounding build path; stub what it reaches for.
def error(msg) = warn(msg)
def find_executable(_name) = nil
def cache_platform_dir = '/nonexistent'
def cache_stamp_ok?(_dir) = false
load File.join(ROOT, 'lib/ruby2d/cli/spinel.rb')

# Frame 5 rather than frame 1: the first frames of a scene that spawns its
# objects in `update` are legitimately different from each other, and 5 is past
# that on every example here.
EARLY = 5
LATE = 60

ENGINES = { 'mruby' => '--native', 'spinel' => '--spinel' }.freeze

# The examples this target can build at all. Anything the preflight rejects
# stops before compiling, so listing them here keeps the report about motion
# rather than about coverage.
def buildable
  Dir.glob("#{ROOT}/examples/*.rb").sort.select do |path|
    spinel_unsupported_uses(File.read(path)).empty?
  end
end

def probe(source, early, late)
  inject = <<~RUBY.chomp
    \\0
      $__motion_n = ($__motion_n || 0) + 1
      Ruby2D::DSL.window.screenshot(#{early.inspect}) if $__motion_n == #{EARLY}
      Ruby2D::DSL.window.screenshot(#{late.inspect}) if $__motion_n == #{LATE}
      close if $__motion_n > #{LATE}
  RUBY

  patched = source.sub(/^update do(?: \|[^|]*\|)?$/, inject)
  raise 'no top-level `update do` to inject into' if patched == source

  patched
end

def moves?(name, engine, flag)
  dir = File.expand_path("#{SCRATCH}/#{name}-#{engine}")
  FileUtils.rm_rf(dir)
  FileUtils.mkdir_p(dir)
  early = File.join(dir, 'early.png')
  late = File.join(dir, 'late.png')

  File.write("#{dir}/app.rb", probe(File.read("#{ROOT}/examples/#{name}.rb"), early, late))

  out, status, code = Dir.chdir(dir) { run_capped(['ruby2d', 'build', flag, 'app.rb'], seconds: 900) }
  return [nil, "build failed:\n#{out}"] unless status == :ok && code&.zero?

  ran, status = run_capped([File.expand_path(File.join(dir, 'build/native/app'))], seconds: 120,
                           chdir: File.join(dir, 'build/native'))
  return [nil, 'hung'] if status == :timeout
  return [nil, "wrote no screenshot:\n#{ran}"] unless File.exist?(early) && File.exist?(late)

  [File.binread(early) != File.binread(late), nil]
end

names = ARGV.empty? ? buildable.map { |p| File.basename(p, '.rb') } : ARGV
abort "  Nothing to check: no example builds on this target yet.\n\n" if names.empty?

frozen = []
errored = []

names.each do |name|
  results = ENGINES.map do |engine, flag|
    moved, err = moves?(name, engine, flag)
    print format("  %-18s %-8s ", name, engine)
    puts err ? "error — #{err.lines.first.to_s.strip}" : (moved ? 'animates' : 'FROZEN')
    errored << "#{name} (#{engine}): #{err.lines.first.to_s.strip}" if err
    [engine, moved]
  end.to_h

  # Only a disagreement is a finding: an example that holds still on both is
  # holding still because that is what it does.
  frozen << name if results['mruby'] && results['spinel'] == false
end

puts

# An example that failed to build reports `moved` as nil, and `nil == false` is
# false — so before 2026-08-13 a run where every Spinel build failed printed
# "Every example animates on both engines" and exited 0. An error is a failure
# to answer the question, never an answer of "fine".
unless errored.empty?
  puts "  Could not answer for #{errored.size} of #{names.size * ENGINES.size} runs:"
  errored.each { |e| puts "    #{e}" }
  puts "\n  This is not a pass. Fix the build, then re-run.\n\n"
  exit 1
end

if frozen.empty?
  puts "  Every example animates on both engines.\n\n"
else
  puts "  FROZEN on Spinel, animating on mruby: #{frozen.join(', ')}"
  puts "  A scene that draws correctly and never changes is a dropped write or\n" \
       "  a zeroed `dt` — see issues/33 and issues/29.\n\n"
  exit 1
end
