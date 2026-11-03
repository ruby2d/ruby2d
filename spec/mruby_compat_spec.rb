# `mruby_compat` runs only under mruby, in the native and web builds. Its
# `require` shim is what lets an app be compiled as written — `require 'ruby2d'`
# at the top and all — so lock its contract here: the guard is switched on and
# the file is evaluated inside a throwaway module, where its `class Module` and
# `module Kernel` open fresh constants rather than the real ones.
RSpec.describe 'mruby_compat' do
  let(:sandbox) do
    src = File.read(File.expand_path('../lib/ruby2d/mruby_compat.rb', __dir__))
    Module.new.tap { |m| m.module_eval(src.sub("RUBY_ENGINE == 'mruby'", 'true'), 'mruby_compat.rb') }
  end
  let(:app) { Object.new.extend(sandbox.const_get(:Kernel)) }

  it 'is not loaded under CRuby' do
    expect($LOADED_FEATURES.grep(/mruby_compat/)).to be_empty
  end

  it "answers `require 'ruby2d'` and `require 'ruby2d/core'`, which are built in" do
    expect(app.require('ruby2d')).to be false
    expect(app.require('ruby2d/core')).to be false
  end

  it 'refuses any other library by name' do
    expect { app.require('json') }
      .to raise_error(NotImplementedError, /can't require `json`: a compiled app has Ruby 2D built in/)
  end

  it 'refuses require_relative and load the same way' do
    expect { app.require_relative('player') }
      .to raise_error(NotImplementedError, /can't require_relative `player`: a compiled app is its one source file/)
    expect { app.load('player.rb', true) }
      .to raise_error(NotImplementedError, /can't load `player.rb`/)
  end

  # `update` leaves out `dt` only for a lambda that takes no arguments
  it "gives a method that takes no arguments a lambda that takes none, and any other mruby's pass-through" do
    method_class = sandbox.const_get(:Method)
    none = method_class.new.tap { |m| def m.arity = 0; def m.call(&b) = [:none, b&.call] }
    expect(none.to_proc.arity).to eq(0)
    expect(none.to_proc.lambda?).to be true
    expect(none.to_proc.call { :block }).to eq([:none, :block])

    one = method_class.new.tap { |m| def m.arity = 1; def m.call(*args, **opts) = [args, opts] }
    expect(one.to_proc.call(1, key: 2)).to eq([[1], { key: 2 }])
  end
end
