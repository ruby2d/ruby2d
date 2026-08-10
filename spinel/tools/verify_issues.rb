# Re-verify every filed reproducer against the Spinel binary on $SPINEL.
#
#   export SPINEL=/path/to/spinel/bin/spinel
#   ruby spinel/tools/verify_issues.rb
#
# Each file in ../issues/ carries its own expectations: the code under
# "## Reproduction", the correct output under "**Ruby 4.0.6:**", and the buggy
# output under "**Spinel (...):**". This runs both and compares.
#
# The column that matters is `spinel`:
#
#   reproduces  — still buggy, matches the recorded Spinel output
#   FIXED       — now matches Ruby; close the issue and drop its workaround
#   CHANGED     — matches neither; re-read it by hand before trusting anything
#
# A `cruby` column that is not `ok` means the reproducer itself has rotted —
# fix that first, since a case CRuby rejects is one no maintainer can act on.
#
# Do not run this while a `git bisect` is in flight in the Spinel checkout:
# `bin/spinel` is then whatever commit is checked out, not HEAD.

require 'open3'

ISSUES = File.expand_path('../issues', __dir__)

# Same order as `find_spinel` in lib/ruby2d/cli/spinel.rb, plus a checkout
# beside this repo — so no recipe in ../README.md needs a machine-specific path.
def resolve_spinel
  [ENV['SPINEL'], ENV['RUBY2D_SPINEL'],
   File.expand_path('../../../spinel/bin/spinel', __dir__)].each do |c|
    return c if c && !c.empty? && File.executable?(c)
  end
  path = ENV['PATH'].to_s.split(File::PATH_SEPARATOR)
                    .map { |d| File.join(d, 'spinel') }.find { |f| File.executable?(f) }
  path or abort <<~MSG
    No spinel binary found. Build one and either put it on PATH, clone it
    beside this repo as ../spinel, or point SPINEL at it:

      git clone https://github.com/matz/spinel.git ../spinel
      (cd ../spinel && make deps && make)

    See "Setup" in spinel/README.md.
  MSG
end

SPINEL = resolve_spinel
SCRATCH = File.expand_path('../scratch/verify', __dir__)
TIMEOUT = 10

# A reproducer that hangs has no output to compare, so the expected block says
# so in prose instead.
HANG = '(hangs'

# `heading` is a pattern, not a literal: the expectation headings carry a commit
# ("**Spinel (1aa42ab3):**") that changes as issues are re-verified. An earlier
# literal match silently found nothing here, which read as "FIXED" for every
# issue whose output happened to differ — compare against nothing and everything
# looks resolved.
def section(md, heading)
  md[/#{heading}[^\n]*\n+```(?:ruby)?\n(.*?)```/m, 1]
end

# Run with a hard cap: two of these bugs are infinite loops, and a verifier that
# hangs on them is no better than the bug.
def run(cmd)
  out = nil
  pid = nil
  Open3.popen2e(*cmd) do |_in, o, t|
    pid = t.pid
    killer = Thread.new { sleep TIMEOUT; Process.kill('KILL', pid) rescue nil }
    out = o.read
    t.value
    killer.kill
  end
  out
rescue StandardError => e
  "ERROR: #{e.message}"
end

def timed_out?(actual) = actual.to_s.strip.empty?

require 'fileutils'
FileUtils.mkdir_p(SCRATCH)

rows = Dir[File.join(ISSUES, '*.md')].sort.map do |path|
  md = File.read(path)
  name = File.basename(path, '.md')
  code = section(md, '## Reproduction')
  next [name, 'no-repro', '-'] unless code

  want_ruby = section(md, '\*\*Ruby').to_s.strip
  want_spinel = section(md, '\*\*Spinel').to_s.strip
  abort "#{name}: could not parse both expectation blocks" if want_ruby.empty? || want_spinel.empty?

  rb = File.join(SCRATCH, "#{name}.rb")
  File.write(rb, code)

  got_ruby = run(['ruby', rb]).to_s.strip
  cruby = got_ruby == want_ruby ? 'ok' : 'MISMATCH'

  bin = File.join(SCRATCH, name)
  compiled = system(SPINEL, rb, '-o', bin, out: File::NULL, err: File::NULL)
  spinel =
    if !compiled
      want_spinel.include?('error') || want_spinel.include?('rejected') ? 'reproduces' : 'compile-FAIL'
    else
      got = run([bin]).to_s.strip
      if want_spinel.include?(HANG)
        timed_out?(got) ? 'reproduces' : 'FIXED'
      elsif got == want_spinel then 'reproduces'
      elsif got == want_ruby then 'FIXED'
      else 'CHANGED'
      end
    end

  [name, cruby, spinel]
end.compact

w = rows.map { |r| r[0].size }.max
puts format("%-#{w}s  %-8s  %s", 'issue', 'cruby', 'spinel')
rows.each { |r| puts format("%-#{w}s  %-8s  %s", *r) }

stale = rows.count { |r| r[2] == 'FIXED' }
puts "\n#{stale} of #{rows.size} now behave correctly." if stale.positive?
