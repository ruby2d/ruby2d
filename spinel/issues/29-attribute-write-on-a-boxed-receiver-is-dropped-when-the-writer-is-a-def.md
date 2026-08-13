# [Runtime] An attribute write on a run-time-typed receiver is silently dropped when the writer is a `def`

Filed as [#3907](https://github.com/matz/spinel/issues/3907). Found while porting [Ruby 2D](https://github.com/ruby2d/ruby2d) to Spinel.

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

**Spinel (e05feeb9):**
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

`case 0` is `Attr`. `Def` is class id 1 and has no arm, so a `Def` receiver reaches the end of the switch and the store never happens. The **read** of the same attribute, from the same program and the same receiver, is emitted correctly — an ivar arm, a method arm, and a raising default:

```c
switch ((_t6.tag == SP_TAG_OBJ ? _t6.cls_id : 0x7fffffff)) {
  case 0: _t7 = ((sp_Attr *)_t6.v.p)->iv_x; break;
  case 1: _t7 = sp_Def_x((sp_Def *)_t6.v.p); break;
  default: sp_raise_nomethod(sp_nomethod_msg("x", _t6)); break;
}
```

The missing arm's target already exists: the same compile emits `sp_Def_x_set(sp_Def *self, mrb_int lv_v)` — declared, defined, and never called. Only the switch arm is absent.

| Variant | Result |
|---|---|
| boxed receiver, writer is a `def`, some class declares the name as an attr | **silently dropped** |
| boxed receiver, writer is `attr_accessor` | correct |
| boxed receiver, writer is a `def`, no class anywhere declares the name as an attr | correct |
| boxed receiver, class has no writer at all, another class declares the name as an attr | **silently swallowed** — runs on where CRuby raises `NoMethodError` |
| statically typed receiver (`Def.new` in a local), writer is a `def` | correct |
| homogeneous array, so the element type is provable | correct |
| reading the attribute on a boxed receiver | correct |

The fourth row is the same defect seen from the other side: because the switch has no `default`, a receiver that genuinely does not respond to `x=` is also swallowed instead of raising.

Binding the element to its own variable first does not help — it is the type the value acquires passing through the container, not the subscript expression.

In Ruby 2D this silently discards every `shape.x = …` and `shape.y = …` on a shape held in an array, while `shape.color = …` on the same object works — `color=` happens to collide with no attr in the program, and `x=` collides with `MouseEvent`'s `attr_accessor :x`.

## Cause

The two write emitters in `src/codegen_stmt.c` resolve the same name against different tables, and only one of them arbitrates.

The typed-receiver emitter (`src/codegen_stmt.c:5894`) does this correctly since the fix for the read-side precedence: it asks `comp_writer_in_chain` *and* `comp_method_in_chain`, walks the ancestor chain, and lets the more-derived definition win, with a same-class tie going to the explicit `def x=` (`:5901-5913`).

The boxed-receiver emitter (`:5985`) never asks the method table. It counts candidates with `comp_is_writer` (`src/compiler.c:828` — a `name_in(ci->writers, …)` lookup, not chain-aware), emits an ivar-store arm per attr-declaring class, `continue`s past a class whose ivar slot cannot hold the right-hand side's concrete type (`:6019`) — a second way for an arm to silently vanish — and closes the switch with a bare `" } }\n"` (`:6031`): no method arm, no `default`.

`writers[]` is populated from `attr_writer`/`attr_accessor`, `Struct` members, module inclusion, and superclass copy. A hand-written `def x=` never enters it, so a class defining its writer by hand is structurally absent from the switch.

## Suggested fix

Give the boxed emitter the arbitration its typed sibling already has, per candidate class: an arm calling `sp_<Class>_x_set` where the method wins, an ivar store where the attr wins, and a `default` that raises `NoMethodError` so an unhandled receiver is reported rather than ignored — the boxed *read* switch already closes exactly that way.

## Environment

- Spinel commit: `e05feeb9`
- Ruby version: 4.0.6
- Platform: macOS 26 (arm64), Apple clang 21
