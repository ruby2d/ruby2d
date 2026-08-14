# How far is this target from running everything in examples/ and test/?
#
#   cd spinel && rake coverage
#
# The goal of this branch is that every program in `examples/` and `test/`
# builds, runs, and behaves the way it does on mruby. That is four gates, and a
# program can pass three of them and still be broken:
#
#   1. the preflight accepts it     — this tool
#   2. it builds                    — `rake cli`, and a real `ruby2d build`
#   3. it draws the right pixels    — `rake compare`
#   4. it behaves                   — `rake motion`, and nothing yet for input
#
# **This tool measures gate 1 only**, and gate 1 is the most flattering of the
# four. It is a static scan for features the target does not implement, so a
# program it calls accepted may still fail to compile, draw nothing, or freeze —
# on 2026-08-13 all three of the accepted programs built while two of them
# rendered a correct first frame and then never moved. Read the number as "not
# refused outright", never as "works".
#
# The ranking is the useful half: it turns "add the missing features" into an
# order, by counting how many programs each one unblocks rather than guessing.
# `Text` looks like the obvious first move by raw appearances and is not
# necessarily the cheapest — the greedy list says what each step buys.

require 'set'

ROOT = File.expand_path('../..', __dir__)
Dir.chdir(ROOT)

# The preflight's own scan, read out of the CLI so this can't drift from what
# `ruby2d build --spinel` actually refuses. `cli/spinel.rb` expects the
# surrounding build path; stub what it reaches for. No compiler is needed —
# this is a source scan, so it runs in a second with nothing built.
def error(msg) = warn(msg)
def find_executable(_name) = nil
def cache_platform_dir = '/nonexistent'
def cache_stamp_ok?(_dir) = false
load File.join(ROOT, 'lib/ruby2d/cli/spinel.rb')

# `examples/build/` holds generated copies of the examples, which would be
# counted twice and inflate the total.
PROGRAMS = (Dir.glob('examples/**/*.rb') + Dir.glob('test/**/*.rb'))
           .reject { |p| p.include?('/build/') }.sort.freeze

# path => the set of features that keep it off this target.
needs = PROGRAMS.to_h do |path|
  [path, spinel_unsupported_uses(File.read(path)).map { |_n, name, _why| name }.uniq.to_set]
end

accepted = needs.select { |_p, n| n.empty? }.keys
pct = ->(n) { 100 * n / PROGRAMS.size }

puts "\n  #{PROGRAMS.size} programs in examples/ and test/"
puts "  #{accepted.size} accepted by the preflight (#{pct[accepted.size]}%), " \
     "#{PROGRAMS.size - accepted.size} refused\n\n"
accepted.each { |p| puts "    #{p}" }

puts "\n  Blocking features, by how many programs each appears in:\n\n"
tally = needs.values.flat_map(&:to_a).tally.sort_by { |name, n| [-n, name] }
tally.each { |name, n| puts format('    %-18s %3d', name, n) }

# Greedy rather than by raw count: the question is what to build next, and a
# feature that appears everywhere alongside four others unblocks nothing on its
# own. Each row is the cumulative total once that feature exists.
puts "\n  What to add next, and what each step buys:\n\n"
have = Set.new
runnable = ->(h) { needs.count { |_p, n| (n - h).empty? } }
puts format('    %-20s %3d programs  (%d%%)', 'today', accepted.size, pct[accepted.size])

until (remaining = needs.values.flat_map(&:to_a).uniq - have.to_a).empty?
  best = remaining.max_by { |f| [runnable[have | [f]], -f.length] }
  have << best
  puts format('    + %-18s %3d programs  (%d%%)', best, runnable[have], pct[runnable[have]])
end
puts
