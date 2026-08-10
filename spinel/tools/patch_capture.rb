# Pass the user's block positionally instead of forwarding it with `&proc`,
# stepping around issue 09. Verified on the real library, not just a probe: with
# this applied the subset prints `ticks: 5`, matching CRuby exactly.
#
# Not landed as a `cli/spinel.rb` transform. Issue 09 is an upstream bug and the
# real fix costs a positional parameter on every block-taking Window method, so
# this stays a probe until it is clear upstream will not fix it.
#
#   ruby spinel/tools/build_subset.rb
#   ruby spinel/tools/patch_next.rb
#   ruby spinel/tools/patch_capture.rb
#
# Two edits, mirroring what a `cli/spinel.rb` transform would do:
#   - `Window#update` gains a positional proc parameter (keeping the block form,
#     so nothing else that calls it has to change)
#   - the generated top-level DSL shim passes the proc positionally
#
# Plain heredocs, not `<<~`: the indentation has to match the file exactly.

path = ARGV[0] || 'spinel/scratch/subset.rb'
src = File.read(path)

edits = [
  [<<'FROM', <<'TO', 'Window#update accepts a positional proc'],
    def update(&proc)
      raise Error, '`update` requires a block' unless proc
FROM
    def update(positional = nil, &blk)
      proc = positional || blk
      raise Error, '`update` requires a block' unless proc
TO
  [<<'FROM', <<'TO', 'top-level update shim passes positionally'],
def update(&proc)
  Ruby2D::DSL.window.update(&proc)
end
FROM
def update(&proc)
  Ruby2D::DSL.window.update(proc)
end
TO
]

edits.each do |from, to, what|
  abort "site not found: #{what}" unless src.include?(from)
  src = src.sub(from, to)
end

File.write(path, src)
puts "patched #{path}: #{edits.size} sites"
