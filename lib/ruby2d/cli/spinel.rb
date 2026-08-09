# Spinel build path — compile a Ruby 2D app ahead-of-time with Spinel instead
# of mruby. Opt in with `ruby2d build --spinel`; mruby remains the default.
#
# Everything in the "Compatibility" section below is a workaround for a current
# Spinel limitation, applied to the assembled source rather than to `lib/` so
# that the library stays idiomatic and each workaround can be deleted in one
# place when upstream fixes it. `spinel/README.md` pins every one to the Spinel commit
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
# workaround so the error points at the right entry in spinel/README.md.
def spinel_sub(src, from, to, what)
  raise SpinelCompatDrift, "Spinel compat `#{what}` no longer matches lib/. See spinel/README.md." unless src.include?(from)

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


# `Window.<m>` fails to resolve when `m` reaches the class through
# `extend ClassMethods` (issue 6 in spinel/README.md — cause still unknown after ten
# reductions, every one of which passed in isolation).
#
# It is systemic rather than a fixed list of call sites: Spinel's whole-program
# inference only analyzes reachable code, so each newly-exercised path surfaces
# more of them. Rather than chase sites, rewrite by *method*: nearly every
# ClassMethods entry is exactly `DSL.window.<same name>(...)`, so calling that
# directly is the same code with one delegation hop inlined. The delegating
# methods are read out of `window/class_methods.rb` so the list cannot go stale.
#
# Methods that are not pure delegations (`shown?`, `render_ready_check`) are
# handled separately — see spinel_window_guards.
def spinel_bypass_window_class_methods(src, class_methods_source)
  # `def NAME(args)` whose entire body is `DSL.window.NAME(...)`.
  delegating = class_methods_source.scan(
    /^      def ([a-z_][\w]*[?!=]?)(?:\([^)]*\))?\n\s*DSL\.window\.\1[\s(]/
  ).flatten.uniq

  if delegating.empty?
    raise SpinelCompatDrift, 'Spinel compat `Window class-method bypass` found no delegating methods. See spinel/README.md.'
  end

  delegating.each do |m|
    # Method call or bare reference, but never a definition or a longer name.
    src = src.gsub(/\bWindow\.#{Regexp.escape(m)}\b(?!\s*=[^=])/, "DSL.window.#{m}")
  end

  src
end


# Two ClassMethods entries are not `DSL.window` delegations, so the bypass above
# cannot reach them, and both hit the same issue-6 resolution failure.
#
# `render_ready_check` is a self-contained guard: route it through a module
# function, which Spinel does resolve. `shown?` is called with an implicit
# receiver from inside the extended module, which Spinel cannot resolve either,
# so make that call explicit — `class << self` methods work by constant receiver.
def spinel_window_guards(src)
  src = spinel_sub(src, "        return if shown?\n", "        return if Window.shown?\n",
                   'render_ready_check implicit shown?')

  helper = +"module Ruby2D\n" \
            "  # See spinel_window_guards.\n" \
            "  def self.render_ready_check\n" \
            "    return if Window.shown?\n\n" \
            "    raise Error, 'Attempting to draw before the window is ready. " \
            "Please put calls to render() inside of a render block.'\n" \
            "  end\n" \
            "end\n\n"

  unless src.include?('Window.render_ready_check')
    raise SpinelCompatDrift, 'Spinel compat `render_ready_check` matched nothing. See spinel/README.md.'
  end

  src.gsub('Window.render_ready_check', 'Ruby2D.render_ready_check') + helper
end


# `Ruby2D.web?` is registered from C (`ruby2d.c`), so it disappears along with
# the binding layer under RUBY2D_NO_RUBY. The Spinel target is native.
def spinel_web_predicate
  "module Ruby2D\n  def self.web?\n    false\n  end\nend\n\n"
end


# Spinel rejects `return` in expression position, so the `x = expr or return`
# guard idiom has to become a statement. Rewritten rather than changed in `lib/`
# because the idiom is idiomatic Ruby and reads better than the expansion.
def spinel_expand_or_return(src)
  rewritten = 0
  src = src.gsub(/^(\s*)([a-z_][\w]*) = (.+?) or return( nil)?$/) do
    indent, name, expr = Regexp.last_match(1), Regexp.last_match(2), Regexp.last_match(3)
    rewritten += 1
    "#{indent}#{name} = #{expr}\n#{indent}return #{Regexp.last_match(4) ? 'nil' : ''}".rstrip +
      " if #{name}.nil?"
  end
  if rewritten.zero?
    raise SpinelCompatDrift, 'Spinel compat `or return` matched nothing. See spinel/README.md.'
  end

  src
end


# Whether `expr` has a comma outside any bracket or quote — i.e. whether it is
# a list rather than a single expression. Deliberately a scanner and not a
# regex: `f(a, b)` and `@x, @y` are indistinguishable without tracking depth.
def spinel_top_level_comma?(expr)
  depth = 0
  quote = nil
  chars = expr.chars
  chars.each_with_index do |c, i|
    escaped = i.positive? && chars[i - 1] == '\\'
    if quote
      quote = nil if c == quote && !escaped
    elsif ['"', "'"].include?(c)
      quote = c
    elsif ['(', '[', '{'].include?(c)
      depth += 1
    elsif [')', ']', '}'].include?(c)
      depth -= 1
    elsif c == ',' && depth.zero?
      return true
    end
  end
  false
end


# Destructuring assignment from a polymorphic expression emits invalid C: the
# poly result lands in locals Spinel typed `mrb_int`, with no unboxing. The
# polymorphism usually comes from an optional keyword argument (`points: nil`
# makes the parameter `NilClass | Array`), so it is pervasive rather than local.
#
# Rewriting `a, b = expr` to an indexed temporary sidesteps it. Kept here rather
# than in `lib/` because three lines per site, at ~40 sites, is a real
# readability cost for what should be a compiler fix — see "To report upstream".
#
# Deliberately NOT rewritten:
#   - parallel assignment (`a, b = @x, @y`) — no array is indexed, and it works
#   - block parameters (`|a, b|`) — a different construct entirely
#   - anything with a splat, which the indexed form can't express
def spinel_expand_massign(src)
  rewritten = 0
  out = src.lines.map do |line|
    m = line.match(/\A(\s*)([a-z_]\w*), ([a-z_]\w*)(?:, ([a-z_]\w*))? = (\S.*?)\s*\z/)
    next line unless m
    # A comma at bracket depth zero means parallel assignment (`a, b = @x, @y`),
    # which compiles fine and must be left alone. A comma *inside* parens is
    # just an argument list (`x, y = f(a, b)`) and should still be rewritten.
    next line if spinel_top_level_comma?(m[5])
    next line if m[5].include?('*') || m[5].end_with?('=')

    indent, names, rhs = m[1], [m[2], m[3], m[4]].compact, m[5]
    tmp = "_sp_#{names.first}"
    rewritten += 1
    ["#{indent}#{tmp} = #{rhs}\n",
     *names.each_with_index.map { |n, i| "#{indent}#{n} = #{tmp}[#{i}]\n" }].join
  end.join

  if rewritten.zero?
    raise SpinelCompatDrift, 'Spinel compat `multiple assignment` matched nothing. See spinel/README.md.'
  end

  out
end


# An ivar first assigned inside a module body stays polymorphic, and a method
# name that several core classes share then resolves to the wrong one:
# `@gamepads_by_id.delete(id)` compiles to `String#delete`. Unambiguous methods
# (`[]`, `[]=`, `key?`) are unaffected, which is why only `delete` needs this.
#
# In the compat layer rather than `lib/` because the replacement allocates a new
# Hash and reads worse than `delete` — it is not defensible Ruby on its own.
def spinel_expand_hash_delete(src)
  spinel_sub(src,
             "        pad = @gamepads_by_id.delete(id)\n",
             "        pad = @gamepads_by_id[id]\n" \
             "        @gamepads_by_id = @gamepads_by_id.reject { |k, _v| k == id }\n",
             'Hash#delete on a poly ivar')
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


# `Interactive` reaches the shapes through a nested include — `Renderable`
# includes it, the shapes include `Renderable` — and that second hop does not
# carry its methods across, so `object.interactive?` is undefined at run time.
# The guard in front of it uses `respond_to?`, which an AOT build answers from
# the compile-time class graph and gets wrong here.
#
# Per-object events are outside the current scope, so the registration is
# switched off rather than worked around. This is a scope limit, not a fix:
# `on` / `off` on a shape will not work on the Spinel target until the nested
# include does. See spinel/README.md.
def spinel_disable_object_interactivity(src)
  spinel_sub(src,
             "      if object.respond_to?(:interactive?) && object.interactive?\n",
             "      if false # per-object events unsupported on this target\n",
             'per-object interactivity registration')
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


# Apply every compatibility transformation to the assembled library source.
# `class_methods_source` is `lib/ruby2d/window/class_methods.rb`, read for the
# list of delegating class methods rather than hardcoding it.
def spinel_compat(src, class_methods_source)
  src = spinel_expand_renderable(src)
  src = spinel_expand_window_singleton(src)
  src = spinel_bypass_window_class_methods(src, class_methods_source)
  src = spinel_window_guards(src)
  src = spinel_expand_or_return(src)
  src = spinel_expand_hash_delete(src)
  src = spinel_disable_class_pattern(src)
  src = spinel_disable_object_interactivity(src)
  src = spinel_expand_massign(src)
  src + spinel_web_predicate
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
