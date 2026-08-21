# [Compile] A poly-dispatched call emits invalid C for an arm whose method has a keyword defaulting to an ivar

Found while porting [Ruby 2D](https://github.com/ruby2d/ruby2d) to Spinel: `Window#register_event_handler` does `@events[:close].clear` on a Hash value, and once `Canvas` — which has its own `clear(color = nil, x: 0, width: @width, …)` — was in the program, every app stopped compiling at that line.

## Description

When a call's receiver is a poly value, Spinel emits a `switch` over the classes that answer the method. For an arm whose method has a keyword argument defaulting to an instance variable (`width: @width`), the default is emitted as `(sp_Canvas *)_t.v.p->iv_width` — the cast applied to the member rather than the pointer — so the arm passes an object where the parameter wants an integer, and in a smaller program dereferences `void`:

```
error: member reference base type 'void' is not a structure or union
error: passing 'sp_Canvas' (aka 'struct sp_Canvas_s') to parameter of incompatible type 'sp_int'
```

The call site never targets a `Canvas`; the arm exists because the name is shared. Ruby 2D's `Canvas#clear` defaults its region to the canvas's own size, which is the natural default for such a method, and `Hash#clear` on a value pulled from a Hash is ordinary code.

## Reproduction

```ruby
class Canvas
  def initialize(w) = @width = w
  def clear(color = nil, x: 0, width: @width)
    puts "canvas clear #{x} #{width}"
  end
end
class Win
  def initialize
    @events = { close: {}, key: {} }
  end
  def register(event)
    @events[:close].clear if event == :close
    @events[event].size
  end
end
c = Canvas.new(10)
c.clear
w = Win.new
puts w.register(:close)
```

**Ruby 4.0.6:**
```
canvas clear 0 10
0
```

**Spinel (f13e0ada):**
```
error: member reference base type 'void' is not a structure or union
```

## Additional Findings

| Variant | Result |
|---|---|
| As above | **invalid C** at the `@events[:close].clear` site |
| `@events[:close] = {}` instead of `.clear` | correct |
| `Canvas#clear` with `width: 0` (a literal default) | correct — the ivar default is the trigger |
| `Canvas` never instantiated, class still defined | **invalid C** — reachability of the class is enough |

## Environment

- Spinel commit: `f13e0ada`
- Ruby version: 4.0.6
- Platform: macOS 26 (arm64), Apple clang 21
