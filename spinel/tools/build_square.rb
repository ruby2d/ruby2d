# Assemble a real Ruby 2D script — window, square, Ruby-owned loop — into one
# Spinel-compilable file, with `Ext` backed by FFI instead of stubs.
#
#   ruby spinel/tools/build_square.rb                 # writes spinel/scratch/square.rb
#   ruby spinel/tools/patch_next.rb   spinel/scratch/square.rb
#   ruby spinel/tools/patch_capture.rb spinel/scratch/square.rb
#   ruby spinel/scratch/square.rb                     # CRuby control (needs the gem)
#
# Then build and link per "Building the demo" in ../README.md. `FRAMES=n` caps
# the run and `SHOT=path` writes a screenshot, so the build can be checked
# without a human watching a window.
#
# This is `build_subset.rb`'s sibling: same slice of `lib/`, same compatibility
# transforms, but the 41 `Ext` entry points become real calls into the
# `RUBY2D_NO_RUBY` core rather than stubs returning nil.

ROOT = File.expand_path('../..', __dir__)
OUT  = File.join(ROOT, 'spinel', 'scratch', 'square.rb')

def error(msg) = warn(msg)
def find_executable(_name) = nil
def cache_platform_dir = '/nonexistent'
def cache_stamp_ok?(_dir) = false
load File.join(ROOT, 'lib/ruby2d/cli/spinel.rb')

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

# Ruby has to own the main loop: Spinel's FFI has no callbacks, so the mruby
# branch — where `window_show` blocks in C and drives the frame loop — can never
# work here. `RUBY_ENGINE` is "spinel", so the CRuby test is false and that is
# exactly the branch it would take. See ../README.md.
src = spinel_sub(src,
                 "      if RUBY_ENGINE == 'ruby'\n",
                 "      if true # Spinel: Ruby owns the loop, as on CRuby\n",
                 'Window#show engine branch')

# `Ext` on this target ###########################################################
#
# Every `Ext` call in `lib/` passes `self` so C can read the window's ivars.
# Spinel FFI cannot read a Ruby object, so each one is a Ruby method here that
# reads the ivars itself and calls a flattened `R2D_*` entry point. That is the
# whole shape of the adapter, and why `R2D_ShowWindow` takes twelve parameters.
FFI = <<~'RUBY'
  module Ruby2D
    module Ext
      ffi_func :R2D_ShowWindow, [:str, :int, :int, :bool, :bool, :bool, :double,
                                 :int, :int, :str, :str, :str], :bool
      ffi_func :R2D_CreateWindow, [:str, :int, :int, :int, :int, :str], :bool
      ffi_func :R2D_CloseWindow, [], :void
      ffi_func :R2D_LastError, [], :str
      ffi_func :R2D_PollEvents, [], :void
      ffi_func :R2D_PollClosed, [], :bool
      ffi_func :R2D_PollMouseX, [], :int
      ffi_func :R2D_PollMouseY, [], :int
      ffi_func :R2D_PollWidth, [], :int
      ffi_func :R2D_PollHeight, [], :int
      ffi_func :R2D_PollViewportWidth, [], :int
      ffi_func :R2D_PollViewportHeight, [], :int
      ffi_func :R2D_BeginFrame, [:float, :float, :float, :float], :bool
      ffi_func :R2D_EndFrame, [], :void
      ffi_func :R2D_FrameCount, [], :int
      ffi_func :R2D_Fps, [], :double
      ffi_func :R2D_Now, [], :double
      ffi_func :R2D_GetWindow, [], :ptr
      ffi_func :R2D_Screenshot, [:ptr, :str], :void
      # Spelled out, not `[:float] * 24` — a computed type array is rejected.
      # See "Workarounds to re-check" in ../README.md.
      ffi_func :R2D_DrawQuad, [:float, :float, :float, :float, :float, :float,
                               :float, :float, :float, :float, :float, :float,
                               :float, :float, :float, :float, :float, :float,
                               :float, :float, :float, :float, :float, :float], :void

      # `Window#initialize` calls this; the real window is not created until
      # `window_show`, but the core needs its R2D_Window allocated first.
      def self.window_create(win)
        ok = Ext.R2D_CreateWindow(win.title, win.width, win.height,
                                  win.viewport_width, win.viewport_height,
                                  win.viewport_mode.to_s)
        raise Error, "failed to allocate the window: #{Ext.R2D_LastError()}" unless ok

        ok
      end

      def self.window_show(win)
        ok = Ext.R2D_ShowWindow(win.title, win.width, win.height,
                                win.resizable, win.highdpi, win.pixel_scale,
                                win.fps_cap ? win.fps_cap.to_f : -1.0,
                                win.viewport_width, win.viewport_height,
                                win.viewport_mode.to_s, win.render_mode.to_s,
                                win.icon || '')
        raise Error, "failed to create the window: #{Ext.R2D_LastError()}" unless ok

        ok
      end

      def self.window_close(_win) = Ext.R2D_CloseWindow()

      # `poll_events` updates the window's own state in C on the other engines;
      # here the state comes back through the pollers and is written in Ruby.
      def self.poll_events(win)
        Ext.R2D_PollEvents()
        win._spinel_sync(Ext.R2D_PollMouseX(), Ext.R2D_PollMouseY(),
                         Ext.R2D_PollWidth(), Ext.R2D_PollHeight(),
                         Ext.R2D_PollViewportWidth(), Ext.R2D_PollViewportHeight(),
                         Ext.R2D_PollClosed())
        nil
      end

      # No input on this target yet: window-level `on` does not compile, so
      # there is nothing to dispatch. `nil` makes `tick` skip dispatch entirely.
      def self.drain_events(_win) = nil

      def self.begin_frame(win)
        bg = win.background
        Ext.R2D_BeginFrame(bg.r, bg.g, bg.b, bg.a)
      end

      def self.end_frame(_win)
        Ext.R2D_EndFrame()
        nil
      end

      def self.now = Ext.R2D_Now()

      def self.window_screenshot(_win, path)
        Ext.R2D_Screenshot(Ext.R2D_GetWindow, path)
        nil
      end

      # Counted so a blank window can be told apart from a window that drew
      # nothing — the two look identical.
      def self.draws = @draws || 0

      # `.to_f` is not decoration: a shape built with integer literals
      # (`Square.new(x: 160, size: 80)`) hands Integers to `:float` parameters,
      # and the window renders blank with no error.
      def self.draw_quad_uniform(x1, y1, x2, y2, x3, y3, x4, y4, r, g, b, a)
        @draws = (@draws || 0) + 1
        Ext.R2D_DrawQuad(x1.to_f, y1.to_f, r.to_f, g.to_f, b.to_f, a.to_f,
                         x2.to_f, y2.to_f, r.to_f, g.to_f, b.to_f, a.to_f,
                         x3.to_f, y3.to_f, r.to_f, g.to_f, b.to_f, a.to_f,
                         x4.to_f, y4.to_f, r.to_f, g.to_f, b.to_f, a.to_f)
      end

      def self.draw_quad(x1, y1, x2, y2, x3, y3, x4, y4,
                         r1, g1, b1, a1, r2, g2, b2, a2,
                         r3, g3, b3, a3, r4, g4, b4, a4)
        Ext.R2D_DrawQuad(x1, y1, r1, g1, b1, a1, x2, y2, r2, g2, b2, a2,
                         x3, y3, r3, g3, b3, a3, x4, y4, r4, g4, b4, a4)
      end
    end
  end
RUBY

# Everything else the slice references but a static square never reaches. These
# have to exist — Spinel compiles the whole reachable graph, so a missing method
# is a compile error even on a path that never runs — but they can do nothing.
covered = FFI.scan(/def self\.([a-z_0-9]+)/).flatten
stubbed = MIN.flat_map { |f| lib(f).scan(/Ext\.([a-z_0-9]+)/) }.flatten.uniq.sort - covered
returns = { 'window_cursor_visible' => 'true',
            'scancode_name' => "'space'", 'render' => 'nil' }.freeze

src << FFI
src << "module Ruby2D\n  module Ext\n"
src << stubbed.map { |m| "    def self.#{m}(*args)\n      #{returns.fetch(m, 'nil')}\n    end\n" }.join("\n")
src << "  end\nend\n\n"

# `poll_events` writes back through this rather than six attr_writers, keeping
# the flattened-state seam in one named place.
src << <<~'RUBY'
  module Ruby2D
    class Window
      def _spinel_sync(mx, my, w, h, vw, vh, closed)
        @mouse_x = mx
        @mouse_y = my
        @width = w
        @height = h
        @viewport_width = vw
        @viewport_height = vh
        @close = true if closed
        nil
      end
    end
  end

RUBY

src << "include Ruby2D\n"
src << spinel_dsl_shims(lib('dsl'))
src << <<~'MAIN'

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
  puts "rendered #{n} frames, #{Ruby2D::Ext.draws} quad draws"
  puts "objects: #{Ruby2D::DSL.window.instance_variable_get(:@objects).size}"
MAIN

require 'fileutils'
FileUtils.mkdir_p(File.dirname(OUT))
File.write(OUT, src)
puts "#{OUT}: #{src.lines.size} lines, #{covered.size} FFI-backed, #{stubbed.size} inert"
