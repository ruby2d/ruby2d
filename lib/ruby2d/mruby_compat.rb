# CRuby idioms mruby doesn't implement, shimmed for the native and web builds.
# CRuby never takes this branch, so the file reads as unused — it isn't.

if RUBY_ENGINE == 'mruby'
  # Visibility hints with no runtime effect, so dropping them on mruby is free —
  # but without these stubs every file that calls one raises `NoMethodError` in
  # the builds while the CRuby specs stay green.
  class Module
    def private_class_method(*) = self
    def private_constant(*) = self
  end

  # A compiled app has Ruby 2D built in and mruby loads nothing else, so
  # `require` accepts Ruby 2D's own names — the `require 'ruby2d'` every app
  # starts with — and refuses any other by name, rather than mruby's
  # `undefined method 'require'`. Returns false as CRuby does for a library
  # that is already loaded. `require_relative` and `load`, the ways an app
  # splits itself across files, refuse the same way.
  module Kernel
    def require(name)
      return false if name == 'ruby2d' || name == 'ruby2d/core'

      raise NotImplementedError, "can't require `#{name}`: a compiled app has Ruby 2D built in and can't load other libraries"
    end

    def require_relative(name)
      raise NotImplementedError, "can't require_relative `#{name}`: a compiled app is its one source file and can't load others"
    end

    def load(name, *)
      raise NotImplementedError, "can't load `#{name}`: a compiled app is its one source file and can't load others"
    end
  end

  # A Method's proc reports the method's arity on CRuby, but mruby's passes any
  # arguments through and reports -1. `update` reads the arity to decide
  # whether to pass `dt`, so `update(&method(:tick))` handed a zero-parameter
  # `tick` one and raised. A method that takes no arguments now gets a proc
  # that takes none, as on CRuby; any other keeps mruby's own pass-through.
  class Method
    def to_proc
      method = self
      return ->(&block) { method.call(&block) } if arity.zero?

      ->(*args, **opts, &block) { method.call(*args, **opts, &block) }
    end
  end
end
