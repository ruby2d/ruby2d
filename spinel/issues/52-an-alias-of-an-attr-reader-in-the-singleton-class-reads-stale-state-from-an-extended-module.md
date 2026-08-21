# [Runtime] An `alias_method` of a singleton `attr_reader` answers stale state when called implicitly from an `extend`ed module

Found while porting [Ruby 2D](https://github.com/ruby2d/ruby2d) to Spinel: `Window.render_ready_check` raised "attempting to draw before the window is ready" while `Window.shown?` answered `true` one line earlier.

## Description

A class tracks state in a class-level ivar and exposes it through `attr_reader :shown` plus `alias_method :shown?, :shown` inside `class << self`, with `attr_writer :shown` beside them. A module `extend`ed onto the class calls `shown?` with an implicit receiver. After `Win.shown = true`, `Win.shown?` from outside answers `true`, but the module method's `shown?` still answers `false`.

Replacing the alias with a plain `def shown? = @shown` makes the module method agree, so it is the alias of the generated reader — not the `extend`, not the class-level ivar — that answers from somewhere other than the writer wrote.

An aliased predicate over a class-level flag is a common way to keep `shown` and `shown?` in step.

## Reproduction

```ruby
class Win
  module CM
    def check = shown? ? 'ok' : 'not ready'
  end
end
class Win
  @shown = false
  class << self
    attr_reader :shown
    alias_method :shown?, :shown
    attr_writer :shown
  end
  extend CM
end
Win.shown = true
puts Win.shown?
puts Win.check
```

**Ruby 4.0.6:**
```
true
ok
```

**Spinel (f13e0ada):**
```
true
not ready
```

## Additional Findings

| Variant | Result |
|---|---|
| As above | **`not ready`** — the module sees `false`, the caller sees `true` |
| `def shown? = @shown` and `def shown=(v)` written out instead of `attr_*` + alias | correct |
| `Win.shown?` called directly | correct — only the implicit call from the module is wrong |

## Environment

- Spinel commit: `f13e0ada`
- Ruby version: 4.0.6
- Platform: macOS 26 (arm64), Apple clang 21
