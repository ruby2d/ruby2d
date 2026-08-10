# Run the Spinel checks and report what passed.
#
#   ruby spinel/tools/check.rb [subset|demo|issues|all]     # default: all
#
# Or through rake, which is the normal entry point:
#
#   rake spinel:check   rake spinel:demo   rake spinel:issues
#
# Every step that burned time by hand is encoded here: stale binaries are
# deleted before compiling (a failed compile otherwise leaves the previous one
# in place and the old result reads as success), `-ferror-limit=0` is always
# passed (clang stops at 20 and a real count reads as a plateau), the CRuby
# control always runs (a Spinel difference is only attributable against it), and
# the demo's pixels are checked rather than its exit status.

require 'fileutils'
require_relative 'spinel_env'

ROOT = File.expand_path('../..', __dir__)
Dir.chdir(ROOT)
SPINEL = resolve_spinel
SCRATCH = 'spinel/scratch'

def sh!(*cmd)
  out, status = run_capped(cmd, seconds: 600)
  [out, status == :ok]
end

def compile(src, bin)
  # Delete first: `spinel` leaves the previous binary when it fails, and running
  # a stale one reproduces the last result exactly.
  FileUtils.rm_f(bin)
  out, = sh!(SPINEL, src, '-o', bin, '--cc=cc -ferror-limit=0')
  errors = out.scan(/error:/).size
  [out, errors, File.exist?(bin)]
end

# The lib/ slice: does it compile, and does it behave the way CRuby does?
def check_subset
  sh!('ruby', 'spinel/tools/build_subset.rb')
  sh!('ruby', 'spinel/tools/patch_next.rb',    "#{SCRATCH}/subset.rb")
  sh!('ruby', 'spinel/tools/patch_capture.rb', "#{SCRATCH}/subset.rb")

  control, ok = sh!('ruby', "#{SCRATCH}/subset.rb")
  return ['subset', :fail, "CRuby control failed — the harness is broken, not the compiler:\n#{control}"] unless ok

  _, errors, built = compile("#{SCRATCH}/subset.rb", "#{SCRATCH}/subset.bin")
  return ['subset', :fail, "#{errors} C errors, no binary"] unless built

  out, status = run_capped(["./#{SCRATCH}/subset.bin"])
  return ['subset', :fail, 'hung — issue 08 is back, or patch_next no longer applies'] if status == :timeout

  if out == control
    ['subset', :pass, "matches CRuby (#{control.lines.size} lines)"]
  else
    ['subset', :fail, "diverged from CRuby\n  cruby:  #{control.lines.last&.strip}\n  spinel: #{out.lines.last&.strip}"]
  end
end

# The demo: does a real Ruby 2D script put pixels on screen?
def check_demo
  shot = "#{SCRATCH}/square.png"
  FileUtils.rm_f(shot)
  out, ok = sh!('./spinel/tools/link_square.sh')
  return ['demo', :fail, "build failed:\n#{out}"] unless ok

  ENV['FRAMES'] = '30'
  ENV['SHOT'] = shot
  run, status = run_capped(["./#{SCRATCH}/square.bin"], seconds: 60)
  return ['demo', :fail, 'hung'] if status == :timeout
  return ['demo', :fail, "no screenshot written:\n#{run}"] unless File.exist?(shot)

  colors = png_distinct_colors(shot)
  return ['demo', :skip, 'ran, but the screenshot could not be decoded to check'] if colors.nil?
  # A window that drew nothing is one flat background color, and looks healthy
  # from every other angle — including a per-frame draw count.
  return ['demo', :fail, "rendered a blank window (#{colors} distinct color)"] if colors < 2

  ['demo', :pass, "drew #{colors} distinct colors over #{run[/rendered (\d+) frames/, 1]} frames"]
end

# The filed reproducers: has upstream fixed any of them?
def check_issues
  out, = sh!('ruby', 'spinel/tools/verify_issues.rb')
  fixed = out.scan(/\bFIXED\b/).size
  repro = out.scan(/\breproduces\b/).size
  changed = out.scan(/\bCHANGED\b/).size
  detail = "#{fixed} fixed, #{repro} reproduce"
  detail += ", #{changed} CHANGED — read by hand" if changed.positive?
  [changed.zero? ? 'issues' : 'issues', changed.zero? ? :pass : :warn, detail]
end

CHECKS = { 'subset' => method(:check_subset),
           'demo' => method(:check_demo),
           'issues' => method(:check_issues) }.freeze

which = ARGV[0] || 'all'
selected = which == 'all' ? CHECKS.keys : [which]
unless (selected - CHECKS.keys).empty?
  abort "unknown check #{which.inspect}; known: #{CHECKS.keys.join(', ')}, all"
end

puts "spinel: #{SPINEL}"
results = selected.map do |name|
  print "  #{name}... "
  $stdout.flush
  row = CHECKS[name].call
  puts({ pass: 'ok', fail: 'FAILED', skip: 'skipped', warn: 'note' }[row[1]])
  row
end

puts
results.each { |name, status, detail| puts format('  %-8s %-8s %s', name, status, detail) }
puts

exit(results.any? { |r| r[1] == :fail } ? 1 : 0)
