# [Codegen] A user class defining `length` turns `empty?` on a poly receiver into an unconditional `NoMethodError`

Filed as [#3805](https://github.com/matz/spinel/issues/3805). Found while porting [Ruby 2D](https://github.com/ruby2d/ruby2d) to Spinel.

## Description

`empty?` on a polymorphic receiver normally lowers to the generic builtin form, `sp_poly_length(recv) == 0`. Define a method named **`length`** on any user class in the program and that lowering is skipped: the call is emitted as an unconditional `sp_raise_cls("NoMethodError", …)` with no dispatch and no runtime check, so it fires whatever the receiver actually is.

The user class does not have to be related to the receiver, to be instantiated, or to be referenced again. Its presence anywhere in the program is enough.

This is the residue of [#1438](https://github.com/matz/spinel/issues/1438), whose reproduction passes at `83d1315d`. That issue was about a user class defining `empty?`; the fix added builtin arms to the poly `empty?` dispatch. The check that decides whether to skip the generic lowering asks about `length`, while the dispatch that is supposed to catch the fall-through is keyed on `empty?` — so a program defining `length` but not `empty?` falls between the two.

## Reproduction

```ruby
class Sized
  def length
    0
  end
end

opts = { n: 1, list: [2] }
puts opts[:list].empty?
```

**Ruby 4.0.6:**
```
false
```

**Spinel (83d1315d):**
```
undefined method 'empty?' for an instance of Array (NoMethodError)
```

## Additional Findings

**The emitted C shows the two lowerings.** Removing `class Sized` is the only change between them:

```c
// without the user class — generic builtin lowering, correct:
puts(((sp_poly_length(sp_SymPolyHash_get(lv_opts, ((sp_sym)1))) == 0)) ? "true" : "false");

// with it — an unconditional raise, no switch at all:
puts(((sp_raise_cls("NoMethodError", sp_nomethod_msg_args("empty?", sp_SymPolyHash_get(lv_opts, ((sp_sym)2)), 0, (sp_RbVal[]){sp_box_nil()})), 0)) ? "true" : "false");
```

| Variant | Result |
|---|---|
| user class defines `length`, poly receiver | **raises** |
| no user class in the program | prints `false` |
| user class defines `length` **and** `empty?` | prints `false` |
| `length` exposed as `attr_reader :length` rather than `def` | **raises** |
| user class defines `size` instead of `length` | prints `false` |
| receiver is a String rather than an Array — `{ n: 1, s: 'ab' }` | **raises** |
| typed receiver, `[2].empty?` | prints `false` |
| `.length` on the same poly receiver | prints `1` |
| `.size` on the same poly receiver | prints `1` |

The last three lines are the sharp contrast: on the *same* receiver in the *same* program, `length` and `size` resolve correctly and only `empty?` raises. The receiver has to be poly — a typed one is unaffected.

## Cause

`src/codegen_call_recv.c`, in the poly-receiver builtin lowering for `length` / `size` / `empty?`:

```c
int has_user_len = 0;
const char *lcheck = (sp_streq(name, "empty?")) ? "length" : name;
...
for (int kk = 0; kk < c->nclasses && !has_user_len; kk++)
  if (comp_method_in_chain(c, kk, lcheck, NULL) >= 0 ||
      comp_reader_in_chain(c, kk, lcheck, NULL)) has_user_len = 1;
if (sp_streq(name, "empty?") && !has_user_len)
  for (int kk = 0; kk < c->nclasses && !has_user_len; kk++)
    if (comp_method_in_chain(c, kk, "empty?", NULL) >= 0) has_user_len = 1;
if (!has_user_len) {
  /* generic lowering: (sp_poly_length(recv) == 0) */
}
```

For `empty?`, `lcheck` is `"length"`, so any user class owning `length` — by `def` or by a reader, which is what the surrounding comment is guarding against — sets `has_user_len` and skips the generic lowering. Control then reaches the poly dispatch emitter, which builds its `switch (cls_id)` from classes owning the name actually called, `empty?`. There are none, so no switch is emitted and the call collapses to the raise.

The builtin arms added for #1438 live inside that dispatch, in `src/codegen_call.c` under `if (is_empty)`, so they are not reached either. The comment a few lines below them states the invariant this breaks:

> That is the invariant -- a user class owning a name must not change what a builtin receiver does -- and it holds for every name the surface serves, not a list maintained here.

That holds within the dispatch. The `empty?` → `length` widening one level up is where a user class owning a name still changes what a builtin receiver does.

## Suggested fix

The two checks need to agree on a name. Either consult `empty?` when deciding whether to skip the generic lowering and let the reader case be handled inside the dispatch, or keep the `length` widening and emit the dispatch whenever it fires, so the `if (is_empty)` builtin arms serve the call. The second preserves what the `lcheck` widening was added for — a class exposing `length` as a reader getting its own `empty?` semantics — while restoring the builtin path for every other receiver.

Nearest prior art, both closed and both passing at `83d1315d`: [#1438](https://github.com/matz/spinel/issues/1438) (a user `empty?` dropping the builtin arms) and [#3459](https://github.com/matz/spinel/issues/3459) (poly dispatch over builtin | user class losing the builtin arm). This is the same family — a user class changing what a builtin receiver does — reached through a different name.

## Environment

- Spinel commit: `83d1315d`
- Ruby version: 4.0.6
- Platform: macOS 26 (arm64), Apple clang 21
