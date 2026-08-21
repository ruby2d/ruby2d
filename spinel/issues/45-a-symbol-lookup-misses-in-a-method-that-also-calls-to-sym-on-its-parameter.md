# [Runtime] A Symbol hash lookup misses when the method also calls `to_sym` on the same parameter and is reached with a String elsewhere

Found while porting [Ruby 2D](https://github.com/ruby2d/ruby2d) to Spinel: every valid input name was rejected as invalid by the library's name validator.

## Description

`@h.key?(k)` returns `false` for a Symbol key that is in the Hash. Three things have to be true at once, and removing any one of them makes the lookup correct:

1. the Hash was filled by assignment in a loop (`names.each { |n| @h[n] = true }`) rather than written as a literal;
2. the method that does the lookup also evaluates `k.to_sym` on the same parameter, even on a path that is not taken;
3. the method is called with a Symbol from one call site and a String from another.

The second lookup in the same method, `@h.key?(k.to_sym)`, finds the key — so the Hash is intact and the Symbol is the right one. It is the direct lookup with the parameter that misses, which suggests the parameter's type is widened to cover both call sites and the Symbol arrives at the hash lookup in a representation that does not match how the keys were stored.

Validating user-supplied names is exactly this shape: look the name up, and if it misses, check whether a String spelling of a known Symbol was passed so the error can say so. Because `||` or an early return would hide the bug behind the successful second lookup, it can sit silently in a program for a long time.

## Reproduction

```ruby
class V
  def initialize(names)
    @h = {}
    names.each { |n| @h[n] = true }
  end

  def check(k)
    return :direct if @h.key?(k)
    return :via_to_sym if @h.key?(k.to_sym)
    :missing
  end
end

v = V.new(%i[left])
puts v.check(:left)   # expected :direct
puts v.check('left')  # expected :via_to_sym
```

**Ruby 4.0.6:**
```
direct
via_to_sym
```

**Spinel (42649df7):**
```
via_to_sym
via_to_sym
```

## Additional Findings

| Variant | Result |
|---|---|
| As above | **`key?(:left)` is false** |
| `@h = { left: true }` literal instead of the loop | correct |
| Only the Symbol call site (`check('left')` removed) | correct |
| Second lookup removed (no `k.to_sym` in the method) | correct — `true false` |
| `k.downcase.to_sym` instead of `k.to_sym` | **same miss** |
| `is_a?(String) &&` guarding the second lookup | **same miss** — the guard does not help, the branch is not taken for `:left` anyway |
| Lookup through a one-line wrapper (`def valid?(k) = @h.key?(k)`) | **same miss** |
| Same method body at top level with a constant Hash instead of an ivar | correct |
| `@h.key?(k) \|\| @h.key?(k.to_sym)` | prints `true` — the second lookup masks the first one's miss |

## Impact

Silent: no diagnostic, and the result is a plain `false` from a Hash that visibly contains the key. In Ruby 2D it made every `on key_down: :escape`, `mouse_pressed?(:left)` and gamepad name check raise as "not a valid name" with a message that lists the very name that was passed.

## Environment

- Spinel commit: `42649df7`
- Ruby version: 4.0.6
- Platform: macOS 26 (arm64), Apple clang 21
