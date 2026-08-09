# Spinel build path — compile a Ruby 2D app ahead-of-time with Spinel instead
# of mruby. Opt in with `ruby2d build --spinel`; mruby remains the default.
#
# Everything in the "Compatibility" section below is a workaround for a current
# Spinel limitation, applied to the assembled source rather than to `lib/` so
# that the library stays idiomatic and each workaround can be deleted in one
# place when upstream fixes it. `SPINEL.md` pins every one to the Spinel commit
# it was needed at, with the probe to re-check it.
#
# Each transformation asserts that it matched. A `lib/` edit that invalidates
# one fails the build loudly instead of silently producing a source that no
# longer has the workaround applied.

require 'ruby2d/cli/colorize'
require 'ruby2d/cli/messages'
require_relative '../../../assets/target'


# Compatibility ################################################################

# Raised when a compatibility transformation no longer matches the library it
# rewrites — i.e. `lib/` changed and this file needs updating (or the
# workaround can be dropped because Spinel fixed it).
class SpinelCompatDrift < StandardError; end

# Apply `sub`, failing loudly if the pattern isn't found. `what` names the
# workaround so the error points at the right entry in SPINEL.md.
def spinel_sub(src, from, to, what)
  raise SpinelCompatDrift, "Spinel compat `#{what}` no longer matches lib/. See SPINEL.md." unless src.include?(from)

  src.sub(from, to)
end


# Spinel carries only plain `def` methods from a module body into the including
# class: `attr_reader`, `attr_accessor`, `alias_method`, and `alias` declared in
# a module don't reach it. `Renderable` is included by every shape, so its
# attributes have to be written out. The same declarations in a *class* body are
# fine, which is why only these are rewritten.
def spinel_expand_renderable(src)
  readers   = %w[x y z width height color x_align y_align]
  accessors = %w[visible padding_top padding_right padding_bottom padding_left]

  defs  = readers.map { |m| "    def #{m}\n      @#{m}\n    end\n" }
  defs += accessors.flat_map do |m|
    ["    def #{m}\n      @#{m}\n    end\n",
     "    def #{m}=(value)\n      @#{m} = value\n    end\n"]
  end

  src = spinel_sub(src,
                   "    attr_reader :x, :y, :z, :width, :height, :color, :x_align, :y_align\n" \
                   "    attr_accessor :visible,\n" \
                   "                  :padding_top, :padding_right, :padding_bottom, :padding_left\n",
                   defs.join,
                   'Renderable attributes')

  src = spinel_sub(src, "    alias_method :visible?, :visible\n",
                   "    def visible?\n      @visible\n    end\n", 'Renderable#visible?')

  spinel_sub(src, "    alias colour color\n",
             "    def colour\n      color\n    end\n", 'Renderable#colour')
end


# `alias_method` inside `class << self` doesn't produce a callable class method
# (`attr_reader` in the same position does work, so only the alias is rewritten).
def spinel_expand_window_singleton(src)
  spinel_sub(src, "      alias_method :shown?, :shown\n",
             "      def shown?\n        @shown\n      end\n", 'Window.shown?')
end


# `Window.<m>(object)` fails to resolve through `extend ClassMethods` (issue 6 in
# SPINEL.md — cause still unknown, seven reductions all passed in isolation).
# Each of these class methods is defined as exactly `DSL.window.<m>(object)`, so
# calling that directly is the same code with one delegation hop inlined.
#
# This is a partial workaround: it fixes the library's internal call sites, which
# is what shapes use (`add: true` auto-registers on construction). A user app
# calling `Window.add(obj)` directly still hits the bug.
def spinel_bypass_window_class_methods(src)
  rewritten = 0
  %w[add remove register_interactive unregister_interactive].each do |m|
    src = src.gsub(/\bWindow\.#{m}\(/) do
      rewritten += 1
      "DSL.window.#{m}("
    end
  end
  if rewritten.zero?
    raise SpinelCompatDrift, 'Spinel compat `Window class-method bypass` matched nothing. See SPINEL.md.'
  end

  src
end


# Top-level `include`/`extend` of a module with instance methods is miscompiled,
# so the mruby preamble's `extend Ruby2D::DSL` can't be used. Every DSL method is
# a self-contained delegation to `DSL.window`, so they lift to the top level
# verbatim. `include Ruby2D` is kept — it only brings in constants, which works.
def spinel_dsl_shims(dsl_source)
  body = dsl_source[/module DSL\n(.*)\n  end\n/m, 1] or
    raise SpinelCompatDrift, 'Spinel compat `DSL shims` could not find the DSL module body. See SPINEL.md.'

  # Instance methods only — `def self.window` and friends stay on the module and
  # are called by the shims.
  shims = body.scan(/^    def ([a-z_][\w]*[?=]?(?:\([^)]*\))?)\n(.*?)^    end$/m).reject do |sig, _|
    sig.start_with?('self.')
  end
  raise SpinelCompatDrift, 'Spinel compat `DSL shims` found no DSL methods. See SPINEL.md.' if shims.empty?

  shims.map do |sig, inner|
    "def #{sig}\n#{inner.gsub(/^      /, '  ').gsub('DSL.window', 'Ruby2D::DSL.window')}end\n"
  end.join("\n")
end


# Apply every compatibility transformation to the assembled library source.
def spinel_compat(src)
  src = spinel_expand_renderable(src)
  src = spinel_expand_window_singleton(src)
  spinel_bypass_window_class_methods(src)
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

  cache = File.join(cache_platform_dir, 'bin', 'spinel')
  return cache if File.exist?(cache) && cache_stamp_ok?(cache_platform_dir)

  find_executable('spinel')
end
