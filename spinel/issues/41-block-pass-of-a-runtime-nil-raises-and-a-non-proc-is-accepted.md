# [Runtime] `&value` block-pass gets both ends of the coercion wrong: a runtime `nil` raises `TypeError`, and a non-proc is silently accepted as no block

Found by a Ruby-versus-Spinel differential survey while porting [Ruby 2D](https://github.com/ruby2d/ruby2d) to Spinel.

## Description

`&value` at a call site should convert `value` to a block: `nil` means "no block", anything that is not `nil` and does not respond to `to_proc` is a `TypeError`. Spinel gets both halves backwards when the value is only known at run time.

- `value = nil; f(&value)` raises `TypeError`. Ruby passes no block, and `block_given?` answers `false`.
- `value = 7; f(&value)` is accepted, and `block_given?` answers `false`. Ruby raises `TypeError`.

A literal `f(&nil)` is handled correctly, so the working path is the one where the compiler can see the value; the runtime path is the one that inverts. The result is that the case Ruby allows is refused and the case Ruby refuses is allowed.

## Reproduction

```ruby
def f
  block_given?
end

value = nil

begin
  p f(&value)
rescue => e
  p e.class
end

value = false

begin
  p f(&value)
rescue => e
  p e.class
end
```

**Ruby 4.0.6:**
```
false
TypeError
```

**Spinel (42649df7):**
```
TypeError
TypeError
```

## Additional Findings

| Variant | Result |
|---|---|
| `value = nil` then `f(&value)` | **raises `TypeError`** — Ruby answers `false` |
| `value = 7` then `f(&value)` | **accepted, `block_given?` is `false`** — Ruby raises `TypeError` |
| `f(&nil)` written literally | correct — answers `false` |
| `value = false` then `f(&value)` | correct — raises `TypeError` |
| `value = proc { 1 }` then `f(&value)` | correct — answers `true` |

The second row is the quieter one: a program that passes the wrong thing gets no diagnostic, and the method it called simply behaves as though no block was given.

## Cause

Not root-caused. The literal-`nil` row narrows it: the conversion is right when the value is a compile-time constant and wrong when it is a runtime read, so the defect is in the runtime coercion path rather than in the rule itself. The two failures are consistent with a single test that asks whether the value is a proc and treats every other case identically — raising where the value is a boxed `nil` and falling through to "no block" where it is a boxed Integer, when Ruby's rule keys on `nil` first and `to_proc` second.

## Suggested fix

Order the runtime coercion the way Ruby specifies it: `nil` passes no block; a `Proc` passes itself; anything else calls `to_proc` and raises `TypeError` only when that is unavailable. That makes the literal and runtime paths agree, and both rows in the reproduction fall out of it.

## Impact

The `nil` half is loud — a `TypeError` on a line that is correct Ruby — and appears wherever a block is forwarded optionally, which is the `&callback` shape any event registration uses. The non-proc half is silent and rarer.

## Environment

- Spinel commit: `42649df7`
- Ruby version: 4.0.6
- Platform: macOS 26 (arm64), Apple clang 21
