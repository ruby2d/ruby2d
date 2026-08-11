# Pull the Spinel checkout and rebuild it, reporting what arrived.
#
#   cd spinel && rake upstream      # this, then `issues`, then `sweep`
#
# Spinel ships many commits a day and both of the last two pulls changed our
# position — one fixed a bug before its report could be filed, another turned an
# adjacent commit into supporting evidence for one. Checking by hand is five
# steps and was twice run against a stale transform list.
#
# Refuses to touch a dirty checkout: the branch's patch for issue 11 lives there
# as an applied diff or a stash, and pulling over local edits would lose them.

require_relative 'spinel_env'

SPINEL = resolve_spinel
CHECKOUT = File.expand_path('..', File.dirname(SPINEL))

def git(*args, dir: CHECKOUT)
  IO.popen(['git', '-C', dir, *args], err: [:child, :out], &:read).to_s.strip
end

unless Dir.exist?(File.join(CHECKOUT, '.git'))
  abort "  #{SPINEL} is not inside a git checkout; nothing to pull.\n\n"
end

dirty = git('status', '--porcelain')
unless dirty.empty?
  puts "\n  The Spinel checkout has local changes:\n\n"
  dirty.lines.first(10).each { |l| puts "    #{l.rstrip}" }
  abort "\n  Refusing to pull over them. Stash or commit in #{CHECKOUT} first.\n\n"
end

before = git('rev-parse', '--short=8', 'HEAD')
puts "  #{CHECKOUT}"
puts "  at #{before}, pulling…\n\n"

out = git('pull', '--ff-only')
after = git('rev-parse', '--short=8', 'HEAD')

if before == after
  puts "  Already up to date at #{before}.\n\n"
  exit 0
end

log = git('log', '--oneline', "#{before}..#{after}")
puts "  #{before} -> #{after}, #{log.lines.size} new commit(s):\n\n"
log.lines.first(30).each { |l| puts "    #{l.rstrip}" }
puts "    …" if log.lines.size > 30

puts "\n  Rebuilding…\n\n"
ok = system('make', '-j8', chdir: CHECKOUT, out: File::NULL, err: File::NULL)
abort "  Build failed. Run `make` in #{CHECKOUT} to see why.\n\n" unless ok

puts "  Built #{after}. Now `rake issues` for the reproducers and `rake sweep`"
puts "  for the workarounds — they answer different questions and have disagreed.\n\n"
puts "  (#{out.lines.last&.strip})" unless out.empty?
