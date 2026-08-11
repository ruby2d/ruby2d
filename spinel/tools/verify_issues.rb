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

require_relative 'spinel_env'

ISSUES = File.expand_path('../issues', __dir__)

SPINEL = resolve_spinel
SCRATCH = File.expand_path('../scratch/verify', __dir__)
TIMEOUT = 10

# A reproducer that hangs has no output to compare, so the expected block says
# so in prose instead.
HANG = '(hangs'

# A reproducer that crashes is the same problem one step further: the shell
# prints "segmentation fault" but the binary never wrote it, so the captured
# stream holds only whatever came before the fault. The crash is read from the
# exit status instead. SIGKILL is deliberately not in this list — that one is
# the timeout killer below, not the bug.
CRASH = 'segmentation fault'
FATAL_SIGNALS = %w[SEGV BUS ABRT ILL FPE].filter_map { |s| Signal.list[s] }.freeze

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
  status = nil
  pid = nil
  Open3.popen2e(*cmd) do |_in, o, t|
    pid = t.pid
    killer = Thread.new { sleep TIMEOUT; Process.kill('KILL', pid) rescue nil }
    out = o.read
    status = t.value
    killer.kill
  end
  [out, status]
rescue StandardError => e
  ["ERROR: #{e.message}", nil]
end

def timed_out?(actual) = actual.to_s.strip.empty?

def crashed?(status) = FATAL_SIGNALS.include?(status&.termsig)

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

  got_ruby, = run(['ruby', rb])
  got_ruby = got_ruby.to_s.strip
  cruby = got_ruby == want_ruby ? 'ok' : 'MISMATCH'

  bin = File.join(SCRATCH, name)
  compiled = system(SPINEL, rb, '-o', bin, out: File::NULL, err: File::NULL)
  spinel =
    if !compiled
      # Does the draft document a refusal? Spinel's own diagnostics start with
      # `spinel:` and clang's carry `error:` — matching those is what tells a
      # reproduced compile error apart from a draft that has gone stale.
      #
      # Sniffing for the word "error" is not enough: `unsupported call:` and
      # `(NameError)` contain neither it nor "rejected", so two drafts whose
      # expectations matched exactly still reported `compile-FAIL`.
      documented = want_spinel.match?(/^spinel:/) || want_spinel.include?('error:') ||
                   want_spinel.include?('rejected')
      documented ? 'reproduces' : 'compile-FAIL'
    else
      got, status = run([bin])
      got = got.to_s.strip
      if want_spinel.include?(HANG)
        timed_out?(got) ? 'reproduces' : 'FIXED'
      elsif want_spinel.include?(CRASH)
        crashed?(status) ? 'reproduces' : 'FIXED'
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
