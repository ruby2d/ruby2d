# [Runtime] Splatting `nil` passes one `nil` argument instead of none

Found by a Ruby-versus-Spinel differential survey while porting [Ruby 2D](https://github.com/ruby2d/ruby2d) to Spinel.

## Description

`*nil` in an argument list expands to **no** arguments in Ruby: `nil` has no `to_a`, and the splat of it contributes nothing. Spinel expands it to a single `nil` argument.

Splatting an empty array is handled correctly, so the empty case itself is understood — it is `nil` specifically that is passed through as a value rather than treated as the empty expansion.

The consequence is an off-by-one in the argument count, which for a rest parameter shows up as an unexpected `nil` element and for a fixed-arity method turns a call Ruby rejects into one that runs.

## Reproduction

```ruby
def m(*a)
  p a
end

v = nil
m(*v)
```

**Ruby 4.0.6:**
```
[]
```

**Spinel (42649df7):**
```
[nil]
```

## Additional Findings

| Variant | Result |
|---|---|
| `m(*v)` where `v = nil` | **`[nil]`** |
| `m(*nil)` written literally | **`[nil]`** — the literal form diverges too |
| `m(1, *nil)` | **`[1, nil]`** — the trailing splat adds the extra element |
| `m(*v)` where `v = []` | correct — `[]` |
| `def m(a)` called as `m(*nil)` | **binds `a` to `[]` and runs**; Ruby raises `ArgumentError` (given 0, expected 1) |

The last row is the one that changes control flow rather than data: a call Ruby refuses outright is accepted, and the parameter is bound to a value that came from neither the caller nor a default.

## Cause

Not root-caused. The `v = []` row shows the empty expansion works when the value is an array, so the gap is the `nil` case reaching the splat path as an ordinary value instead of being expanded first. Ruby's rule is that a splatted operand is converted with `to_a` and `nil.to_a` is `[]`; Spinel appears to skip that conversion for `nil` and push the boxed value.

## Suggested fix

Expand a splatted `nil` to zero arguments — equivalently, apply `nil.to_a == []` before the argument list is built, which also makes the literal and runtime forms agree. The fixed-arity row then raises on its own, because the call really does supply no arguments.

## Impact

Silent, and it changes arity. `m(*maybe_nil)` is an ordinary way to forward an optional argument list, and it produces a call one argument longer than the program intended.

## Environment

- Spinel commit: `42649df7`
- Ruby version: 4.0.6
- Platform: macOS 26 (arm64), Apple clang 21
