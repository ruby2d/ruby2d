# [Runtime] A `fetch`/`delete` fallback block is reduced to its tail expression and hoisted out of the branch that should guard it

Found by a Ruby-versus-Spinel differential survey while porting [Ruby 2D](https://github.com/ruby2d/ruby2d) to Spinel.

## Description

The block form of `Array#fetch`, `Hash#fetch`, `Array#delete` and `Hash#delete` is not compiled as a block. Only its **tail expression** survives, evaluated inside the else-arm of a conditional, with the block parameter assigned immediately before it.

Three things follow, and all four methods show some subset:

1. **Leading statements are dropped.** Anything before the tail expression is not emitted at all.
2. **A container-valued tail is built too early.** The emitter hoists the construction to a statement above the conditional, where the parameter has not been assigned yet, so the container captures the parameter's initial value — `nil` for a boxed parameter, `0` for an Integer one.
3. **The hoisted construction runs even when the fallback is not taken**, so a side effect inside it fires on the success path, which in Ruby never calls the block at all.

`Array#delete` additionally never assigns the parameter, so even a bare `{ |missing| missing }` returns `nil`.

The scalar forms mostly work, which is what makes this quiet: `h.fetch(k) { |key| key }` is correct, and `h.fetch(k) { |key| [key] }` is not.

## Reproduction

```ruby
p({ a: 1 }.fetch(:missing) { |key| [key] })
```

**Ruby 4.0.6:**
```
[:missing]
```

**Spinel (42649df7):**
```
[nil]
```

## Additional Findings

| Variant | Result |
|---|---|
| `{a: 1}.fetch(:missing) { \|key\| [key] }` | **`[nil]`** — parameter unbound in the hoisted container |
| `[10].fetch(3) { \|index\| [index] }` | **`[0]`** — same, with the Integer parameter's zero |
| `{a: 1}.delete(:missing) { \|key\| [key] }` | **`[nil]`** |
| `[1].delete(2) { \|missing\| missing }` | **`nil`** — parameter never assigned at all |
| a leading statement (`calls += 1`) before the tail | **dropped** — result correct, `calls` still `0` |
| the fallback **not** taken, tail `[seen << key]` | **`seen` becomes `[nil]`** — Ruby leaves it `[]`, having never called the block |
| `{a: 1}.fetch(:missing) { \|key\| key }` | correct |
| `[10].fetch(3) { \|index\| index }` | correct |
| `{a: 1}.delete(:missing) { \|key\| key }` | correct |
| `[1].delete(2) { 2 }` (no parameter) | correct |
| the key/index **present**, any form | correct |

The sixth row is the sharpest: the block runs on the path where Ruby guarantees it does not.

## Cause

The emitted C shows the shape directly. For `[10].fetch(3) { |index| [index] }` the container is built in the enclosing statement position, before the conditional:

```c
sp_IntArray *_t7 = sp_IntArray_new();
sp_IntArray_push(_t7, lv_index);          /* lv_index is still 0 here */
... (_t4 >= 0 && _t4 < _t3) ? ({ ...hit... })
                            : ({ lv_index = _t2; sp_box_nullable_obj((void *)(_t7), ...); });
```

`lv_index` is assigned in the else-arm, after `_t7` has already captured its initial value.

For the leading-statement case, `calls += 1` simply has no counterpart in the output — the else-arm is the tail expression and nothing else:

```c
else { lv_key = sp_box_sym(_t2); _t5 = lv_key; }
```

And for `Array#delete` the parameter is read but never written:

```c
({ mrb_int _t1 = sp_IntArray_delete(_t2, 2LL); _t1 != SP_INT_NIL ? sp_box_int(_t1) : lv_missing; })
```

`lv_missing` holds its declaration value, `sp_box_nil()`.

## Suggested fix

Emit the fallback as a scoped block whose body — all of it — lives inside the not-taken branch, with the parameter bound at entry. Concretely, the four call sites need a shared helper that:

1. opens a statement scope in the else-arm;
2. assigns the block parameter there;
3. emits the full body, not just the tail; and
4. yields the tail's value as the arm's result.

That also removes the hoisting, since nothing needs to be constructed before the branch is chosen. `Hash#fetch`'s scalar path already demonstrates the correct parameter binding; what is missing is a body and a scope to put it in.

Migrating the four conditional-fallback APIs together is cohesive — they share one mechanism and one regression matrix. Other block emitters should stay out of the same change.

## Impact

Silent and wrong in both directions: a value that should have come from the fallback comes back holding `nil`, and a side effect that should not have run does. `h.fetch(key) { |k| [k] }` — build a default container from the missing key — is an ordinary line to write, and it returns `[nil]`.

## Environment

- Spinel commit: `42649df7`
- Ruby version: 4.0.6
- Platform: macOS 26 (arm64), Apple clang 21
