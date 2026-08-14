# [Runtime] A `Float` argument to a stored proc is truncated to Integer `0` when the parameter is read inside a nested block

Found while porting [Ruby 2D](https://github.com/ruby2d/ruby2d) to Spinel.

## Description

A proc stored in an ivar and called later with a `Float` receives Integer `0` instead, if two things are both true of the program: the proc's parameter is read from inside a nested block, and the program contains a `Struct`. The parameter's declared type is wrong, not just one read of it — `dt.class` answers `Integer` everywhere in the body, including outside the nested block.

Nothing is reported. The program compiles without warnings and runs to completion; every quantity derived from the argument is zero.

Neither ingredient is enough on its own. With the parameter read only at the proc's top level it arrives correctly as `0.5`; with the `Struct` removed it arrives correctly even with the nested block. The `Struct` need not be touched by the proc, or by anything reachable from it — declaring one and instantiating it is enough. Its member's type does not matter.

## Reproduction

```ruby
class Loop
  def register(&blk)
    @proc = blk
  end

  def tick
    @proc.call(0.5)
  end
end

Point = Struct.new(:v)
Point.new(1.0)

loop = Loop.new
loop.register do |dt|
  [1].each { |_i| _x = dt }
  puts "dt=#{dt} class=#{dt.class}"
end
loop.tick
```

**Ruby 4.0.6:**
```
dt=0.5 class=Float
```

**Spinel (e05feeb9):**
```
dt=0 class=Integer
```

## Additional Findings

The parameter is emitted as an `mrb_int` read from the integer argument slot:

```c
static mrb_int _proc_22(void *_cap, mrb_int argc, mrb_int *args) {
    sp_proc_lambda_arity_check(argc, 1, 0, FALSE, FALSE);
    mrb_int lv___cap_13349_dt__bp13350 = (argc > 0) ? args[0] : SP_INT_NIL;
```

and `dt.class` is constant-folded to the literal `"Integer"` in the same body, so the misinference is in the parameter's type rather than in any one read.

| Variant | Result |
|---|---|
| parameter read inside a nested block, `Struct` present in the program | **Integer `0`** |
| parameter read only at the proc's top level, `Struct` present | correct |
| parameter read inside a nested block, no `Struct` anywhere | correct |
| `Struct` declared and instantiated but never read by the proc | **Integer `0`** |
| `Struct` member typed `Integer` rather than `Float` | **Integer `0`** |
| the block called through `yield` instead of being stored and called later | correct |
| the object holding the members is an ordinary class with `attr_accessor` rather than a `Struct` | correct |
| an `Array` of `Float` in place of the `Struct` | correct |

The last three are what make this specific: the same body reached by `yield`, or with the `Struct` swapped for an equivalent class, compiles to a `Float` parameter.

## Cause

`src/codegen.c:3310` records that this ABI has two paths — "a first-class proc's `.call` passes float args through the boxed side-channel (`sp_box_float` / `sp_poly_to_f`), not the truncating slot". The caller boxes correctly; the callee here declares the parameter `mrb_int` and reads `args[0]`, which is the truncating slot that comment names. What the reproduction adds is which combination lands the parameter in the wrong slot: capture-into-a-nested-block re-types it, and the presence of a `Struct` in the program is what makes that re-typing settle on `Integer`.

## Suggested fix

Type the proc's parameter from the argument the call site passes, independently of whether the parameter is also captured by a nested block, so a capture never narrows a `Float` parameter to the integer slot.

## Impact

This is the per-frame delta time in an animation loop. Ruby 2D registers the user's block with `update do |dt| … end`, stores it, and calls it once per frame with the elapsed seconds; a scene that moves anything by `velocity * dt` stops moving. Two of the three example programs that otherwise build and run on this target — `examples/bouncing_balls.rb` and `examples/fireworks.rb` — draw their opening frame correctly and then freeze, because the loop body reads `dt` inside a `balls.each do |b| … end` and the program uses a `Struct` to pair each shape with its velocity. Both are ordinary Ruby idioms, and the failure is silent: full frame rate, correct first frame, no motion.

## Environment

- Spinel commit: `e05feeb9`
- Ruby version: 4.0.6
- Platform: macOS 26 (arm64), Apple clang 21
