# CRuby idioms mruby doesn't implement, shimmed as no-ops. Both are visibility
# hints with no runtime effect, so dropping them on mruby is free — but without
# these stubs every file that calls one raises `NoMethodError` in the native and
# web builds while the CRuby specs stay green. CRuby never takes this branch, so
# the file reads as unused — it isn't.

if RUBY_ENGINE == 'mruby'
  class Module
    def private_class_method(*) = self
    def private_constant(*) = self
  end
end
