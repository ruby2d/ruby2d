# Assemble the `lib/` slice into one Spinel-compilable file with every `Ext`
# entry point stubbed, so this exercises `lib/` alone — no C, no FFI.
#
#   ruby spinel/tools/build_subset.rb            # writes spinel/scratch/subset.rb
#   ruby spinel/scratch/subset.rb                # CRuby baseline — should print OK
#   $SPINEL spinel/scratch/subset.rb -o out && ./out
#
# The assembly itself is `spinel_assemble` from `cli/spinel.rb` — the same code
# `ruby2d build --spinel` runs. This file only supplies the main. That matters:
# a check built on a parallel harness proves things about the harness.
#
# To re-check a workaround after an upstream fix, drop it and rebuild:
#
#   SPINEL_SKIP=expand_or_return,dsl_shims ruby spinel/tools/build_subset.rb
#   SPINEL_SKIP=all ruby spinel/tools/build_subset.rb
#
# Names are the `spinel_*` functions in cli/spinel.rb minus the prefix. This is
# the documented way to re-check the workaround table in ../README.md — a probe
# passing standalone does not mean the transform can go.

ROOT = File.expand_path('../..', __dir__)
OUT  = File.join(ROOT, 'spinel', 'scratch', 'subset.rb')

# `cli/spinel.rb` expects the surrounding build path; stub what it reaches for.
def error(msg) = warn(msg)
def find_executable(_name) = nil
def cache_platform_dir = '/nonexistent'
def cache_stamp_ok?(_dir) = false
load File.join(ROOT, 'lib/ruby2d/cli/spinel.rb')

# Replace the named transforms with the identity, so a workaround can be dropped
# without editing lib/. `web_predicate` appends rather than rewrites, so its
# identity is the empty string.
TRANSFORMS = %w[
  expand_window_singleton bypass_window_class_methods window_guards
  expand_hash_delete disable_class_pattern disable_object_interactivity
  hash_each_next positional_callbacks expand_massign web_predicate dsl_shims
].freeze

skip = (ENV['SPINEL_SKIP'] || '').split(',').map(&:strip).reject(&:empty?)
skip = TRANSFORMS if skip == ['all']
(skip - TRANSFORMS).each { |n| abort "unknown transform #{n.inspect}; known: #{TRANSFORMS.join(', ')}" }

skip.each do |name|
  body =
    case name
    when 'web_predicate' then ->(*) { '' }
    when 'bypass_window_class_methods' then ->(src, _) { src }
    # `include Ruby2D` is emitted separately by spinel_assemble; the shims exist
    # only to put the DSL's instance methods at top level, which `extend` does.
    when 'dsl_shims' then ->(*) { "extend Ruby2D::DSL\n" }
    else ->(src) { src }
    end
  Object.send(:define_method, :"spinel_#{name}", &body)
end
warn "skipping: #{skip.join(', ')}" unless skip.empty?

MAIN = <<~'RUBY'
  sq = Square.new(x: 10, y: 20, size: 50, color: 'red')
  puts "square: x=#{sq.x} y=#{sq.y} size=#{sq.size}"
  w = Ruby2D::DSL.window
  puts "objects: #{w.instance_variable_get(:@objects).size}"
  ticks = 0
  update { ticks += 1 }
  5.times { w.tick }
  puts "ticks: #{ticks}"
  puts 'SUBSET OK'
RUBY

src = spinel_assemble(MAIN, lib_dir: File.join(ROOT, 'lib/ruby2d'), ffi: false)

require 'fileutils'
FileUtils.mkdir_p(File.dirname(OUT))
File.write(OUT, src)
puts "#{OUT}: #{src.lines.size} lines, #{SPINEL_LIB_FILES.size} files"
