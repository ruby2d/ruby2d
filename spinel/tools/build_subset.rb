# Assemble the square-only slice of `lib/` into one Spinel-compilable file.
#
# This is the harness behind every measurement in ../README.md: it concatenates
# the subset, applies the compatibility transforms from `cli/spinel.rb`, stubs
# every `Ext` entry point the subset references, and appends a smoke-test main.
# The result runs identically under CRuby, which is the baseline that makes any
# Spinel difference attributable.
#
#   ruby spinel/tools/build_subset.rb            # writes spinel/scratch/subset.rb
#   ruby spinel/scratch/subset.rb                # CRuby baseline — should print OK
#   $SPINEL spinel/scratch/subset.rb -o out && ./out
#
# Add files to MIN to widen the slice; see ../README.md for what each additional
# subsystem drags in.
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
  expand_massign web_predicate dsl_shims
].freeze

skip = (ENV['SPINEL_SKIP'] || '').split(',').map(&:strip).reject(&:empty?)
skip = TRANSFORMS if skip == ['all']
(skip - TRANSFORMS).each { |n| abort "unknown transform #{n.inspect}; known: #{TRANSFORMS.join(', ')}" }

skip.each do |name|
  body =
    case name
    when 'web_predicate' then ->(*) { '' }
    when 'bypass_window_class_methods' then ->(src, _) { src }
    # `include Ruby2D` is emitted separately below; the shims exist only to put
    # the DSL's instance methods at top level, which `extend` does directly.
    when 'dsl_shims' then ->(*) { "extend Ruby2D::DSL\n" }
    else ->(src) { src }
    end
  Object.send(:define_method, :"spinel_#{name}", &body)
end
warn "skipping: #{skip.join(', ')}" unless skip.empty?

# The minimum for a moving square: no image, text, canvas, audio, sprite or
# button, and none of the shapes a square doesn't use.
MIN = %w[
  mruby_compat cli/colorize exceptions warnings
  window/class_methods window/key_events window/mouse_events
  window/gamepad_events window/object_events
  gamepad window interactive renderable color
  quad rectangle square vertices dsl
].freeze

def lib(name) = File.read(File.join(ROOT, 'lib/ruby2d', "#{name}.rb"))

src = MIN.map { |f| "#{lib(f)}\n\n" }.join
src = spinel_compat(src, lib('window/class_methods'))

# Stub every Ext entry point the subset references, so this exercises `lib/`
# alone — no C, no FFI. Swapping these for real `ffi_func` declarations one at a
# time is the eventual adapter.
ext_calls = MIN.flat_map { |f| lib(f).scan(/Ext\.([a-z_0-9]+)/) }.flatten.uniq.sort
returns = {
  'now' => '0.016', 'begin_frame' => 'true', 'drain_events' => 'nil',
  'window_show' => 'true', 'window_create' => 'true',
  'scancode_name' => "'space'", 'window_cursor_visible' => 'true'
}.freeze
stubs = ext_calls.map { |m| "    def self.#{m}(*args)\n      #{returns.fetch(m, 'nil')}\n    end\n" }

src << "module Ruby2D\n  module Ext\n" << stubs.join("\n") << "  end\nend\n\n"
src << "include Ruby2D\n"
src << spinel_dsl_shims(lib('dsl'))
src << <<~MAIN

  sq = Square.new(x: 10, y: 20, size: 50, color: 'red')
  puts "square: x=\#{sq.x} y=\#{sq.y} size=\#{sq.size}"
  w = Ruby2D::DSL.window
  puts "objects: \#{w.instance_variable_get(:@objects).size}"
  ticks = 0
  update { ticks += 1 }
  5.times { w.tick }
  puts "ticks: \#{ticks}"
  puts 'SUBSET OK'
MAIN

require 'fileutils'
FileUtils.mkdir_p(File.dirname(OUT))
File.write(OUT, src)
puts "#{OUT}: #{src.lines.size} lines, #{MIN.size} files, #{ext_calls.size} Ext stubs"
