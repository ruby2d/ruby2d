# [Codegen] A method on an untyped receiver compiles to an unconditional raise unless a user class owns the name

**Status:** research notes — not ready to file. Root-caused with a decisive test, but there is no minimal reproducer yet, and our standard is a small Ruby that fails under Spinel and passes under CRuby. Eleven probe variants are recorded below so they are not tried again.

## Description

Spinel emits a polymorphic dispatch — a `switch (cls_id)` with an arm per builtin type — for a method call on an untyped receiver **only when some user-defined class in the program defines a method of that name**. When no user class owns the name, the call is compiled to an unconditional `NoMethodError` raise with no dispatch and no runtime check, so it fires whatever the receiver actually is.

In Ruby 2D this surfaced as `undefined method 'empty?' for an instance of Array`, on an ordinary `Array` that plainly has `empty?`.

The asymmetry within one class is the clearest statement of it. `Ruby2D::Color::Set` defines `length` but not `empty?`. On the *same* untyped receiver:

- `colors.length` → a correct `switch (cls_id)` with a case per array and hash flavor
- `colors.empty?` → `sp_raise_cls("NoMethodError", ...)`, unconditionally

## The generated C

From `Color.set`, whose inferred signature is `def self.set: (untyped) -> untyped`:

```c
sp_raise_cls("NoMethodError", sp_nomethod_msg_args("empty?", lv_colors, 0, ...))
```

Contrast `length` on an equally untyped receiver, which gets the full dispatch:

```c
switch (_t399.cls_id) {
  case 14: _t400 = sp_Set_length((sp_Set *)_t399.v.p); break;
  case SP_BUILTIN_INT_ARRAY: case SP_BUILTIN_SYM_ARRAY: ...
  case SP_BUILTIN_STR_ARRAY: ...
  case SP_BUILTIN_POLY_ARRAY: ...
  default: sp_raise_nomethod(sp_nomethod_msg("length", _t399)); break;
}
```

## Cause

`src/codegen_call.c`, around line 4253, generating the builtin arms — its own comment describes the condition:

> Container reads on a builtin receiver that reached this dispatch only because a user class happens to own the name. The user arms are above; without an arm of its own the switch left every builtin tag on the raise default […]

So the builtin arms are attached to a dispatch that exists *because of* a user-owned name. `empty?` has its own generator a few lines above, guarded by `if (is_empty)`, emitting arms for `INT_ARRAY`, `STR_ARRAY`, `FLT_ARRAY`, `POLY_ARRAY` and every hash flavor — correct code that is never reached when no user class owns `empty?`.

## The decisive test

Appending a never-instantiated class that merely owns the name makes the failing program run correctly:

```ruby
class Probe
  def empty?
    true
  end
end
```

Adding that to the assembled Ruby 2D program, changing nothing else, turns the crash into a correct render. Defining `Color::Set#empty?` — the same mechanism, via a class that is actually in the union — does the same, and is what Ruby 2D shipped.

## What reproduces it today

Only the whole library, which is why this is not ready to file. Delete `Color::Set#empty?` from `lib/ruby2d/color.rb`, run `rake` to reinstall the gem, then build any per-vertex color:

```ruby
require 'ruby2d'

set width: 320, height: 240
Square.new(color: %w[red lime blue yellow])
show
```

```
undefined method 'empty?' for an instance of Array (NoMethodError)
```

`spinel/tools/gradient_app.rb` is the same shape with a frame cap and a screenshot, and `rake compare` builds it on both engines.

## Probes that pass, and should not be retried

Every one of these compiles and runs correctly under Spinel, matching CRuby. The receiver in each resolves to a small enumerated union, so codegen emits a direct or switched call and never reaches the unconditional-raise path.

| # | Shape |
|---|---|
| 1 | `v.is_a?(Array)` early-return guard, then `v.empty?`; called with a String and an Array |
| 2 | `def check(v) = v.empty?` called only with Arrays |
| 3 | same, called with a String and an Array |
| 4 | same, with a user class and an Array, `is_a?` early-return guard |
| 5 | value read out of a heterogeneous `Hash` literal, then `.empty?` |
| 6 | hash argument passed through two method hops, then `.empty?` |
| 7 | a hand-written mirror of `Color`/`Color::Set`, including `class << self` and the `is_a?(Color::Set)` pass-through |
| 8 | `Array \| String \| Hash` union, then `.empty?` |
| 9 | the same union plus an unrelated user class owning `empty?` |
| 10 | `v.is_a?(Array) && !v.empty?` as a single expression |
| 11 | the same guard written as an early return |

## Suggested next step

Do not reduce against run-time behaviour — the oracle is available at compile time and is far sharper. `spinel app.rb -c` writes `app.c`; the bug is present whenever

```sh
grep -c 'sp_nomethod_msg_args("empty?"' app.c
```

is non-zero, and absent when the same call site produces a `switch (cls_id)`. That makes a two-sided oracle cheap: CRuby accepts the program, Spinel compiles it, and the emitted C contains the unconditional raise. No linking and no window.

The open question is what widens a receiver to genuinely `untyped` rather than to an enumerated union. In the library it is a parameter reached from several call sites through a `Symbol`-keyed poly hash, and `--emit-rbs` reports `untyped` for it; every probe above got a union instead. `--emit-rbs` on a candidate is the fast way to tell which one you have before compiling.

## Environment

- Spinel commit: `9678c99b`
- Ruby version: 4.0.6
- Platform: macOS 26 (arm64), Apple clang 21
