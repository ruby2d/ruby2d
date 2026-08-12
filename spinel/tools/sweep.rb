# Drop each compatibility transform in turn, rebuild the library, and report
# whether it is still needed.
#
#   cd spinel && rake sweep
#
# **This is the check that matters most after an upstream pull**, and it is not
# the same as `rake issues`. That one re-runs each filed reproducer, which
# answers "did the small case get fixed". This one answers "can we delete the
# workaround", and the two have disagreed in both directions:
#
#   - #3783 was closed and its reproducer passed while the library still failed;
#     the sweep caught it and kept the workaround
#   - a nested-`include` bug was fixed in a probe while the real library still
#     failed, for weeks
#   - #3787 and #3788 were both fixed upstream and both reproducers pass, and
#     `dsl_shims` and `window_guards` are both still needed
#
# A transform is droppable only when the library compiles to zero errors AND
# runs to the same output as CRuby. Both halves matter: dropping
# `disable_class_pattern` compiles clean and then fails at run time, and
# `positional_callbacks` — since deleted — compiled, ran, printed `SUBSET OK`,
# and had one earlier line wrong.

require 'fileutils'
require_relative 'spinel_env'

ROOT = File.expand_path('../..', __dir__)
Dir.chdir(ROOT)
SPINEL = resolve_spinel
OUT = 'spinel/scratch/subset.rb'
BIN = 'spinel/scratch/sweep.bin'

TRANSFORMS = spinel_transform_names(File.join(ROOT, 'lib/ruby2d/cli/spinel.rb')).freeze

def build(skip)
  env = skip ? { 'SPINEL_SKIP' => skip } : {}
  out = IO.popen(env, ['ruby', 'spinel/tools/build_subset.rb'], err: [:child, :out], &:read)
  return nil if $?.success?

  # The message, not a backtrace line: a transform that no longer matches raises
  # SpinelCompatDrift naming which one, and that names the dependency.
  reason = out.lines.find { |l| l.include?('Spinel compat') } || out.lines.first
  reason.to_s.strip.sub(/\A.*?: /, '').sub(' See spinel/README.md.', '').sub(/ \(\w+\)\z/, '')
end

# The control: every transform in place, run under CRuby. Anything the compiler
# produces is only attributable against this.
abort "generator failed with all transforms: #{build(nil)}" if build(nil)
control, status, code = run_capped(['ruby', OUT], seconds: 60)
abort 'CRuby control failed — the harness is broken, not the compiler' unless status == :ok && code&.zero?

puts "spinel:  #{SPINEL}"
puts "control: #{control.lines.last.strip}"
puts "\n  #{TRANSFORMS.size} transforms, read from cli/spinel.rb\n\n"

results = TRANSFORMS.map do |name|
  # A transform whose site another one creates cannot be tested alone. No pair
  # is coupled that way today — `positional_callbacks` rewrote the shims
  # `dsl_shims` generates, and it is gone — but the next one added might be.
  if (err = build(name))
    next [name, 'inconclusive', "another transform depends on it — #{err[0, 70]}"]
  end

  cruby, status, code = run_capped(['ruby', OUT], seconds: 60)
  next [name, 'inconclusive', 'CRuby rejects the result'] unless status == :ok && code&.zero?
  next [name, 'still needed', 'CRuby output changed — the transform is not semantics-preserving'] if cruby != control

  FileUtils.rm_f(BIN)
  out, = run_capped([SPINEL, OUT, '-o', BIN, '--cc=cc -ferror-limit=0'], seconds: 900)
  unless File.exist?(BIN)
    errors = out.scan(/error:/).size
    detail = errors.positive? ? "#{errors} C errors" : (out[/unsupported[^\n]*/]&.slice(0, 60) || 'refused')
    next [name, 'still needed', detail]
  end

  ran, status = run_capped(["./#{BIN}"], seconds: 60)
  next [name, 'still needed', 'hangs'] if status == :timeout
  next [name, 'still needed', "diverged: #{ran.lines.grep_v(/OK/).last&.strip.inspect}"] if ran != control

  [name, 'DROPPABLE', 'compiles clean and matches CRuby']
end

build(nil) # leave the scratch subset in its normal state

width = TRANSFORMS.map(&:size).max
results.each { |name, verdict, detail| puts format("  %-#{width}s  %-13s %s", name, verdict, detail) }

droppable = results.select { |r| r[1] == 'DROPPABLE' }.map(&:first)
puts "\n  #{droppable.empty? ? 'Nothing droppable.' : "Droppable: #{droppable.join(', ')}"}"
puts "  Delete a droppable transform from cli/spinel.rb, then re-run `rake` to confirm.\n\n"
