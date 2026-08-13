# [Runtime] An override of an inherited `attr_reader` is dispatched correctly but typed as the attr

Filed as [#3909](https://github.com/matz/spinel/issues/3909). Found while porting [Ruby 2D](https://github.com/ruby2d/ruby2d) to Spinel.

Follow-up to [#1702](https://github.com/matz/spinel/issues/1702), whose reproduction passes on current master. That issue was the *dispatch* half — the call site read the field instead of calling the override. The override is now called; the call site still takes its **type** from the attr.

## Description

When a class defines a method that overrides an `attr_reader`/`attr_accessor` inherited from a parent class or an included module, the call site emits the override's function but types the expression as the attribute's ivar. When the two happen to agree — the case [#1702](https://github.com/matz/spinel/issues/1702) reproduces — nothing is wrong. When they differ, the emitted C reinterprets the returned value as the attr's type.

Which way they differ decides what the user sees. An `mrb_int` returned where a `const char *` is expected compiles without a warning and is dereferenced: a segfault. The reverse is caught by the C compiler, and the build stops on generated code the user did not write.

## Reproduction

```ruby
class Attr
  attr_accessor :x
  def initialize(v)
    @x = v
  end
end

class Child < Attr
  def x
    @x.length
  end
end

puts Child.new('abc').x
```

**Ruby 4.0.6:**
```
3
```

**Spinel (e05feeb9):**
```
[segmentation fault]
```

## Additional Findings

**The emitted C casts the returned integer to a string pointer:**

```c
static mrb_int sp_Child_x(sp_Child *self) {
  return sp_str_length_m(self->iv_x);
}
...
{ const char *_ps = (const char *)(sp_Child_x((sp_Child *)_t1)); if (_ps) fputs(_ps, stdout); ... }
```

`sp_Child_x` is declared and emitted as returning `mrb_int`, and the call site declares its result a `const char *`. The two disagree in the same statement.

| Variant | Result |
|---|---|
| String ivar, override returns Integer | **segfault** |
| Integer ivar, override returns String | **compile error** — `incompatible pointer to integer conversion` |
| the attr never assigned, override returns Integer | **compile error** — `passing 'mrb_int' … to parameter of incompatible type 'sp_RbVal'` |
| the result assigned to a local first | **compile error** — the mismatch moves to the assignment |
| the call made from inside another method | **segfault** |
| the override ignoring the ivar entirely (`def x; 7; end`) | **segfault** |
| the attr from an included module rather than a parent | **segfault** |
| `attr_reader` instead of `attr_accessor` | **segfault** |
| Integer ivar, override returns Integer — the [#1702](https://github.com/matz/spinel/issues/1702) shape | prints `30` |
| the parent providing `def x` rather than an attr | prints `3` |

The last two rows bound it: the mechanism is the attr specifically, and it only surfaces when the types disagree, which is why [#1702](https://github.com/matz/spinel/issues/1702)'s reproduction cannot see it. The override does not have to read the ivar at all — `def x; 7; end` crashes the same way — so the attr contributes nothing but its type.

A subclass that overrides an accessor to compute rather than store is the reason to write the override at all, and computing usually changes the type: a stored width read back as a formatted string, a stored string read back as its length. That is the shape this was found in.

## Cause

Dispatch and typing resolve the reader/method collision independently, and only dispatch arbitrates. The read emitter now walks the ancestor chain and lets the more-derived definition win (`src/codegen_call_recv.c:8554` — the fix [#1702](https://github.com/matz/spinel/issues/1702) got), which is why that issue's same-type reproduction passes. But the *type* of the call expression is still resolved through the reader entry, so the analyzer types the expression as the attr's ivar while the emitter calls the override: the emitted C declares `sp_Child_x` as returning `mrb_int` and, in the same statement, casts the result to `const char *`.

## Suggested fix

Resolve the type from whichever member the dispatch arbitration chose. When the method wins, the call's type is that method's return type, and the reader entry should not be consulted for it — the same more-derived-wins precedence the emitter applies at `codegen_call_recv.c:8554`, applied during inference.

## Environment

- Spinel commit: `e05feeb9`
- Ruby version: 4.0.6
- Platform: macOS 26 (arm64), Apple clang 21
