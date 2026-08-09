# [Codegen] Top-level `include` of a module emits a call with the wrong arity, failing the C compile

Found while porting [Ruby 2D](https://github.com/ruby2d/ruby2d) to Spinel.

## Description

Calling a method brought in by `include` at the top level generates C that passes one argument too few, so the generated file fails to compile. The emitted function takes two parameters (apparently the receiver plus the method's own), while the call site passes one — so the function itself looks correct and only the call site is short a receiver.

This surfaces as a C compiler error rather than a Spinel diagnostic.

## Reproduction

```ruby
module M004
  def double004(n); n * 2; end
end
include M004
p double004(21)
```

**Ruby 4.0.6:**
```
42
```

**Spinel (1c3d99897ef3):**
```
v4_toplevel_include.rb:5:41: error: too few arguments to function call, expected 2, have 1
v4_toplevel_include.rb:2:40: note: 'sp_M004_double004' declared here
1 error generated.
spinel: C compilation failed
```

## Additional Findings

**Working:** `include` inside a class body, then calling on an instance; calling a module function directly (`M004.double004(21)` defined with `def self.`).

**Failing:** `include` at the top level followed by a bare call. `extend M004` at the top level fails identically.

## Environment

- Spinel commit: `1c3d99897ef3`
- Ruby version: 4.0.6
- Platform: macOS 15 (arm64), clang
