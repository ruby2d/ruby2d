# `[Runtime] Safe navigation on the right of || returns NaN instead of nil`

Found while porting [Ruby 2D](https://github.com/ruby2d/ruby2d) to Spinel.

## Description

When a safe-navigation call sits on the right of `||` and the receiver is `nil`, the expression evaluates to `NaN` instead of `nil`. There is no compile error and no exception — the program runs and produces a wrong value, so this fails silently rather than loudly.

The receiver's ivar must be genuinely polymorphic (assigned both an object and `nil` somewhere in the program) for this to appear. If it is only ever `nil`, the result is correct — which is why a smaller reproducer does not show it.

## Reproduction

```ruby
class Inner005
  def opacity005; 0.5; end
end

class Outer005
  def initialize(c005); @c005 = c005; end
  def value005(override005)
    override005 || @c005&.opacity005
  end
end

p Outer005.new(Inner005.new).value005(nil)
p Outer005.new(nil).value005(nil)
```

**Ruby 4.0.6:**
```
0.5
nil
```

**Spinel (1c3d99897ef3):**
```
0.5
NaN
```

## Additional Findings

**Working:**

```ruby
@c005&.opacity005                              # correct nil, outside an ||
override005 || (@c005.nil? ? nil : @c005.opacity005)   # correct nil, explicit check
```

**Failing:** `expr || receiver&.method` where the receiver is nil at run time and the ivar is polymorphic across the program.

The wrong value is `NaN` and the method returns a Float, which suggests the nil branch is coerced to the non-nil branch's type rather than kept polymorphic. A method returning a non-Float may show a different wrong value.

## Related

This looks like the same family as two closed issues, so it may be a variant the earlier fixes did not cover rather than something new:

- [#701](https://github.com/matz/spinel/issues/701) — `&.` on nil returning `""` / `0` instead of `nil`. `NaN` is the Float analogue of those typed zero-values.
- [#3269](https://github.com/matz/spinel/issues/3269) — `&.` on an instance variable producing a wrong value.

What appears to be new here is that the plain form is now correct — `@c005&.opacity005` on its own returns `nil` — and the wrong value only appears on the right of `||`.

## Environment

- Spinel commit: `1c3d99897ef3`
- Ruby version: 4.0.6
- Platform: macOS 15 (arm64), clang
