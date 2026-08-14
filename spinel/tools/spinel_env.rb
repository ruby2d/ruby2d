# Shared helpers for the Spinel tools: finding the compiler, and running things
# that might not terminate.

require 'open3'

# Same order as `find_spinel` in lib/ruby2d/cli/spinel.rb, plus a checkout
# beside this repo — so no recipe in ../README.md needs a machine-specific path.
def resolve_spinel
  # Absolute, always. `$SPINEL=../spinel/bin/spinel` resolves here and then
  # breaks in any tool that chdirs before building — which `motion.rb` does,
  # and which read as three failed builds rather than as a bad path.
  [ENV['SPINEL'], ENV['RUBY2D_SPINEL'],
   File.expand_path('../../../spinel/bin/spinel', __dir__)].each do |c|
    return File.expand_path(c) if c && !c.empty? && File.executable?(c)
  end
  found = ENV['PATH'].to_s.split(File::PATH_SEPARATOR)
                     .map { |d| File.join(d, 'spinel') }.find { |f| File.executable?(f) }
  found or abort <<~MSG
    No spinel binary found. Build one and either put it on PATH, clone it
    beside this repo as ../spinel, or point SPINEL at it:

      git clone https://github.com/matz/spinel.git ../spinel
      (cd ../spinel && make deps && make)

    See "Setup" in spinel/README.md.
  MSG
end

# Run with a hard cap. Two open Spinel bugs are infinite loops, so anything that
# executes freshly compiled code needs one — a checker that hangs on them is no
# better than the bug.
#
# Returns [output, :ok | :timeout | :error, exit code]. The exit code is
# separate from the status because they answer different questions: whether the
# command finished, and whether it succeeded. A killed process has no code.
def run_capped(cmd, seconds: 20)
  out = nil
  code = nil
  status = :ok
  Open3.popen2e(*cmd) do |_in, o, t|
    killer = Thread.new do
      sleep seconds
      status = :timeout
      Process.kill('KILL', t.pid)
    rescue StandardError
      nil
    end
    out = o.read
    code = t.value.exitstatus
    killer.kill
  end
  [out.to_s, status, code]
rescue StandardError => e
  ["#{e.class}: #{e.message}", :error, nil]
end

# The compatibility transforms `cli/spinel.rb` applies, read out of the file
# rather than listed here. Two tools need this list and both had hardcoded
# copies that went stale the moment a transform was added or dropped — which is
# the same drift the transforms themselves guard against.
#
# `spinel_compat` names most of them; `dsl_shims` is applied later in
# `spinel_assemble`, so it is added explicitly.
def spinel_transform_names(cli_spinel_path)
  source = File.read(cli_spinel_path)
  body = source[/^def spinel_compat\b.*?^end$/m] or
    raise "could not find spinel_compat in #{cli_spinel_path}"

  names = body.scan(/\bspinel_(\w+)/).flatten - %w[compat sub]
  (names + %w[dsl_shims]).uniq
end


# Distinct colors in a PNG, or nil if it can't be decoded.
#
# This exists for one reason: a window that renders nothing looks exactly like a
# window that renders correctly, from the outside. Passing Integers to `:float`
# FFI parameters produced a blank window with no error and a healthy-looking
# draw count — only the pixels showed it. Handles the 8-bit RGB/RGBA
# non-interlaced case SDL writes; anything else returns nil (skip, not fail).
def png_distinct_colors(path)
  require 'zlib'
  data = File.binread(path)
  return nil unless data[0, 8] == "\x89PNG\r\n\x1a\n".b

  pos = 8
  width = height = depth = color_type = interlace = nil
  idat = +''.b
  while pos < data.size
    len = data[pos, 4].unpack1('N')
    type = data[pos + 4, 4]
    body = data[pos + 8, len]
    case type
    when 'IHDR'
      width, height, depth, color_type, _, _, interlace = body.unpack('NNC5')
    when 'IDAT' then idat << body
    when 'IEND' then break
    end
    pos += 12 + len
  end
  return nil unless depth == 8 && [2, 6].include?(color_type) && interlace.to_i.zero?

  channels = color_type == 6 ? 4 : 3
  raw = Zlib::Inflate.inflate(idat)
  stride = width * channels
  colors = {}
  prev = "\0".b * stride
  height.times do |y|
    off = y * (stride + 1)
    filter = raw.getbyte(off)
    line = raw[off + 1, stride].dup
    unfilter_scanline!(line, prev, filter, channels)
    (0...stride).step(channels) { |i| colors[line[i, channels]] = true }
    prev = line
  end
  colors.size
rescue StandardError
  nil
end

# PNG scanline filters (RFC 2083 §6), in place.
def unfilter_scanline!(line, prev, filter, bpp)
  return if filter.zero?

  line.bytesize.times do |i|
    a = i >= bpp ? line.getbyte(i - bpp) : 0
    b = prev.getbyte(i) || 0
    c = i >= bpp ? (prev.getbyte(i - bpp) || 0) : 0
    add =
      case filter
      when 1 then a
      when 2 then b
      when 3 then (a + b) / 2
      when 4 then paeth(a, b, c)
      else 0
      end
    line.setbyte(i, (line.getbyte(i) + add) & 0xff)
  end
end

def paeth(a, b, c)
  p = a + b - c
  pa = (p - a).abs
  pb = (p - b).abs
  pc = (p - c).abs
  pa <= pb && pa <= pc ? a : (pb <= pc ? b : c)
end
