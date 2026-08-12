# [Compile] `extend` in a reopened class body: an implicit-receiver call to a singleton method becomes unresolvable

Found while porting [Ruby 2D](https://github.com/ruby2d/ruby2d) to Spinel.

Follow-up to [#3788](https://github.com/matz/spinel/issues/3788), whose reproduction passes. The failing library shape turns out not to be about `alias_method` at all — a plain `def self.` fails the same way — but about *where the `extend` is written*.

## Description

A module extended into a class can call the class's singleton methods with an implicit receiver. That resolves correctly when the `extend` sits in the same `class` body as the module definition. Move the `extend` into a **reopening** of the class and the same call stops resolving:

```
unsupported call: node 15 (CallNode `shown?`) recv=-/ty-1 argc=0
```

Nothing else changes — the same module, the same singleton method, the same call.

## Reproduction

```ruby
class Win
  def self.shown?
    false
  end

  module ClassMethods
    def check; shown? ? 'yes' : 'no'; end
  end
end

class Win
  extend ClassMethods
end

puts Win.check
```

**Ruby 4.0.6:**
```
no
```

**Spinel (9678c99b):**
```
spinel: w8.rb:7: unsupported call: node 15 (CallNode `shown?`) recv=-/ty-1 argc=0
```

## Additional Findings

Moving the `extend` is the whole difference. Everything else can vary:

| Variant | Result |
|---|---|
| `extend` in the same body as the module, one `class Win` | resolves |
| `extend` in a second `class Win` body | **unresolvable** |
| module defined in body one, `extend` in body two | **unresolvable** |
| module *and* `extend` both in body one, singleton alias in body two | resolves |
| singleton written as `def self.shown?` | **unresolvable** — the alias is not required |
| singleton written as `attr_reader :shown` + `alias_method :shown?, :shown` in `class << self` | **unresolvable** |
| the class nested inside a module, as `App::Win` | **unresolvable** |

So [#3788](https://github.com/matz/spinel/issues/3788)'s `alias_method` was incidental: its reproduction happened to put everything in one body, which is the arrangement that works.

The diagnostic's `recv=-/ty-1` says the receiver is absent and its type unknown, so the call is not being attributed to the class the module was extended into.

## Impact

This is why Ruby 2D still needs its workaround after #3788 was fixed. `Window::ClassMethods` is defined in `lib/ruby2d/window/class_methods.rb` and `extend ClassMethods` is written in `lib/ruby2d/window.rb`, so the two are necessarily in different `class Window` bodies — splitting a large class across files is ordinary practice, and it makes every implicit-receiver singleton call in the module unresolvable.

## Environment

- Spinel commit: `9678c99b`
- Ruby version: 4.0.6
- Platform: macOS 26 (arm64), Apple clang 21
