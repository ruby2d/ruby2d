# Spinel build path — compile a Ruby 2D app ahead-of-time with Spinel instead
# of mruby. Opt in with `ruby2d build --spinel`; mruby remains the default.
#
# Whole-program AOT: the library slice, the FFI adapter, and the app become one
# Ruby file, which Spinel compiles to C and hands to the same C compiler the
# mruby path uses. The sections below follow that order — Compatibility rewrites
# the library source, Assembly joins the pieces, Preflight refuses what this
# target can't build, and Build runs the compiler.
#
# Everything in "Compatibility" is a workaround for a current Spinel limitation,
# applied to the assembled source rather than to `lib/` so that the library
# stays idiomatic and each workaround can be deleted in one place when upstream
# fixes it. `spinel/README.md` pins every one to the Spinel commit it was needed
# at, with the probe to re-check it.
#
# Each transformation asserts that it matched. A `lib/` edit that invalidates
# one fails the build loudly instead of silently producing a source that no
# longer has the workaround applied.

require 'ruby2d/cli/colorize'
require 'ruby2d/cli/messages'
require 'ruby2d/cli/lib_files'
require_relative '../../../assets/target'


# Compatibility ################################################################

# Raised when a compatibility transformation no longer matches the library it
# rewrites — i.e. `lib/` changed and this file needs updating (or the
# workaround can be dropped because Spinel fixed it).
class SpinelCompatDrift < StandardError; end

# Apply `sub`, failing loudly if the pattern isn't found. `what` names the
# workaround so the error points at the right entry in spinel/README.md.
def spinel_sub(src, from, to, what)
  raise SpinelCompatDrift, "Spinel compat `#{what}` no longer matches lib/. See spinel/README.md." unless src.include?(from)

  src.sub(from, to)
end


# `Ruby2D.web?` is registered from C (`ruby2d.c`), so it disappears along with
# the binding layer under RUBY2D_NO_RUBY. The Spinel target is native.
def spinel_web_predicate
  "module Ruby2D\n  def self.web?\n    false\n  end\nend\n\n"
end


# A proc created inside a method that came from an **included module** cannot
# capture that method's block parameter: the capture pass looks the name up in
# the immediately enclosing scope, doesn't find it, and refuses the program with
# "proc referencing an uncaptured outer variable `proc` (later slice)".
# `Interactive#on`'s filtered form is the only place in `lib/` with that shape,
# and `Interactive` is included into `Renderable`, so it reaches every shape.
#
# Aliasing the block parameter to an ordinary local first is enough — the lambda
# then captures a plain local, which resolves. Drafted as issue 34, unfiled.
#
# **This was deleted on 2026-08-13 and put straight back.** `rake sweep` called
# it droppable, and it was — for the subset, whose main did not register an `on`
# handler, so the refused lambda was never reachable. Every real app using `on`
# failed to build. `build_subset.rb`'s MAIN now registers one, so the sweep can
# see this path; do not drop this transform on a sweep result alone until an
# `on`-using program builds without it.
def spinel_block_param_capture(src)
  spinel_sub(src,
             "          wrapped = ->(e) { proc.call(e) if values.any? { |v| e.matches?(field, v) } }\n",
             "          handler = proc\n" \
             "          wrapped = ->(e) { handler.call(e) if values.any? { |v| e.matches?(field, v) } }\n",
             'lambda capturing a module method’s block parameter')
end


# `Window#overrides?` detects the class pattern — a `Ruby2D::Window` subclass
# overriding `update` / `render` — by walking the ancestor chain and asking each
# module which instance methods it defines. That is runtime reflection over the
# class graph, which whole-program AOT compilation cannot provide: the graph is
# baked at compile time and no metaobject survives into the binary.
#
# Unlike everything else here this is not a compiler bug and there is nothing to
# report upstream. It is a real, permanent gap in what the Spinel target can
# offer, so the class pattern is switched off there and the DSL pattern
# (`update do ... end`) carries the whole API. See spinel/README.md.
def spinel_disable_class_pattern(src)
  spinel_sub(src,
             "    def overrides?(name)\n" \
             "      wrappers = Window.ancestors - [Window]\n" \
             "      owner = self.class.ancestors.find do |mod|\n" \
             "        !wrappers.include?(mod) && mod.instance_methods(false).include?(name)\n" \
             "      end\n" \
             "      owner != Window\n" \
             "    end\n",
             "    def overrides?(_name)\n" \
             "      # Always false on the Spinel target: detecting the class pattern needs\n" \
             "      # ancestor reflection, which an AOT build has no way to answer.\n" \
             "      false\n" \
             "    end\n",
             'Window#overrides? class-pattern detection')
end


# Top-level `include`/`extend` of a module with instance methods is miscompiled,
# so the mruby preamble's `extend Ruby2D::DSL` can't be used. Every DSL method is
# a self-contained delegation to `DSL.window`, so they lift to the top level
# verbatim. `include Ruby2D` is kept — it only brings in constants, which works.
def spinel_dsl_shims(dsl_source)
  body = dsl_source[/module DSL\n(.*)\n  end\n/m, 1] or
    raise SpinelCompatDrift, 'Spinel compat `DSL shims` could not find the DSL module body. See spinel/README.md.'

  # Instance methods only — `def self.window` and friends stay on the module and
  # are called by the shims.
  shims = body.scan(/^    def ([a-z_][\w]*[?=]?(?:\([^)]*\))?)\n(.*?)^    end$/m).reject do |sig, _|
    sig.start_with?('self.')
  end
  raise SpinelCompatDrift, 'Spinel compat `DSL shims` found no DSL methods. See spinel/README.md.' if shims.empty?

  shims.map do |sig, inner|
    "def #{sig}\n#{inner.gsub(/^      /, '  ').gsub('DSL.window', 'Ruby2D::DSL.window')}end\n"
  end.join("\n")
end


# `Window::ObjectEventDispatch#cleanup_interaction_state` drops a released
# button's press record with `Hash#delete_if`. In the assembled library that
# Hash compiles to a kind with no `delete_if` (nor `reject!`), and the first
# object removed after a press raises `undefined method 'delete_if' for an
# instance of Hash`. Every standalone replica — plain, in an included module,
# with poly objects as values — compiles and runs correctly, so the kind is
# decided by something in the wider program that has not been isolated; draft
# 50 holds the harness that reproduces it. Iterating a snapshot of the keys
# and deleting by key is the same operation with methods the kind does have.
def spinel_hash_delete_if(src)
  spinel_sub(src,
             "        @pressed_objects.delete_if { |_btn, info| info[:object] == object }\n",
             "        @pressed_objects.keys.each do |btn|\n" \
             "          @pressed_objects.delete(btn) if @pressed_objects[btn][:object] == object\n" \
             "        end\n",
             'Hash#delete_if on the pressed-object map')
end


# `Canvas` removes `Renderable`'s `color` accessors with `undef_method`, since it
# has `tint` instead. Whole-program AOT compiles every call to a direct C call,
# so there is no method table to undefine from and Spinel refuses the call.
# Dropping it loses nothing on this target: a `color` call on a Canvas would
# be resolved statically either way. An AOT gap, not a bug.
def spinel_undef_color(src)
  line = "    undef_method :color, :color=, :colour, :colour=\n"
  unless src.scan(line).size == 2
    raise SpinelCompatDrift, 'Spinel compat `undef_color` no longer matches lib/ (expected Canvas and Image). See spinel/README.md.'
  end

  src.gsub(line, '')
end


# `Image#initialize` takes `_share_from:`, the Image whose decoded texture a
# `SpriteSheet`'s sprites share, and copies its state with
# `instance_variable_get` — runtime reflection an AOT build refuses. Neither
# class is on this target yet, so the branch becomes a raise until they are.
def spinel_image_share_from(src)
  spinel_sub(src,
             "      if _share_from\n" \
             "        # SpriteSheet uses this to give every Sprite the same backing texture\n" \
             "        # without re-decoding the file or re-uploading to the GPU.\n" \
             "        @path        = _share_from.path\n" \
             "        @ext_image   = _share_from.instance_variable_get(:@ext_image)\n" \
             "        # Inherit the sheet's sampling unless this Sprite asked for its own\n" \
             "        @scale_mode ||= _share_from.scale_mode\n" \
             "        @orig_width  = _share_from.instance_variable_get(:@orig_width)\n" \
             "        @orig_height = _share_from.instance_variable_get(:@orig_height)\n" \
             "        @width     ||= @orig_width\n" \
             "        @height    ||= @orig_height\n" \
             "        @clipped     = false\n" \
             "        @clip_x      = 0.0\n" \
             "        @clip_y      = 0.0\n" \
             "        @clip_width  = @orig_width\n" \
             "        @clip_height = @orig_height\n" \
             "      else\n",
             "      if _share_from\n" \
             "        raise Error, 'SpriteSheet is not available on the Spinel target'\n" \
             "      else\n",
             'Image _share_from state copy')
end


# `Button` reaches into a wrapped visual two ways an AOT build cannot follow:
# `define_singleton_method` to wrap the visual's alignment resolver so a
# symbolic `align:` keeps the label centered, and `send` to read a private
# anchor offset for a center-anchored visual. Both are runtime reflection
# (`rake survey` lists `define_singleton_method` as the remaining AOT limit),
# so on this target a Button wrapping a visual keeps its label centered on
# the visual's top-left anchor and does not follow a later symbolic
# alignment. No program in `examples/` or `test/` passes a visual or `align:`
# to a Button. A feature gap, not a compiler bug.
def spinel_button_visual_hooks(src)
  src = spinel_sub(src,
                   "      if @visual && !@owns_visual && @visual.respond_to?(:_alignment_anchor_dx, true)\n" \
                   "        [@visual.send(:_alignment_anchor_dx), @visual.send(:_alignment_anchor_dy)]\n" \
                   "      else\n" \
                   "        [0, 0]\n" \
                   "      end\n",
                   "      [0, 0]\n",
                   'Button visual anchor offset')
  spinel_sub(src,
             "      return unless @visual.respond_to?(:_resolve_alignment)\n\n" \
             "      button = self\n" \
             "      @visual.define_singleton_method(:_resolve_alignment) do\n" \
             "        super()\n" \
             "        button.send(:_sync_from_visual)\n" \
             "      end\n",
             "      nil\n",
             'Button alignment hook')
end


# Apply every compatibility transformation to the assembled library source.
# Four of the five are not compiler bugs: the class pattern and Button's visual
# hooks need reflection an AOT build cannot provide, `undef_method` needs a
# method table it does not have, and `web?` stands in for a method C registers
# on the other engines.
def spinel_compat(src)
  src = spinel_block_param_capture(src)
  src = spinel_hash_delete_if(src)
  src = spinel_undef_color(src)
  src = spinel_image_share_from(src)
  src = spinel_button_visual_hooks(src)
  src = spinel_disable_class_pattern(src)
  src + spinel_web_predicate
end


# Assembly #####################################################################

# The slice of `lib/` this target compiles. Deliberately not `CLI::LIB_FILES`:
# every subsystem left out here needs `Ext` entry points the FFI adapter below
# doesn't have yet, and Spinel compiles the whole reachable graph — so an
# unsupported file is a compile error, not a feature that quietly does nothing.
# `spinel_preflight!` reads the difference between the two lists to tell the
# user which class isn't available, so widening one widens the other.
SPINEL_LIB_FILES = %w[
  mruby_compat
  cli/colorize
  exceptions
  warnings
  window/class_methods
  window/key_events
  window/mouse_events
  window/gamepad_events
  window/object_events
  vocabulary
  keyboard
  mouse
  gamepad
  window
  interactive
  renderable
  color
  quad
  rectangle
  square
  circle
  line
  font
  text
  image
  canvas
  polyline
  triangle
  button
  vertices
  dsl
].freeze

# The C sources that make up the `RUBY2D_NO_RUBY` core — the `R2D_*` renderer
# with no Ruby engine in it. The rest of `ext/ruby2d` is either the CRuby/mruby
# binding layer (`ext.c`) or a subsystem this slice doesn't reach.
SPINEL_CORE_FILES = %w[ruby2d window shapes fps font keyboard text image canvas].freeze

# `Ext` on this target.
#
# Every `Ext` call in `lib/` passes `self` so C can read the window's ivars.
# Spinel's FFI cannot read a Ruby object and C can never call back into Ruby, so
# each entry point is a Ruby method here that reads the ivars itself and calls a
# flattened `R2D_*` function. That is the whole shape of the adapter, and why
# `R2D_ShowWindow` takes thirteen parameters.
SPINEL_EXT = <<~'RUBY'
  module Ruby2D
    module Ext
      ffi_func :R2D_ShowWindow, [:str, :int, :int, :bool, :bool, :bool, :double,
                                 :int, :int, :str, :str, :str, :str], :bool
      ffi_func :R2D_CreateWindow, [:str, :int, :int, :int, :int, :str], :bool
      ffi_func :R2D_CloseWindow, [], :void
      ffi_func :R2D_LastError, [], :str
      ffi_func :R2D_PollEvents, [], :void
      ffi_func :R2D_PollClosed, [], :bool
      ffi_func :R2D_EventCount, [], :int
      ffi_func :R2D_EventInt, [:int, :int], :int
      ffi_func :R2D_EventDelta, [:int, :int], :double
      ffi_func :R2D_EventStr, [:int], :str
      ffi_func :R2D_EventKeyName, [:int], :str
      ffi_func :R2D_EventsClear, [], :void
      ffi_func :R2D_KeyName, [:int], :str
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
      ffi_func :R2D_DrawQuad, [:float, :float, :float, :float, :float, :float,
                               :float, :float, :float, :float, :float, :float,
                               :float, :float, :float, :float, :float, :float,
                               :float, :float, :float, :float, :float, :float], :void
      # 25: the stroke width, then the same 24 as R2D_DrawQuad.
      ffi_func :R2D_StrokeQuad, [:float,
                                 :float, :float, :float, :float, :float, :float,
                                 :float, :float, :float, :float, :float, :float,
                                 :float, :float, :float, :float, :float, :float,
                                 :float, :float, :float, :float, :float, :float], :void
      ffi_func :R2D_DrawCircle, [:float, :float, :float, :int,
                                 :float, :float, :float, :float], :void
      # 21: the endpoints and stroke width, then four corner colors.
      ffi_func :R2D_DrawLine, [:float, :float, :float, :float, :float,
                               :float, :float, :float, :float,
                               :float, :float, :float, :float,
                               :float, :float, :float, :float,
                               :float, :float, :float, :float], :void
      # 23: the same with the dash and gap lengths after the stroke width.
      ffi_func :R2D_DrawDashedLine, [:float, :float, :float, :float, :float, :float, :float,
                                     :float, :float, :float, :float,
                                     :float, :float, :float, :float,
                                     :float, :float, :float, :float,
                                     :float, :float, :float, :float], :void
      # Text is an opaque handle: created once, re-rasterized on every
      # content/size/style/font change, measured back, and drawn each frame.
      ffi_func :R2D_TextNew, [], :ptr
      ffi_func :R2D_TextUpdate, [:ptr, :str, :str, :int, :int], :bool
      ffi_func :R2D_TextWidth, [:ptr], :int
      ffi_func :R2D_TextHeight, [:ptr], :int
      ffi_func :R2D_TextStale, [:ptr], :bool
      ffi_func :R2D_TextDraw, [:ptr, :float, :float, :float, :float, :float,
                               :float, :float, :float, :float, :str], :bool
      # An image is an opaque handle loaded once from its path (the display size
      # steers the SVG rasterizer), measured back, and drawn each frame with its
      # geometry, tint, flip and scale mode passed in.
      ffi_func :R2D_ImageNew, [:str, :int, :int], :ptr
      ffi_func :R2D_ImageWidth, [:ptr], :int
      ffi_func :R2D_ImageHeight, [:ptr], :int
      ffi_func :R2D_ImageDraw, [:ptr, :float, :float, :float, :float, :float, :float, :float,
                                :float, :float, :float, :float, :int, :str], :bool
      ffi_func :R2D_ImageResize, [:ptr, :str, :int, :int, :str], :bool
      # A canvas is an opaque handle; packed payloads cross as a Float array
      # with their length, in the layouts `canvas.c` documents per binding.
      ffi_func :R2D_CanvasNew, [:int, :int, :bool, :float, :float, :float, :float], :ptr
      ffi_func :R2D_CanvasDrawNamed, [:ptr, :float, :float, :float, :float, :float,
                                      :float, :float, :float, :float, :float, :float, :str], :bool
      ffi_func :R2D_CanvasClear, [:ptr, :float_array, :int], :bool
      ffi_func :R2D_CanvasFillTriangle, [:ptr, :double, :double, :double, :double, :double, :double,
                                         :double, :double, :double, :double], :bool
      ffi_func :R2D_CanvasFillTriangleLerp, [:ptr, :float_array, :int], :bool
      ffi_func :R2D_CanvasFillRectangle, [:ptr, :double, :double, :double, :double,
                                          :double, :double, :double, :double], :bool
      ffi_func :R2D_CanvasFillRectangles, [:ptr, :float_array, :int], :bool
      ffi_func :R2D_CanvasFillPixelGrid, [:ptr, :float_array, :int, :float_array, :int], :bool
      ffi_func :R2D_CanvasFillEllipse, [:ptr, :double, :double, :double, :double,
                                        :double, :double, :double, :double], :bool
      ffi_func :R2D_CanvasFillPolygon, [:ptr, :float_array, :int], :bool
      ffi_func :R2D_CanvasFillPolygonLerp, [:ptr, :float_array, :int], :bool
      ffi_func :R2D_CanvasDrawLine, [:ptr, :double, :double, :double, :double, :double,
                                     :double, :double, :double, :double, :double, :double], :bool
      ffi_func :R2D_CanvasDrawLineLerp, [:ptr, :float_array, :int], :bool
      ffi_func :R2D_CanvasDrawLines, [:ptr, :float_array, :int], :bool
      ffi_func :R2D_CanvasStrokePolygon, [:ptr, :float_array, :int], :bool
      ffi_func :R2D_CanvasStrokePolyline, [:ptr, :float_array, :int], :bool
      ffi_func :R2D_CanvasDrawImageNamed, [:ptr, :ptr, :double, :double, :double, :double, :str], :bool
      ffi_func :R2D_CanvasDrawTextNamed, [:ptr, :ptr, :double, :double, :double, :double,
                                          :double, :double, :double, :double, :str], :bool
      # 18: three vertices of x, y, r, g, b, a.
      ffi_func :R2D_DrawTriangle, [:float, :float, :float, :float, :float, :float, :float, :float, :float, :float, :float, :float, :float, :float, :float, :float, :float, :float], :void
      # A stroked path: n (x, y) pairs, closed flag, width, n (r, g, b, a) quads
      # and their count.
      ffi_func :R2D_StrokePathD, [:float_array, :int, :int, :double, :float_array, :int], :void
      # No `R2D_StrokeCircle` exists — `ext.c` strokes a circle as an
      # axis-aligned ellipse with equal radii, and so does `stroke_circle` below.
      ffi_func :R2D_StrokeEllipse, [:float, :float, :float, :float, :float,
                                    :int, :float,
                                    :float, :float, :float, :float], :void

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
                                win.scale_mode.to_s, win.icon || '')
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
                         Ext.R2D_PollClosed(),
                         Ext.R2D_FrameCount(), Ext.R2D_Fps())
        nil
      end

      # The other engines return the queue as one flat array built in C. FFI
      # cannot return an array, so this rebuilds the same array — R2D_EVT_STRIDE
      # values per event, a key event's id as its name symbol — from scalar
      # reads, and `Window#dispatch_events` consumes it unchanged. `nil` on an
      # empty queue keeps `tick` skipping dispatch on the common frame.
      def self.drain_events(_win)
        n = Ext.R2D_EventCount()
        return nil if n == 0

        raw = []
        i = 0
        while i < n
          cat = Ext.R2D_EventInt(i, 0)
          raw << cat << Ext.R2D_EventInt(i, 1)
          raw << (cat == Window::EVT_KEY ? Ext.R2D_EventKeyName(i).to_sym : Ext.R2D_EventInt(i, 2))
          raw << Ext.R2D_EventInt(i, 3) << Ext.R2D_EventInt(i, 4) << Ext.R2D_EventInt(i, 5)
          raw << Ext.R2D_EventInt(i, 6) << Ext.R2D_EventInt(i, 7)
          raw << Ext.R2D_EventDelta(i, 0) << Ext.R2D_EventDelta(i, 1)
          raw << Ext.R2D_EventInt(i, 8)
          str = Ext.R2D_EventStr(i)
          raw << (str.empty? ? nil : str)
          i += 1
        end
        Ext.R2D_EventsClear()
        raw
      end

      # Every key name the C table holds, as the Ruby bridge's `key_names`
      # returns them: `:unknown` first, then each named scancode in order.
      def self.key_names
        names = [:unknown]
        code = 0
        while code < 512
          name = Ext.R2D_KeyName(code)
          names << name.to_sym unless name == 'unknown'
          code += 1
        end
        names
      end

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

      # `.to_f` is not decoration: a shape built with integer literals
      # (`Square.new(x: 160, size: 80)`) hands Integers to `:float` parameters,
      # and the window renders blank with no error.
      def self.draw_quad_uniform(x1, y1, x2, y2, x3, y3, x4, y4, r, g, b, a)
        Ext.R2D_DrawQuad(x1.to_f, y1.to_f, r.to_f, g.to_f, b.to_f, a.to_f,
                         x2.to_f, y2.to_f, r.to_f, g.to_f, b.to_f, a.to_f,
                         x3.to_f, y3.to_f, r.to_f, g.to_f, b.to_f, a.to_f,
                         x4.to_f, y4.to_f, r.to_f, g.to_f, b.to_f, a.to_f)
      end

      # Interleaved, one vertex at a time — the order `Quad#render` passes and
      # the order `R2D_DrawQuad` takes. `stroke_quad` below groups the
      # coordinates instead, because that is how `lib/` calls *it*; the two
      # differ, and matching each to its caller is the whole job here.
      def self.draw_quad(x1, y1, r1, g1, b1, a1,
                         x2, y2, r2, g2, b2, a2,
                         x3, y3, r3, g3, b3, a3,
                         x4, y4, r4, g4, b4, a4)
        Ext.R2D_DrawQuad(x1.to_f, y1.to_f, r1.to_f, g1.to_f, b1.to_f, a1.to_f,
                         x2.to_f, y2.to_f, r2.to_f, g2.to_f, b2.to_f, a2.to_f,
                         x3.to_f, y3.to_f, r3.to_f, g3.to_f, b3.to_f, a3.to_f,
                         x4.to_f, y4.to_f, r4.to_f, g4.to_f, b4.to_f, a4.to_f)
      end

      # Quad, Rectangle and Square are the whole of this slice's stroking, and
      # all three are closed four-vertex paths, so `R2D_StrokeQuad` covers it.
      def self.stroke_quad_uniform(x1, y1, x2, y2, x3, y3, x4, y4, sw, r, g, b, a)
        Ext.R2D_StrokeQuad(sw.to_f,
                           x1.to_f, y1.to_f, r.to_f, g.to_f, b.to_f, a.to_f,
                           x2.to_f, y2.to_f, r.to_f, g.to_f, b.to_f, a.to_f,
                           x3.to_f, y3.to_f, r.to_f, g.to_f, b.to_f, a.to_f,
                           x4.to_f, y4.to_f, r.to_f, g.to_f, b.to_f, a.to_f)
      end

      def self.stroke_quad(x1, y1, x2, y2, x3, y3, x4, y4, sw,
                           r1, g1, b1, a1, r2, g2, b2, a2,
                           r3, g3, b3, a3, r4, g4, b4, a4)
        Ext.R2D_StrokeQuad(sw.to_f,
                           x1.to_f, y1.to_f, r1.to_f, g1.to_f, b1.to_f, a1.to_f,
                           x2.to_f, y2.to_f, r2.to_f, g2.to_f, b2.to_f, a2.to_f,
                           x3.to_f, y3.to_f, r3.to_f, g3.to_f, b3.to_f, a3.to_f,
                           x4.to_f, y4.to_f, r4.to_f, g4.to_f, b4.to_f, a4.to_f)
      end

      # `sectors` gets `.to_i` for the same reason the coordinates get `.to_f`:
      # the FFI takes the declared type and nothing coerces on the way in.
      def self.draw_circle(x, y, radius, sectors, r, g, b, a)
        Ext.R2D_DrawCircle(x.to_f, y.to_f, radius.to_f, sectors.to_i,
                           r.to_f, g.to_f, b.to_f, a.to_f)
      end

      # Equal radii, no tilt — the circle case of the ellipse stroke.
      def self.stroke_circle(x, y, radius, sectors, sw, r, g, b, a)
        Ext.R2D_StrokeEllipse(x.to_f, y.to_f, radius.to_f, radius.to_f, 0.0,
                              sectors.to_i, sw.to_f,
                              r.to_f, g.to_f, b.to_f, a.to_f)
      end

      # Four corner colors in `R2D_DrawLine`'s order: start+perp, start-perp,
      # end-perp, end+perp. `line.rb` passes the start color twice then the end
      # color twice, so a gradient runs along the line.
      def self.draw_line(x1, y1, x2, y2, sw,
                         r1, g1, b1, a1, r2, g2, b2, a2,
                         r3, g3, b3, a3, r4, g4, b4, a4)
        Ext.R2D_DrawLine(x1.to_f, y1.to_f, x2.to_f, y2.to_f, sw.to_f,
                         r1.to_f, g1.to_f, b1.to_f, a1.to_f,
                         r2.to_f, g2.to_f, b2.to_f, a2.to_f,
                         r3.to_f, g3.to_f, b3.to_f, a3.to_f,
                         r4.to_f, g4.to_f, b4.to_f, a4.to_f)
      end

      # `text_create(text)` is a pass-self call on the other engines: C reads the
      # font, content, size and style off the object and writes the measured
      # size back. Here the Text carries the native handle in a ptr-typed ivar
      # (see `SPINEL_TEXT_SYNC`), the adapter passes the ivars in, and reads
      # the size out. Handles are never freed — Spinel has no finalizers — so
      # a program churning Text objects leaks them; rewrite `content=` instead.
      def self.text_create(text)
        handle = text._spinel_text
        if handle == nil
          handle = Ext.R2D_TextNew()
          raise Error, 'Ruby2D: failed to initialize' if handle == nil

          text._spinel_text = handle
        end
        _spinel_text_update(text, handle)
        true
      end

      def self._spinel_text_update(text, handle)
        ok = Ext.R2D_TextUpdate(handle, text.font, text.content, text.size.to_i,
                                text._spinel_style_flags)
        raise Error, "Failed to render text (font `#{text.font}`)" unless ok

        text._spinel_measure(Ext.R2D_TextWidth(handle), Ext.R2D_TextHeight(handle))
        nil
      end

      # Re-rasterize first when the asset scale moved since the last update
      # (a Text built before a HiDPI window opened), as the Ruby bridge does.
      def self.text_draw(text, rx, ry)
        handle = text._spinel_text
        return nil if handle == nil

        _spinel_text_update(text, handle) if Ext.R2D_TextStale(handle)
        c = text.color
        ok = Ext.R2D_TextDraw(handle, text.x.to_f, text.y.to_f, text.rotate.to_f,
                              rx.to_f, ry.to_f,
                              c.r.to_f, c.g.to_f, c.b.to_f, c.a.to_f,
                              text.scale_mode.to_s)
        raise Error, 'Failed to draw text' unless ok

        true
      end

      # `image_create(image)` is a pass-self call on the other engines: C reads
      # the path and any display size off the object, decodes the file, and
      # writes the decoded size and a reset clip back. Here the Image carries the
      # native handle in a ptr-typed ivar (see `SPINEL_TEXT_SYNC`) and the
      # adapter copies the size out. Handles are never freed.
      def self.image_create(image)
        w = image.width
        h = image.height
        handle = Ext.R2D_ImageNew(image.path, w.nil? ? 0 : w.to_i, h.nil? ? 0 : h.to_i)
        raise Error, "Failed to load image `#{image.path}`" if handle == nil

        image._spinel_image = handle
        image._spinel_size(Ext.R2D_ImageWidth(handle), Ext.R2D_ImageHeight(handle))
        image._spinel_loaded(Ext.R2D_ImageWidth(handle), Ext.R2D_ImageHeight(handle))
        true
      end

      def self.image_draw(image)
        handle = image._spinel_image
        return nil if handle == nil

        c = image.tint
        ok = Ext.R2D_ImageDraw(handle, image.x.to_f, image.y.to_f,
                               image.width.to_f, image.height.to_f, image.rotate.to_f,
                               image.rx.to_f, image.ry.to_f,
                               c.r.to_f, c.g.to_f, c.b.to_f, c.a.to_f,
                               image._spinel_flip, image.scale_mode.to_s)
        raise Error, 'Failed to draw image' unless ok

        true
      end

      def self.image_resize(image, width, height)
        handle = image._spinel_image
        return nil if handle == nil

        ok = Ext.R2D_ImageResize(handle, image.path, width.to_i, height.to_i, image.scale_mode.to_s)
        raise Error, 'Image#resize! failed' unless ok

        image._spinel_loaded(Ext.R2D_ImageWidth(handle), Ext.R2D_ImageHeight(handle))
        true
      end

      # Canvas: the same handle pattern as Text (see `SPINEL_TEXT_SYNC`). Each
      # packed payload is floated first — `:float_array` hands C the storage of
      # an `Array<Float>`, and `lib/` packs counts and coordinates as Integers.
      def self.canvas_create(canvas, logical)
        handle = Ext.R2D_CanvasNew(canvas.width.to_i, canvas.height.to_i, logical ? true : false,
                                   canvas._spinel_fill_r.to_f, canvas._spinel_fill_g.to_f,
                                   canvas._spinel_fill_b.to_f, canvas._spinel_fill_a.to_f)
        raise Error, 'Ruby2D: failed to create canvas' if handle == nil

        canvas._spinel_canvas = handle
        true
      end

      def self.canvas_draw(canvas, rx, ry)
        t = canvas.tint
        ok = Ext.R2D_CanvasDrawNamed(canvas._spinel_canvas,
                                     canvas.x.to_f, canvas.y.to_f, canvas.width.to_f, canvas.height.to_f,
                                     canvas.rotate.to_f, rx.to_f, ry.to_f,
                                     t.r.to_f, t.g.to_f, t.b.to_f, t.a.to_f,
                                     canvas.scale_mode.to_s)
        raise Error, 'Failed to draw canvas' unless ok

        true
      end

      def self._spinel_floats(values)
        out = []
        values.each { |v| out << v.to_f }
        out
      end

      def self._spinel_canvas_ok(ok, what)
        raise Error, "Canvas##{what} failed" unless ok

        true
      end

      def self.canvas_clear(canvas, a)
        f = _spinel_floats(a)
        _spinel_canvas_ok(Ext.R2D_CanvasClear(canvas._spinel_canvas, f, f.size), 'clear')
      end

      def self.canvas_fill_triangle(canvas, x1, y1, x2, y2, x3, y3, r, g, b, a)
        _spinel_canvas_ok(Ext.R2D_CanvasFillTriangle(canvas._spinel_canvas,
                                                     x1.to_f, y1.to_f, x2.to_f, y2.to_f, x3.to_f, y3.to_f,
                                                     r.to_f, g.to_f, b.to_f, a.to_f), 'fill_triangle')
      end

      def self.canvas_fill_triangle_lerp(canvas, a)
        f = _spinel_floats(a)
        _spinel_canvas_ok(Ext.R2D_CanvasFillTriangleLerp(canvas._spinel_canvas, f, f.size), 'fill_triangle')
      end

      def self.canvas_fill_rectangle(canvas, x, y, w, h, r, g, b, a)
        _spinel_canvas_ok(Ext.R2D_CanvasFillRectangle(canvas._spinel_canvas,
                                                      x.to_f, y.to_f, w.to_f, h.to_f,
                                                      r.to_f, g.to_f, b.to_f, a.to_f), 'fill_rectangle')
      end

      def self.canvas_fill_rectangles(canvas, a)
        f = _spinel_floats(a)
        _spinel_canvas_ok(Ext.R2D_CanvasFillRectangles(canvas._spinel_canvas, f, f.size), 'fill_rectangles')
      end

      def self.canvas_fill_pixel_grid(canvas, header, colors)
        h = _spinel_floats(header)
        c = _spinel_floats(colors)
        _spinel_canvas_ok(Ext.R2D_CanvasFillPixelGrid(canvas._spinel_canvas, h, h.size, c, c.size), 'fill_pixel_grid')
      end

      def self.canvas_fill_ellipse(canvas, x, y, xr, yr, r, g, b, a)
        _spinel_canvas_ok(Ext.R2D_CanvasFillEllipse(canvas._spinel_canvas,
                                                    x.to_f, y.to_f, xr.to_f, yr.to_f,
                                                    r.to_f, g.to_f, b.to_f, a.to_f), 'fill_ellipse')
      end

      def self.canvas_fill_polygon(canvas, a)
        f = _spinel_floats(a)
        _spinel_canvas_ok(Ext.R2D_CanvasFillPolygon(canvas._spinel_canvas, f, f.size), 'fill_polygon')
      end

      def self.canvas_fill_polygon_lerp(canvas, a)
        f = _spinel_floats(a)
        _spinel_canvas_ok(Ext.R2D_CanvasFillPolygonLerp(canvas._spinel_canvas, f, f.size), 'fill_polygon')
      end

      def self.canvas_draw_line(canvas, x1, y1, x2, y2, sw, r, g, b, a, dash, gap)
        _spinel_canvas_ok(Ext.R2D_CanvasDrawLine(canvas._spinel_canvas,
                                                 x1.to_f, y1.to_f, x2.to_f, y2.to_f, sw.to_f,
                                                 r.to_f, g.to_f, b.to_f, a.to_f,
                                                 dash.to_f, gap.to_f), 'draw_line')
      end

      def self.canvas_draw_line_lerp(canvas, a)
        f = _spinel_floats(a)
        _spinel_canvas_ok(Ext.R2D_CanvasDrawLineLerp(canvas._spinel_canvas, f, f.size), 'draw_line')
      end

      def self.canvas_draw_lines(canvas, a)
        f = _spinel_floats(a)
        _spinel_canvas_ok(Ext.R2D_CanvasDrawLines(canvas._spinel_canvas, f, f.size), 'draw_lines')
      end

      def self.canvas_stroke_polygon(canvas, a)
        f = _spinel_floats(a)
        _spinel_canvas_ok(Ext.R2D_CanvasStrokePolygon(canvas._spinel_canvas, f, f.size), 'stroke')
      end

      def self.canvas_stroke_polyline(canvas, a)
        f = _spinel_floats(a)
        _spinel_canvas_ok(Ext.R2D_CanvasStrokePolyline(canvas._spinel_canvas, f, f.size), 'draw_polyline')
      end

      # `a` is [x, y, w, h, r, g, b, a]; the Text's surface is its handle's.
      def self.canvas_draw_text(canvas, text, a)
        handle = text._spinel_text
        raise Error, 'Canvas#draw_text requires a Text that has been created' if handle == nil

        _spinel_canvas_ok(Ext.R2D_CanvasDrawTextNamed(canvas._spinel_canvas, handle,
                                                      a[0].to_f, a[1].to_f, a[2].to_f, a[3].to_f,
                                                      a[4].to_f, a[5].to_f, a[6].to_f, a[7].to_f,
                                                      text.scale_mode.to_s), 'draw_text')
      end

      # `a` is [x, y, w, h]; the Image's surface is its handle's.
      def self.canvas_draw_image(canvas, image, a)
        handle = image._spinel_image
        raise Error, 'Canvas#draw_image requires an Image that has been created' if handle == nil

        _spinel_canvas_ok(Ext.R2D_CanvasDrawImageNamed(canvas._spinel_canvas, handle,
                                                       a[0].to_f, a[1].to_f, a[2].to_f, a[3].to_f,
                                                       image.scale_mode.to_s), 'draw_image')
      end

      def self.draw_triangle(x1, y1, r1, g1, b1, a1,
                             x2, y2, r2, g2, b2, a2,
                             x3, y3, r3, g3, b3, a3)
        Ext.R2D_DrawTriangle(x1.to_f, y1.to_f, r1.to_f, g1.to_f, b1.to_f, a1.to_f,
                             x2.to_f, y2.to_f, r2.to_f, g2.to_f, b2.to_f, a2.to_f,
                             x3.to_f, y3.to_f, r3.to_f, g3.to_f, b3.to_f, a3.to_f)
        nil
      end

      def self.draw_triangle_uniform(x1, y1, x2, y2, x3, y3, r, g, b, a)
        Ext.R2D_DrawTriangle(x1.to_f, y1.to_f, r.to_f, g.to_f, b.to_f, a.to_f,
                             x2.to_f, y2.to_f, r.to_f, g.to_f, b.to_f, a.to_f,
                             x3.to_f, y3.to_f, r.to_f, g.to_f, b.to_f, a.to_f)
        nil
      end

      def self.stroke_triangle(x1, y1, x2, y2, x3, y3, sw,
                               r1, g1, b1, a1, r2, g2, b2, a2, r3, g3, b3, a3)
        pts = [x1.to_f, y1.to_f, x2.to_f, y2.to_f, x3.to_f, y3.to_f]
        cols = [r1.to_f, g1.to_f, b1.to_f, a1.to_f, r2.to_f, g2.to_f, b2.to_f, a2.to_f,
                r3.to_f, g3.to_f, b3.to_f, a3.to_f]
        Ext.R2D_StrokePathD(pts, 3, 1, sw.to_f, cols, 12)
        nil
      end

      def self.stroke_triangle_uniform(x1, y1, x2, y2, x3, y3, sw, r, g, b, a)
        stroke_triangle(x1, y1, x2, y2, x3, y3, sw, r, g, b, a, r, g, b, a, r, g, b, a)
      end

      # `coords` is n (x, y) pairs and `colors` n (r, g, b, a) quads, as `lib/`
      # packs them; both are floated for the `:float_array` crossing.
      def self.stroke_path(coords, sw, colors, closed)
        pts = _spinel_floats(coords)
        cols = _spinel_floats(colors)
        Ext.R2D_StrokePathD(pts, pts.size / 2, closed ? 1 : 0, sw.to_f, cols, cols.size)
        nil
      end

      def self.draw_dashed_line(x1, y1, x2, y2, sw, dash, gap,
                                r1, g1, b1, a1, r2, g2, b2, a2,
                                r3, g3, b3, a3, r4, g4, b4, a4)
        Ext.R2D_DrawDashedLine(x1.to_f, y1.to_f, x2.to_f, y2.to_f,
                               sw.to_f, dash.to_f, gap.to_f,
                               r1.to_f, g1.to_f, b1.to_f, a1.to_f,
                               r2.to_f, g2.to_f, b2.to_f, a2.to_f,
                               r3.to_f, g3.to_f, b3.to_f, a3.to_f,
                               r4.to_f, g4.to_f, b4.to_f, a4.to_f)
      end
    end
  end
RUBY

# `poll_events` writes the polled window state back through this rather than six
# attr_writers, keeping the flattened-state seam in one named place.
SPINEL_WINDOW_SYNC = <<~'RUBY'
  module Ruby2D
    class Window
      # `frames` and `fps` are the two the other engines write straight into the
      # Ruby object from C (`window.c`, in the poll path). Nothing reads them
      # back out over there, so they come through here like the rest.
      def _spinel_sync(mx, my, w, h, vw, vh, closed, frames, fps)
        @mouse_x = mx
        @mouse_y = my
        @width = w
        @height = h
        @viewport_width = vw
        @viewport_height = vh
        @close = true if closed
        @frames = frames
        @fps = fps
        nil
      end
    end
  end
RUBY

# The Text side of the `text_create` / `text_draw` seam: where the native handle
# lives, and how the measured size gets back onto the object. Reopened here,
# like `Window#_spinel_sync`, rather than in `text.rb` — these exist for one
# target. `@_spinel_text` holds a `:ptr`, which Spinel allows in a typed ivar
# but not in a Hash or Array.
SPINEL_TEXT_SYNC = <<~'RUBY'
  module Ruby2D
    class Text
      attr_accessor :_spinel_text

      def _spinel_style_flags = @style_flags

      def _spinel_measure(w, h)
        @width = w
        @height = h
        nil
      end
    end

    class Canvas
      attr_accessor :_spinel_canvas

      def _spinel_fill_r = @fill_r
      def _spinel_fill_g = @fill_g
      def _spinel_fill_b = @fill_b
      def _spinel_fill_a = @fill_a
    end

    class Image
      attr_accessor :_spinel_image

      # Image has no `@flip`; Sprite will, in SDL_FlipMode's bits.
      def _spinel_flip = 0

      def _spinel_size(w, h)
        @width = w
        @height = h
        nil
      end

      # What a (re)load writes back: the decoded size, with the clip reset to
      # cover all of it.
      def _spinel_loaded(w, h)
        @orig_width = w
        @orig_height = h
        @clipped = false
        @clip_x = 0.0
        @clip_y = 0.0
        @clip_width = w
        @clip_height = h
        @source_width = w
        @source_height = h
        @trim_x = 0
        @trim_y = 0
        nil
      end
    end
  end
RUBY

# What an inert `Ext` stub returns when the default `nil` would break the caller.
SPINEL_EXT_STUB_RETURNS = {
  'window_cursor_visible' => 'true',
  # A key vocabulary wide enough for a fixture to register and fire key events
  'key_names' => '%i[unknown a b r space escape left right]',
  'render' => 'nil', 'now' => '0.016', 'begin_frame' => 'true',
  'window_show' => 'true', 'window_create' => 'true'
}.freeze

def spinel_lib(name, lib_dir) = File.read(File.join(lib_dir, "#{name}.rb"))

# Assemble the library slice, the `Ext` adapter, and the app into the single
# file Spinel compiles. `ffi: false` swaps the adapter for stubs, which exercises
# `lib/` alone with no C and no FFI — that is what the subset check builds.
def spinel_assemble(app_source, lib_dir:, ffi: true)
  src = SPINEL_LIB_FILES.map { |f| "#{spinel_lib(f, lib_dir)}\n\n" }.join
  src = spinel_compat(src)

  ext = ffi ? SPINEL_EXT : ''
  src << ext

  # Everything the slice references that the adapter doesn't cover has to exist —
  # Spinel compiles the whole reachable graph, so a missing method is a compile
  # error even on a path that never runs — but it can do nothing.
  covered = ext.scan(/def self\.([a-z_0-9]+)/).flatten
  stubbed = SPINEL_LIB_FILES.flat_map { |f| spinel_lib(f, lib_dir).scan(/Ext\.([a-z_0-9]+)/) }
                            .flatten.uniq.sort - covered
  src << "module Ruby2D\n  module Ext\n"
  src << stubbed.map { |m| "    def self.#{m}(*args)\n      #{SPINEL_EXT_STUB_RETURNS.fetch(m, 'nil')}\n    end\n" }.join("\n")
  src << "  end\nend\n\n"

  src << SPINEL_WINDOW_SYNC << "\n"
  src << SPINEL_TEXT_SYNC << "\n"
  src << "include Ruby2D\n"
  src << spinel_dsl_shims(spinel_lib('dsl', lib_dir))
  src << "\n" << app_source

  src
end


# Preflight ####################################################################

# Ruby 2D features the Spinel target doesn't support yet, as patterns matched
# against the app's source. Each entry names what the user wrote and what it
# needs, so the error can say why rather than just "unsupported".
#
# The class list is derived from the two file lists rather than written out, so
# widening SPINEL_LIB_FILES can't leave a stale rejection behind. Files that
# define no user-facing class map to nil.
SPINEL_EXCLUDED_CLASSES = {
  'audio' => 'Audio',
  'ellipse' => 'Ellipse',
  'json_parser' => nil, 'atlas_parser' => nil, 'sprite_sheet' => 'SpriteSheet',
  'polygon' => 'Polygon',
  'sprite' => 'Sprite', 'bitmap_text' => 'BitmapText',
  'tileset' => 'Tileset'
}.freeze

# The classes to reject, with the reason. Fails loudly if a file was added to
# `lib/` without deciding which side of the line it falls on — the same
# drift-detection the compatibility transforms use.
def spinel_unsupported_classes
  excluded = Ruby2D::CLI::LIB_FILES - SPINEL_LIB_FILES
  unknown = excluded - SPINEL_EXCLUDED_CLASSES.keys
  unless unknown.empty?
    raise SpinelCompatDrift,
          "Spinel preflight doesn't know about #{unknown.join(', ')} — add them to " \
          'SPINEL_EXCLUDED_CLASSES or SPINEL_LIB_FILES. See spinel/README.md.'
  end

  excluded.filter_map { |f| SPINEL_EXCLUDED_CLASSES[f] }
end

# Report every unsupported feature the app uses, as `[line number, what, why]`.
# Comment lines are skipped; string contents are not, so a class name inside a
# string reads as a use. That errs toward a false rejection with a clear
# message, which is the safer way to be wrong here.
def spinel_unsupported_uses(source)
  classes = spinel_unsupported_classes
  found = []

  source.lines.each_with_index do |line, i|
    next if line.match?(/\A\s*#/)

    n = i + 1
    classes.each do |name|
      # No `:` in the lookbehind — `Ruby2D::Image` is a use, `MyImage` isn't.
      found << [n, name, 'shapes and media beyond Square, Rectangle, and Quad'] if line.match?(/(?<![\w.])#{name}\b/)
    end
    found << [n, 'Window subclass', 'the class pattern — it needs ancestor reflection'] if line.match?(/class\s+\w+\s*<\s*(Ruby2D::)?Window\b/)
  end

  found
end

# Stop before compiling if the app uses something this target can't build. The
# alternative is a wall of generated-C errors naming Spinel internals, which
# says nothing about the line the user wrote.
def spinel_preflight!(source, path)
  uses = spinel_unsupported_uses(source)
  return if uses.empty?

  error "#{path} uses features the Spinel target doesn't support yet.", spaced: true
  puts
  # Pad before styling — the color escapes would otherwise count toward the width.
  line_width = uses.map { |n, _, _| n.to_s.length }.max
  what_width = uses.map { |_, what, _| what.length }.max
  uses.each do |n, what, why|
    puts "    #{"line #{n.to_s.rjust(line_width)}".dim}  #{what.bold}#{' ' * (what_width - what.length)}  #{why.dim}"
  end
  puts "\n  The Spinel build is experimental and draws shapes only. Build with"
  puts "  #{'ruby2d build --native'.bold} (mruby) for the full library.\n\n"
  exit 1
end


# Toolchain ####################################################################

# Find the `spinel` compiler: an explicit `RUBY2D_SPINEL` override first (the
# development path — Spinel moves fast, so a local checkout stays out of the
# tree), then a `ruby2d setup --spinel` cache build, then $PATH. Mirrors
# `find_mrbc` in cli/build.rb.
def find_spinel
  override = ENV['RUBY2D_SPINEL']
  unless override.nil? || override.empty?
    return override if File.file?(override) && File.executable?(override)

    error "RUBY2D_SPINEL is set to `#{override}`, which isn't an executable file."
    exit 1
  end

  cache = spinel_cache_bin
  return cache if File.exist?(cache)

  find_executable('spinel')
end


# Where `ruby2d setup --spinel` builds the compiler. Spinel is used from its
# checkout, not installed out of it: it resolves its runtime archive and its C
# sources relative to its own `bin/`, so a binary copied somewhere else fails at
# link time with a missing `libspinel_rt.a`.
def spinel_cache_dir(root = AssetsTarget.cache_root)
  File.join(AssetsTarget.sources_dir(root: root), 'spinel')
end

def spinel_cache_bin(root = AssetsTarget.cache_root)
  File.join(spinel_cache_dir(root), 'bin', 'spinel')
end


# The commit of the checkout a `spinel` binary was built from, short, or nil if
# it isn't in one. Spinel ships many changes a day, so this is the first thing
# to know when a build starts behaving differently than it did yesterday.
#
# Read from the checkout rather than recorded at install time, so it stays
# right for a `RUBY2D_SPINEL` pointing at a tree someone rebuilds themselves.
def spinel_commit(spinel)
  root = File.expand_path('..', File.dirname(spinel))
  return nil unless Dir.exist?(File.join(root, '.git'))

  commit = IO.popen(['git', '-C', root, 'rev-parse', '--short=8', 'HEAD'],
                    err: File::NULL, &:read).to_s.strip
  commit.empty? ? nil : commit
rescue StandardError
  nil
end


# Build ########################################################################

# The static archives this target links, and the compiler flags that go with
# them. mruby is deliberately absent — a Spinel build has no mruby in it.
def spinel_link_libs
  libs = %w[SDL3_image SDL3_mixer SDL3_ttf SDL3]
  if (platform_dir = deps_platform_dir)
    [libs.map { |name| File.join(platform_dir, 'lib', "lib#{name}.a") }, native_platform_flags]
  else
    # No static libraries for this target: link the system's, the same fallback
    # the mruby native build uses.
    [[], libs.map { |name| "-l#{name}" }.join(' ') + " #{native_platform_flags}"]
  end
end


# Compile the `RUBY2D_NO_RUBY` core — the `R2D_*` renderer with the binding
# layer compiled out — and archive it for Spinel to link against.
def spinel_build_core(cc)
  dir = "#{BUILD_DIR}/spinel"
  FileUtils.mkdir_p dir
  archive = "#{dir}/libruby2d_core.a"
  ext_dir = "#{Ruby2D.gem_dir}/ext/ruby2d"

  objects = SPINEL_CORE_FILES.map do |name|
    object = "#{dir}/#{name}.o"
    run_cmd "#{shell_escape(cc)} -c -O2 -DRUBY2D_NO_RUBY " \
            "-I#{shell_escape(ext_dir)} -I#{shell_escape(deps_include_dir)} " \
            "#{shell_escape("#{ext_dir}/#{name}.c")} -o #{shell_escape(object)}"
    unless $?.success?
      error "Failed to compile the Ruby 2D core (#{name}.c)."
      exit 1
    end
    object
  end

  run_cmd "ar rcs #{shell_escape(archive)} #{objects.map { |o| shell_escape(o) }.join(' ')}"
  unless $?.success?
    error 'Failed to archive the Ruby 2D core.'
    exit 1
  end

  archive
end


# Build a native executable with Spinel instead of mruby. Whole-program AOT: the
# library slice, the FFI adapter, and the app become one Ruby file, which Spinel
# compiles to C and hands to the same C compiler the mruby path uses.
def build_spinel(ruby2d_app)
  unless File.exist?(ruby2d_app)
    error "Can't find file: #{ruby2d_app}"
    exit 1
  end

  # Before the toolchain: an app this target can't build shouldn't need a
  # compiler present to be told so.
  app_source = strip_require(ruby2d_app)
  spinel_preflight!(app_source, ruby2d_app)

  @asset_dirs = ([@assets_dir] + asset_directives(ruby2d_app)).compact.uniq
  @asset_dirs.each { |dir| check_asset_dir(dir) }

  spinel = find_spinel
  unless spinel
    error "Can't find `spinel`, the Ruby AOT compiler."
    puts "Run #{'ruby2d setup --spinel'.bold} to build it, or set #{'RUBY2D_SPINEL'.bold} to your own checkout."
    exit 1
  end

  cc = ENV['CC'] || 'cc'
  if find_executable(cc).nil?
    error "Can't find `#{cc}`, a C compiler. Install a C toolchain (e.g. Xcode Command Line Tools or build-essential) or set $CC."
    exit 1
  end

  refuse_if_foreign_build_dir
  FileUtils.rm_rf Dir.glob("#{BUILD_DIR}/*")
  FileUtils.mkdir_p BUILD_DIR
  FileUtils.touch BUILD_MARKER

  step "Assembling #{ruby2d_app}" if @debug
  source = spinel_assemble(app_source, lib_dir: "#{Ruby2D.gem_dir}/lib/ruby2d")
  File.write("#{BUILD_DIR}/app.rb", source)
  wrote "#{BUILD_DIR}/app.rb" if @debug

  step 'Building native with Spinel'
  puts "    #{"for #{native_target}".dim}"
  commit = spinel_commit(spinel)
  puts "    #{"spinel #{commit}".dim}" if commit

  archives, link_flags = spinel_link_libs
  archives = [spinel_build_core(cc)] + archives

  # The C is generated, so its warnings are about Spinel and not about anything
  # the user wrote or can fix — a wall of them on an ordinary build is noise.
  # `--debug` shows them, and they are worth reading there: every silent
  # mistyping bug filed so far announced itself as an incompatible-pointer
  # warning first.
  #
  # Errors are the opposite, and always uncapped: clang stops reporting after 20,
  # which makes a real count read as a plateau. gcc has no such flag.
  c_flags = @debug ? '' : '-w'
  c_flags += ' -ferror-limit=0' if spinel_clang?(cc)

  FileUtils.mkdir_p "#{BUILD_DIR}/native"
  run_cmd "#{shell_escape(spinel)} #{BUILD_DIR}/app.rb " \
          "--cc=#{shell_escape("#{cc} #{c_flags} #{link_flags}".squeeze(' ').strip)} " \
          "#{archives.map { |a| "--link #{shell_escape(a)}" }.join(' ')} " \
          "-o #{BUILD_DIR}/native/app"

  unless $?.success?
    error 'Spinel build failed.', spaced: true
    puts '  The Spinel target is experimental. If the errors above name generated C'
    puts "  rather than your source, that's a compiler bug worth reporting — see"
    puts '  spinel/README.md for how these have been reduced and filed.'
    exit 1
  end

  # The default font and the declared asset directories ship next to the
  # executable as on the mruby target.
  bundle_default_font
  bundle_asset_dirs
  create_macos_bundle if AssetsTarget.host_os == 'macos'
  wrote "#{BUILD_DIR}/native/app"
  wrote "#{BUILD_DIR}/native/App.app" if AssetsTarget.host_os == 'macos'
  puts "    #{'Run `ruby2d launch --native` to view'.dim}"

  FileUtils.rm_rf "#{BUILD_DIR}/spinel" unless @debug
  FileUtils.rm_f "#{BUILD_DIR}/app.rb" unless @debug
  puts
end


# Whether the C compiler is clang, which takes flags gcc doesn't.
def spinel_clang?(cc)
  `#{shell_escape(cc)} --version 2>&1`.include?('clang')
rescue StandardError
  false
end
