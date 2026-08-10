# Rewrite the one `next`-inside-Hash#each site in the assembled subset to the
# equivalent `if` form, stepping around the hang in issue 08.
#
#   ruby spinel/tools/build_subset.rb
#   ruby spinel/tools/patch_next.rb
#
# Semantics-identical, and deliberately not a lib/ change: issue 08 is an
# upstream regression, so this goes away when it is fixed. Delete this file and
# its mention in ../README.md once verify_issues.rb reports 08 as FIXED.
#
# Note: plain heredocs, not `<<~` — squiggly strips the leading indentation that
# has to match the file exactly.

path = 'spinel/scratch/subset.rb'
src = File.read(path)

from = <<'RB'
      dims.each do |name, value|
        next unless value.is_a?(Numeric) && value.negative?
        raise ArgumentError, "#{self.class} #{name} must be zero or positive, got #{value}"
      end
RB

to = <<'RB'
      dims.each do |name, value|
        if value.is_a?(Numeric) && value.negative?
          raise ArgumentError, "#{self.class} #{name} must be zero or positive, got #{value}"
        end
      end
RB

abort "site not found — lib/ drifted" unless src.include?(from)
File.write(path, src.sub(from, to))
puts "patched #{path}"
