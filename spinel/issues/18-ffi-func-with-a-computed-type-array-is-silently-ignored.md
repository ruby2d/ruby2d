# [Compile] `ffi_func` with a non-literal type array is silently ignored, and the error lands on an unrelated line

**Status:** Spinel-only — `ffi_func` is a Spinel DSL, so there is no CRuby behavior to compare against and `verify_issues.rb` does not run this one. Re-check it by hand.

Found while porting [Ruby 2D](https://github.com/ruby2d/ruby2d) to Spinel.

## Description

`ffi_func` accepts its parameter types as an array literal. Given anything else in that position — `[:float] * 6`, or a constant holding the list — the declaration is dropped with no diagnostic. Compilation continues, and the failure surfaces later at the first **call** of the undeclared function, reported as an unsupported call rather than as anything to do with `ffi_func`.

The value is a compile-time constant either way, so the two forms describe the same function. Rejecting the computed form would be reasonable; accepting it silently and failing somewhere else is what makes this expensive.

## Reproduction under Spinel

Two programs differing only in how the one-element type array is written.

Accepted — `ffi_a.rb`:

```ruby
module Demo
  module Ext
    ffi_func :fabsf, [:float], :float
  end
end

puts Demo::Ext.fabsf(-2.5)
```

```
$ spinel ffi_a.rb -o ffi_a && ./ffi_a
2.5
```

Silently dropped — `ffi_b.rb`, with `[:float]` written as `[:float] * 1`:

```ruby
module Demo
  module Ext
    ffi_func :fabsf, [:float] * 1, :float
  end
end

puts Demo::Ext.fabsf(-2.5)
```

```
$ spinel ffi_b.rb -o ffi_b
spinel: ffi_b.rb:7: unsupported puts argument: node 19 (CallNode `fabsf`) recv=ConstantPathNode/ty48 argc=1 arg0ty5
```

## Additional Findings

**The line number points away from the cause.** The declaration is on line 3; the diagnostic names line 7. Nothing in the message mentions `ffi_func`, the type array, or the declaration that was discarded — `unsupported puts argument` describes the symptom at the call site, so the natural reading is that the *call* is malformed.

**A function that is declared but never called compiles clean.** Dropping `puts Demo::Ext.fabsf(-2.5)` from `ffi_b.rb` produces a binary with no diagnostic at all, since nothing then references the missing declaration. In a real FFI adapter, where declarations are added ahead of the code that uses them, this means the mistake can sit in the source for as long as the call site is absent.

**A constant holding the list behaves the same way.** `TYPES = [:float].freeze` and then `ffi_func :fabsf, TYPES, :float` is dropped identically, again reported at the call site. So it is not about the `*` operator; anything other than an array literal in that position disappears.

**It scales with the adapter.** Ruby 2D's Spinel adapter declares 21 functions, two of which take 24 and 25 `:float` parameters for per-vertex geometry. Those are exactly the ones a programmer would write as `[:float] * 24`, and doing so costs a debugging session per occurrence.

## Suggested fix

Either fold a constant-valued array expression before reading the type list, or reject the declaration where it is written:

```
ffi_b.rb:3: ffi_func `fabsf`: the parameter type list must be an array literal
```

Naming the declaration line is the more valuable half. Even without support for computed arrays, an error at the `ffi_func` call turns this from a misleading failure at an unrelated site into a one-line fix.

## Environment

- Spinel commit: `b51c880d`
- Ruby version: 4.0.6
- Platform: macOS 26 (arm64), Apple clang 21
