# [Codegen] `equal?` between a typed receiver and an untyped argument is constant-folded to `false`

Filed as [#3807](https://github.com/matz/spinel/issues/3807). Found while porting [Ruby 2D](https://github.com/ruby2d/ruby2d) to Spinel.

## Description

`a.equal?(b)`, where `a` has a user-class type and `b` is inferred `untyped`, is compiled to the constant `false`. Both operands are discarded — the emitted C casts them to `(void)` and returns `FALSE` — so the comparison never happens, and an object compared against itself answers `false`.

The receiver's static type and the argument's differ, which appears to be read as "these can never be the same object". A poly value holding that very object is the case that breaks.

## Reproduction

```ruby
Pad = Struct.new(:name)

def same?(a, b)
  a.equal?(b)
end

pad = Pad.new('p1')
puts same?(pad, pad).inspect
puts same?(pad, :sym).inspect
```

**Ruby 4.0.6:**
```
true
false
```

**Spinel (83d1315d):**
```
false
false
```

The second call is what widens `b` to `untyped`; the first is the one that answers wrongly.

## Additional Findings

**The emitted C discards both operands:**

```c
static mrb_bool sp_same_p(sp_Pad * lv_a, sp_RbVal lv_b) {
  return ((void)(lv_a), (void)(lv_b), FALSE);
}
```

| Variant | Result |
|---|---|
| typed receiver, poly argument | **`false` for the identical object** |
| a plain `class` rather than a `Struct` | **same** |
| `==` instead of `equal?`, same shape | correct — `true` / `false` |
| monomorphic call, both operands typed | correct |
| both operands poly — e.g. two reads from the same poly hash | correct |
| the sentinel idiom, `def f(x = SENTINEL); x.equal?(SENTINEL); end` | correct |

`==` answering correctly on the identical shape is the sharp contrast: only `equal?` is folded, and only when the two operands' static types differ.

The shape that reaches it is an ordinary one: an identity predicate, `def gamepad?(other) = gamepad.equal?(other)`, whose argument is polymorphic because the caller passes more than one kind of value.

## Suggested fix

A differing static type is not evidence that two references cannot be the same object when one side is `untyped`: the poly value can hold an instance of the receiver's class. Where the argument is poly, the comparison needs to reach the runtime identity check rather than fold. Folding is right only when both sides have concrete, distinct types.

## Environment

- Spinel commit: `83d1315d`
- Ruby version: 4.0.6
- Platform: macOS 26 (arm64), Apple clang 21
