# Assemble the square demo — a real Ruby 2D script, window, Ruby-owned loop —
# into one Spinel-compilable file with `Ext` backed by FFI.
#
#   ruby spinel/tools/build_square.rb                 # writes spinel/scratch/square.rb
#   ruby spinel/scratch/square.rb                     # CRuby control (needs the gem)
#
# Then build and link with `link_square.sh`. `FRAMES=n` caps the run and
# `SHOT=path` writes a screenshot, so the build can be checked without a human
# watching a window.
#
# `build_subset.rb`'s sibling: same assembly, same transforms, but the `Ext`
# entry points are real calls into the `RUBY2D_NO_RUBY` core rather than stubs.
# Both go through `spinel_assemble` from `cli/spinel.rb`, so this demo builds
# the way `ruby2d build --spinel` does and its result is evidence about the CLI.

ROOT = File.expand_path('../..', __dir__)
OUT  = File.join(ROOT, 'spinel', 'scratch', 'square.rb')

def error(msg) = warn(msg)
def find_executable(_name) = nil
def cache_platform_dir = '/nonexistent'
def cache_stamp_ok?(_dir) = false
load File.join(ROOT, 'lib/ruby2d/cli/spinel.rb')

MAIN = <<~'RUBY'
  set title: 'Ruby 2D on Spinel', width: 400, height: 300, background: 'navy'
  Square.new(x: 160, y: 110, size: 80, color: 'red')

  frames = (ENV['FRAMES'] || '0').to_i
  shot = ENV['SHOT'] || ''
  n = 0
  update do
    n += 1
    Ruby2D::DSL.window.screenshot(shot) if !shot.empty? && n == frames
    close if frames.positive? && n > frames
  end

  show
  puts "rendered #{n} frames"
  puts "objects: #{Ruby2D::DSL.window.instance_variable_get(:@objects).size}"
RUBY

src = spinel_assemble(MAIN, lib_dir: File.join(ROOT, 'lib/ruby2d'))

require 'fileutils'
FileUtils.mkdir_p(File.dirname(OUT))
File.write(OUT, src)
puts "#{OUT}: #{src.lines.size} lines"
