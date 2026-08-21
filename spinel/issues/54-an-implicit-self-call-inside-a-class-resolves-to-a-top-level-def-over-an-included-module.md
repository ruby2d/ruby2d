# [Runtime] An implicit-self call inside a class resolves to a top-level `def` of the same name instead of the included module's method

Found while porting [Ruby 2D](https://github.com/ruby2d/ruby2d) to Spinel: `Button` registers its hover handler with `on(:hover) { … }`, `on` comes from an included module, and the program also defines a top-level `on` (the DSL's window-level form). The call went to the top-level one and raised "`hover` is not a valid event type".

## Description

When a method is defined at the top level (so it lands on `Object`) and a module included into a class defines a method of the same name, a call inside that class **without an explicit receiver** resolves to the top-level method. Ruby resolves it to the module's: the class's ancestors (`Sq`, `I`, `Object`, …) are searched in order, and `I` comes before `Object`.

With `self.on(…)` the call resolves correctly, and the explicit-receiver form from outside the class (`Sq.new.on(…)`) is also correct. Only the implicit-receiver call inside the class is wrong.

A DSL that offers a top-level verb and an object-level verb of the same name — `on` for the window and `on` for an object — is an ordinary shape; Ruby 2D's is one of several.

## Reproduction

```ruby
module I
  def on(x, &b)
    puts "I#on #{x}"
  end
end
class Sq
  include I
  def setup
    on(:hover) { puts 'h' }
  end
end
def on(x, &b)
  puts "top on #{x}"
end
on(:a) {}
Sq.new.setup
```

**Ruby 4.0.6:**
```
top on a
I#on hover
```

**Spinel (f13e0ada):**
```
top on a
top on hover
```

## Additional Findings

| Variant | Result |
|---|---|
| As above (implicit self inside the class) | **top-level method called** |
| `self.on(:hover) { … }` inside the class | correct |
| `Sq.new.on(:b) { }` from outside, top-level `on` also called | correct |
| Top-level `on` defined but never called | correct — the top-level method has to be live |

## Environment

- Spinel commit: `f13e0ada`
- Ruby version: 4.0.6
- Platform: macOS 26 (arm64), Apple clang 21
