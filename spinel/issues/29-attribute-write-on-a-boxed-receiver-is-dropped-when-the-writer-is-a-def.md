# [Runtime] An attribute write on a run-time-typed receiver is silently dropped when the writer is a `def`

Found while porting [Ruby 2D](https://github.com/ruby2d/ruby2d) to Spinel.

## Description

When a receiver's class is only known at run time, `obj.x = v` is emitted as a `switch` over the receiver's class id. That switch is built from the **attribute** table alone: it gets an arm for every class declaring `x` through `attr_accessor`/`attr_writer`, and none for a class whose writer is a hand-written `def x=`. There is no `default` arm either, so a receiver the switch does not name falls straight through and the assignment is discarded.

Nothing is reported. The program compiles without warnings, runs to completion, and the object keeps its old value. Reading the same attribute on the same receiver works, because the read dispatch is built from the method table and does carry an arm for the `def`.

The trigger is that *some* class in the program declares the name as an attr. With no attr anywhere, the write dispatches through the method table and every class is handled correctly.

## Reproduction

```ruby
class Attr
  attr_accessor :x

  def initialize
    @x = 0
  end
end

class Def
  def initialize
    @x1 = 0
  end

  def x
    @x1
  end

  def x=(v)
    @x1 = v
  end
end

box = [Def.new, Attr.new]

o = box[0]
o.x = 42
puts "def writer  x=#{o.x}"

a = box[1]
a.x = 99
puts "attr writer x=#{a.x}"
```

**Ruby 4.0.6:**
```
def writer  x=42
attr writer x=99
```

**Spinel (84f5a236):**
```
def writer  x=0
attr writer x=99
```

## Additional Findings

**The emitted C names only the attr class, and has no `default`:**

```c
{ sp_RbVal _t4 = lv_o; mrb_int _t5 = 42LL;
  switch (_t4.cls_id) { case 0: ((sp_Attr *)_t4.v.p)->iv_x = _t5; break; } }
```

`case 0` is `Attr`. `Def` is class id 1 and has no arm, so a `Def` receiver reaches the end of the switch and the store never happens. The read of the same attribute, on the same receiver, is emitted correctly:

```c
switch (_t2193.cls_id) {
  case 17: _t2194 = sp_Rectangle_x((sp_Rectangle *)_t2193.v.p); break;
  case 27: _t2194 = ((sp_MouseEvent *)_t2193.v.p)->iv_x; break;
  default: sp_raise_nomethod(sp_nomethod_msg("x", _t2193)); break;
}
```

| Variant | Result |
|---|---|
| boxed receiver, writer is a `def`, some class declares the name as an attr | **silently dropped** |
| boxed receiver, writer is `attr_accessor` | correct |
| boxed receiver, writer is a `def`, no class anywhere declares the name as an attr | correct |
| boxed receiver, class has no writer at all, another class declares the name as an attr | **silently dropped** — no `NoMethodError` |
| statically typed receiver (`Def.new` in a local), writer is a `def` | correct |
| homogeneous array, so the element type is provable | correct |
| reading the attribute on a boxed receiver | correct |

The fourth row is the same defect seen from the other side: because the switch has no `default`, a receiver that genuinely does not respond to `x=` is also swallowed instead of raising.

Binding the element to its own variable first does not help — it is the type the value acquires passing through the container, not the subscript expression.

## Cause

The write path resolves the callee through the attribute table without consulting the method table, the mirror of the precedence [#27](27-override-of-an-inherited-attr-keeps-the-attr-type-at-call-sites.md) identifies on the read side (`comp_reader_in_chain` ahead of `comp_method_in_chain` in `codegen_call_recv.c`). Emission there now prefers the method and only the *type* is still taken from the reader entry; on the write side the method appears not to be consulted at all.

## Suggested fix

Build the write switch from the union of both tables, the same way the read switch already is: an arm calling `sp_<Class>_x_set` for each class whose writer is a method, an arm storing the ivar for each class declaring it as an attr, and a `default` that raises `NoMethodError` so an unhandled receiver is reported rather than ignored.

## Impact

A class that computes on assignment — validating, updating a derived field, invalidating a cache — is exactly the class that writes its writer by hand, and any collection holding a mix of classes produces a run-time-typed receiver. In Ruby 2D this silently discards every `shape.x = …` and `shape.y = …` on a shape held in an array, while `shape.color = …` on the same object works, because `Renderable#color=` happens to be the only definition of that name and `x=` collides with `MouseEvent`'s `attr_accessor :x`.

## Environment

- Spinel commit: `84f5a236`
- Ruby version: 4.0.6
- Platform: macOS 26 (arm64), Apple clang 21
