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

# `find_spinel` in cli/spinel.rb honors this first, so the checks that shell out
# to `ruby2d build --spinel` use the same compiler the rest measured against
# rather than whatever a `ruby2d setup --spinel` left in the cache.
ENV['RUBY2D_SPINEL'] = SPINEL

def sh!(*cmd)
  out, status, code = run_capped(cmd, seconds: 600)
  [out, status == :ok && code&.zero?]
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

  control, ok = sh!('ruby', "#{SCRATCH}/subset.rb")
  return ['subset', :fail, "CRuby control failed — the harness is broken, not the compiler:\n#{control}"] unless ok

  _, errors, built = compile("#{SCRATCH}/subset.rb", "#{SCRATCH}/subset.bin")
  return ['subset', :fail, "#{errors} C errors, no binary"] unless built

  out, status = run_capped(["./#{SCRATCH}/subset.bin"])
  return ['subset', :fail, 'hung — #3782 has regressed again'] if status == :timeout

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

# The CLI: does `ruby2d build --spinel` take an ordinary app and produce a
# binary that draws? This is the only check that goes through the installed gem
# rather than the working tree — so run `rake` first, or it tests the last
# install and not the current edit.
def check_cli
  dir = "#{SCRATCH}/cli"
  FileUtils.rm_rf(dir)
  FileUtils.mkdir_p(dir)
  FileUtils.cp('spinel/tools/cli_app.rb', "#{dir}/app.rb")
  shot = File.expand_path("#{dir}/app.png")

  out, ok = Dir.chdir(dir) { sh!('ruby2d', 'build', '--spinel', 'app.rb') }
  return ['cli', :fail, "build failed:\n#{out}"] unless ok

  binary = "#{dir}/build/native/app"
  return ['cli', :fail, "no executable at #{binary}"] unless File.exist?(binary)

  ENV['FRAMES'] = '30'
  ENV['SHOT'] = shot
  run, status = run_capped([File.expand_path(binary)], seconds: 60, chdir: File.dirname(binary))
  return ['cli', :fail, 'hung'] if status == :timeout
  return ['cli', :fail, "no screenshot written:\n#{run}"] unless File.exist?(shot)

  colors = png_distinct_colors(shot)
  return ['cli', :skip, 'built and ran, but the screenshot could not be decoded'] if colors.nil?
  return ['cli', :fail, "rendered a blank window (#{colors} distinct color)"] if colors < 2

  # Background, fill, stroke. Counting "more than one color" is what let a
  # stroke that drew nothing pass here for weeks, so the fixture's exact three
  # are named: two means the stroke is inert again.
  return ['cli', :fail, "the stroke drew nothing (#{colors} colors, expected 3)"] if colors < 3

  frames = run[/ran (\d+) frames/, 1]
  # A frame count that stayed at 0 means the `update` block ran without its
  # captured local — #3783 silently back, which nothing else here would catch.
  return ['cli', :fail, "update block lost its captured local (ran #{frames.inspect} frames)"] unless frames.to_i > 1

  ['cli', :pass, "built an app that drew #{colors} colors over #{frames} frames"]
end

# Input: does a keypress, a mouse move, a click, a wheel tick and a quit reach
# the app's handlers — window-level, filtered, and per-object — on this target?
# The fixture injects them into SDL from inside the binary, so no keyboard or
# mouse is driven; see tools/input_app.rb. Goes through the installed gem like
# `cli`, and compares the handler output line for line against what the same
# events produce on CRuby.
def check_input
  dir = "#{SCRATCH}/input_check"
  FileUtils.rm_rf(dir)
  FileUtils.mkdir_p(dir)
  include_dir = File.expand_path('assets/platform/include')
  File.write("#{dir}/app.rb", File.read('spinel/tools/input_app.rb').gsub('__INCLUDE__', include_dir))

  out, ok = Dir.chdir(dir) { sh!('ruby2d', 'build', '--spinel', 'app.rb') }
  return ['input', :fail, "build failed:\n#{out}"] unless ok

  binary = "#{dir}/build/native/app"
  return ['input', :fail, "no executable at #{binary}"] unless File.exist?(binary)

  run, status = run_capped([File.expand_path(binary)], seconds: 60, chdir: File.dirname(binary))
  return ['input', :fail, 'hung'] if status == :timeout

  expected = <<~'LINES'.lines.map(&:chomp)
    key_down :space
    key_up :space
    key_down :r
    filter key_down: :r
    key_up :r
    mouse_move 100 50 3.0,-2.0
    mouse_down :left 100 50
    filter mouse_down: :left 100,50
    mouse_up :left
    mouse_scroll :normal 0.0,-1.0
    mouse_move 160 120 60.0,70.0
    object hover 160,120
    mouse_down :left 160 120
    filter mouse_down: :left 160,120
    object mouse_down :left
    mouse_up :left
    object click :left
    object filter click: :left
    mouse_move 10 10 -150.0,-110.0
    object hover_out
    close
  LINES
  actual = run.lines.map(&:chomp).reject(&:empty?)
  return ['input', :fail, "the quit event never closed the window:\n#{run}"] if actual.any? { |l| l.start_with?('TIMEOUT') }

  missing = expected - actual
  extra   = actual - expected
  unless missing.empty? && extra.empty? && actual == expected
    detail = +"handler output differs from CRuby's\n"
    detail << "  missing: #{missing.join(' | ')}\n" unless missing.empty?
    detail << "  extra:   #{extra.join(' | ')}\n" unless extra.empty?
    detail << "  order:   #{actual.join(' | ')}" if missing.empty? && extra.empty?
    return ['input', :fail, detail]
  end

  ['input', :pass, "#{actual.size} events reached their handlers in order, window and object alike"]
end

# The preflight: does an app using unsupported features stop with a message
# naming them, rather than a wall of generated-C errors?
def check_preflight
  dir = "#{SCRATCH}/cli"
  FileUtils.mkdir_p(dir)
  # Two classes the target does not draw yet. When one of them lands, swap it
  # for another from `SPINEL_EXCLUDED_CLASSES` — a fixture using only supported
  # features reads as "accepted an app it can't build" below.
  File.write("#{dir}/unsupported.rb", <<~'RUBY')
    require 'ruby2d'
    Image.new('missing.png')
    Sprite.new('missing.png', width: 10, height: 10)
  RUBY

  out, ok = Dir.chdir(dir) { sh!('ruby2d', 'build', '--spinel', 'unsupported.rb') }
  return ['preflight', :fail, "accepted an app it can't build"] if ok

  missing = %w[Image Sprite].reject { |name| out.include?(name) }
  return ['preflight', :fail, "didn't name #{missing.join(' or ')}:\n#{out}"] unless missing.empty?

  ['preflight', :pass, 'rejected unsupported features by name']
end

# The filed reproducers: has upstream fixed any of them?
def check_issues
  out, = sh!('ruby', 'spinel/tools/verify_issues.rb')
  fixed = out.scan(/\bFIXED\b/).size
  repro = out.scan(/\breproduces\b/).size
  # Every other verdict needs a human. Counting only fixed and reproduces let
  # two drafts vanish from this line entirely while the verifier was reporting
  # them — a summary that omits rows is worse than one that flags them.
  unclear = out.scan(/\bCHANGED\b/).size + out.scan(/compile-FAIL/).size +
            out.scan(/\bno-repro\b/).size
  # Drafts the verifier cannot judge are deliberate, so they are reported but
  # not flagged: a warning that is always on is one nobody reads.
  parked = out.scan(/\bdraft\b/).size + out.scan(/\bspinel-only\b/).size
  detail = "#{fixed} fixed, #{repro} reproduce"
  detail += ", #{parked} parked" if parked.positive?
  detail += ", #{unclear} to read by hand" if unclear.positive?
  ['issues', unclear.zero? ? :pass : :warn, detail]
end

CHECKS = { 'subset' => method(:check_subset),
           'demo' => method(:check_demo),
           'cli' => method(:check_cli),
           'input' => method(:check_input),
           'preflight' => method(:check_preflight),
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
results.each { |name, status, detail| puts format('  %-10s %-8s %s', name, status, detail) }
puts

exit(results.any? { |r| r[1] == :fail } ? 1 : 0)
