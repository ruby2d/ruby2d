# Build the `cli` fixture with both engines and diff what they actually drew.
#
#   cd spinel && rake compare
#
# The checks in check.rb ask whether the Spinel target works. This one asks
# whether it draws the *same thing* mruby does, which is a different question
# and the one that catches silent gaps.
#
# It exists because of a real one: `Ext.stroke_quad_uniform` was an inert stub
# for weeks, so every stroked shape rendered its fill and no outline. The app
# built, ran a healthy frame count, and put pixels on screen — the `cli` check
# only asked for more than one color, and a fill alone clears that. Nothing but
# mruby's screenshot beside Spinel's showed the outline was missing.
#
# Reports a per-color pixel histogram rather than a pass/fail bit: when the two
# do diverge, which color gained or lost pixels says what went wrong.

require 'fileutils'
require_relative 'spinel_env'

ROOT = File.expand_path('../..', __dir__)
Dir.chdir(ROOT)
DIR = 'spinel/scratch/compare'

# `find_spinel` in cli/spinel.rb honors this first, so the `ruby2d build`
# below uses the same compiler the rest of the tools resolve rather than
# whatever a `ruby2d setup --spinel` left in the cache.
ENV['RUBY2D_SPINEL'] = resolve_spinel

# Full pixel rows: the same decoder `png_distinct_colors` uses, stopped one step
# earlier so the pixels themselves can be compared.
def png_rows(path)
  require 'zlib'
  data = File.binread(path)
  raise "not a PNG: #{path}" unless data[0, 8] == "\x89PNG\r\n\x1a\n".b

  pos = 8
  width = height = depth = color_type = nil
  idat = +''.b
  while pos < data.size
    len = data[pos, 4].unpack1('N')
    type = data[pos + 4, 4]
    body = data[pos + 8, len]
    case type
    when 'IHDR' then width, height, depth, color_type, = body.unpack('NNC5')
    when 'IDAT' then idat << body
    when 'IEND' then break
    end
    pos += 12 + len
  end
  raise "unsupported PNG (depth #{depth}, type #{color_type})" unless depth == 8 && [2, 6].include?(color_type)

  channels = color_type == 6 ? 4 : 3
  raw = Zlib::Inflate.inflate(idat)
  stride = width * channels
  prev = "\0".b * stride
  rows = Array.new(height) do |y|
    off = y * (stride + 1)
    line = raw[off + 1, stride].dup
    unfilter_scanline!(line, prev, raw.getbyte(off), channels)
    prev = line
  end
  [width, height, channels, rows]
end

def histogram(rows, channels)
  counts = Hash.new(0)
  rows.each { |line| (0...line.bytesize).step(channels) { |i| counts[line[i, 3].unpack('C3')] += 1 } }
  counts
end

# Both fixtures, because they exercise different `Ext` entry points: a single
# color goes through `draw_quad_uniform`, per-vertex colors through `draw_quad`,
# and a bug in one is invisible to the other. Each was in fact broken while the
# other passed.
FIXTURES = { 'cli' => 'spinel/tools/cli_app.rb',
             'gradient' => 'spinel/tools/gradient_app.rb' }.freeze

# A histogram is how a single-color divergence explains itself — which color
# gained or lost pixels. A gradient has thousands of colors and the same list
# would be unreadable, so past this many it reports the shape of the difference
# instead.
HISTOGRAM_LIMIT = 12

def screenshots(fixture, dir)
  # mruby has no `ENV`, which the fixture reads for its frame cap. Only that
  # plumbing is substituted — both engines compile byte-identical drawing code.
  source = File.read(fixture).sub(/^frames = .*$/, 'frames = 30')

  { 'mruby' => '--native', 'spinel' => '--spinel' }.map do |name, flag|
    shot = File.expand_path("#{dir}/#{name}.png")
    File.write("#{dir}/app.rb", source.sub(/^shot = .*$/, "shot = #{shot.inspect}"))
    puts "    building #{name} (#{flag})…"

    out, status, code = Dir.chdir(dir) { run_capped(['ruby2d', 'build', flag, 'app.rb'], seconds: 900) }
    abort "\n#{name} build failed:\n#{out}" unless status == :ok && code&.zero?

    binary = File.expand_path("#{dir}/build/native/app")
    abort "\n#{name}: nothing at #{binary}" unless File.exist?(binary)

    ran, status = run_capped([binary], seconds: 60)
    abort "\n#{name} hung" if status == :timeout
    abort "\n#{name} wrote no screenshot:\n#{ran}" unless File.exist?(shot)

    FileUtils.rm_rf("#{dir}/build")
    [name, png_rows(shot)]
  end.to_h
end

diverged = FIXTURES.map do |label, fixture|
  dir = "#{DIR}/#{label}"
  FileUtils.rm_rf(dir)
  FileUtils.mkdir_p(dir)
  puts "\n  #{label}\n\n"

  shots = screenshots(fixture, dir)
  a = shots['mruby']
  b = shots['spinel']
  abort "\n  different geometry: mruby #{a[0]}x#{a[1]}, spinel #{b[0]}x#{b[1]}" \
    unless a[0] == b[0] && a[1] == b[1] && a[2] == b[2]

  ha = histogram(a[3], a[2])
  hb = histogram(b[3], b[2])
  colors = (ha.keys | hb.keys)

  puts "\n  #{a[0]}x#{a[1]}, #{colors.size} colors between them\n\n"
  if colors.size <= HISTOGRAM_LIMIT
    puts format('  %-18s %10s %10s', 'color', 'mruby', 'spinel')
    colors.sort_by { |c| -(ha[c] + hb[c]) }.each do |color|
      puts format('  %-18s %10d %10d%s', color.inspect, ha[color], hb[color],
                  ha[color] == hb[color] ? '' : '  <- differs')
    end
  else
    only_mruby = (ha.keys - hb.keys).size
    only_spinel = (hb.keys - ha.keys).size
    puts format('  %d colors only mruby drew, %d only Spinel drew', only_mruby, only_spinel)
  end

  differing = a[3].each_index.count { |y| a[3][y] != b[3][y] }
  if differing.zero?
    puts "\n  Identical: every pixel of #{a[1]} scanlines matches."
    false
  else
    puts "\n  DIVERGED: #{differing} of #{a[1]} scanlines differ."
    puts '  A color present for mruby and absent for Spinel is an inert `Ext` stub.'
    puts '  The same drawing in the wrong place is an `Ext` adapter taking its'
    puts '  arguments in a different order from the `lib/` call.'
    true
  end
end

puts
exit 1 if diverged.any?
