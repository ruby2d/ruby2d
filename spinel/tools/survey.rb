# What stands between the whole library and a clean Spinel build?
#
#   cd spinel && rake survey
#
# The other checks measure the slice that works. This one measures the gap: it
# assembles all 37 `LIB_FILES` with the compatibility layer off and reports
# everything that has to change before `ruby2d build --spinel` could compile a
# full-featured app.
#
# **Why this is not just "run the compiler and read the errors".** Spinel stops
# at the first construct it refuses and never reaches the next, so a plain build
# reports one blocker at a time no matter how many there are — which is why they
# were found one per session for a week. Each entry in NEUTRALIZE below is a
# blocker already identified, edited out so the one behind it becomes visible.
# The list *is* the finding; the program it produces is not meant to run.
#
# Add to NEUTRALIZE when a new blocker appears, and delete an entry once the
# underlying issue is fixed — a missing site raises rather than passing quietly.

require 'fileutils'
require_relative 'spinel_env'

ROOT = File.expand_path('../..', __dir__)
Dir.chdir(ROOT)
SPINEL = resolve_spinel
OUT = 'spinel/scratch/survey.rb'
BIN = 'spinel/scratch/survey.bin'

# `cli/spinel.rb` expects the surrounding build path; stub what it reaches for.
def error(msg) = warn(msg)
def find_executable(_name) = nil
def cache_platform_dir = '/nonexistent'
def cache_stamp_ok?(_dir) = false
load File.join(ROOT, 'lib/ruby2d/cli/spinel.rb')

Object.send(:remove_const, :SPINEL_LIB_FILES)
SPINEL_LIB_FILES = Ruby2D::CLI::LIB_FILES

# Only the `web?` shim stays: it stands in for a method C registers on the other
# engines, absent under RUBY2D_NO_RUBY. Leaving it out would report a missing
# method that is our artifact rather than anything Spinel does wrong.
#
# `bypass_window_class_methods` is applied too — its blocker sits early and
# would mask everything behind it. It is a compiler bug in its own right, listed
# under "still worked around" below.
def spinel_compat(src, class_methods_source)
  spinel_bypass_window_class_methods(src, class_methods_source) + spinel_web_predicate
end

def spinel_dsl_shims(_dsl_source) = "extend Ruby2D::DSL\n"

# :aot  — inherent to ahead-of-time compilation. Never fixed upstream; needs a
#         change in `lib/`, and each one costs a feature or an idiom.
# :bug  — a compiler bug, filed or filable.
NEUTRALIZE = [
  { kind: :aot, label: 'send with a runtime method name (3 sites)',
    note: 'window and per-object event filters; a compile-time predicate table would replace it',
    subs: [['e.send(:"#{k}?", v)', '(e.nil? && v.nil?)'],      # rubocop:disable Lint/InterpolationCheck
           ['e.send(predicate, v)', '(e.nil? && v.nil?)']] },

  { kind: :aot, label: 'Object#define_singleton_method (button.rb)',
    note: 'no per-object method table exists when every call site is a direct C call',
    subs: [["      @visual.define_singleton_method(:_resolve_alignment) do\n" \
            "        super()\n" \
            "        button.send(:_sync_from_visual)\n" \
            "      end\n",
            "      # survey: define_singleton_method removed\n"]] },

  { kind: :aot, label: 'Module#undef_method (image, canvas, tileset)',
    note: 'methods resolve statically, so there is no table to undefine from',
    subs: [['    undef_method :color, :color=, :colour, :colour=',
            '    # survey: undef_method removed']] },

  { kind: :bug, label: 'a lambda capturing the enclosing block parameter (interactive.rb)',
    note: 'unsupported proc referencing an uncaptured outer variable; same family as issue 11',
    subs: [['          wrapped = ->(e) { proc.call(e) if values.any? { |v| (e.nil? && v.nil?) } }',
            '          wrapped = ->(e) { e }']] },

  { kind: :bug, label: 'Hash#delete_if on an ivar (object_events.rb)',
    note: 'unsupported call, two-parameter block on an instance variable',
    subs: [['        @pressed_objects.delete_if { |_btn, info| info[:object] == object }',
            '        @pressed_objects = {}']] }
].freeze

src = spinel_assemble("puts 'SURVEY'\n", lib_dir: File.join(ROOT, 'lib/ruby2d'), ffi: false)

applied = NEUTRALIZE.map do |entry|
  entry[:subs].each do |from, to|
    raise "#{entry[:label]}: site not found — lib/ drifted, or this is fixed" unless src.include?(from)

    src = src.gsub(from, to)
  end
  entry
end

FileUtils.mkdir_p(File.dirname(OUT))
File.write(OUT, src)

FileUtils.rm_f(BIN)
out, = run_capped([SPINEL, OUT, '-o', BIN, '--cc=cc -ferror-limit=0'], seconds: 1800)

puts "\n  #{SPINEL_LIB_FILES.size} files, #{src.lines.size} lines, compatibility layer off\n\n"

puts '  Inherent AOT limits — a change in lib/, not an upstream fix:'
applied.select { |e| e[:kind] == :aot }.each { |e| puts "    #{e[:label]}\n      #{e[:note]}" }

puts "\n  Compiler bugs blocking the build, edited out to see past them:"
applied.select { |e| e[:kind] == :bug }.each { |e| puts "    #{e[:label]}\n      #{e[:note]}" }

puts "\n  Still worked around by cli/spinel.rb (each a compiler bug):"
puts '    bypass_window_class_methods — applied above; a class method on a constant receiver via extend'
puts '    window_guards (#3788) and dsl_shims (#3787) — both fixed upstream, both still needed here'
puts '    expand_hash_delete, disable_class_pattern (an AOT limit)'

if File.exist?(BIN)
  puts "\n  Then it compiles. Nothing else blocks a clean build.\n\n"
else
  census = out.scan(/error: (.+)/).flatten.tally.sort_by { |_, n| -n }
  puts "\n  Remaining C errors — clang reports these all at once, so this list is complete:"
  census.each { |msg, n| puts format('    %3d  %s', n, msg) }
  puts
end
