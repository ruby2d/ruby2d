# [Design] Method resolution is re-derived at each emission site, and the write path never asks the method table

**Status:** research notes

Found while porting [Ruby 2D](https://github.com/ruby2d/ruby2d) to Spinel. This is a meta-issue over several already-filed bugs rather than a new reproducer — closing it means closing a gap between two code paths that both already exist, not redesigning anything.

## Description

Twenty-nine reproducers came out of this port. Most are unrelated. Four are the same bug wearing different clothes, and three more are the same shape in adjacent machinery — which is worth one issue rather than seven, because each has been fixed correctly and locally, and the next emission site to grow a dispatch will start from zero again.

The shared mechanism: **a call site has two possible lowerings — a proved one and a boxed one — and each derives method resolution independently.** The bugs are where the two derivations disagree. There is no function that answers "what does name `N` mean on receiver `R`"; there are two table queries, `comp_method_in_chain` (`src/compiler.c:440`) and `comp_reader_in_chain` (`src/compiler.c:957`), and roughly forty and fifty-six call sites respectively, each composing its own policy out of them.

## The four

| Issue | What diverged |
|---|---|
| [#3805](https://github.com/matz/spinel/issues/3805) | `empty?` on a boxed receiver became an unconditional raise once any class in the program owned `length` — the guard consulted the method table but not the reader table |
| [#3806](https://github.com/matz/spinel/issues/3806) | `delete` on a boxed receiver lowered to `String#delete` — resolution matched a builtin ahead of the user's method |
| draft 27 | An override of an inherited `attr_reader` is *dispatched* through the method table and *typed* through the reader entry, so the emitted C disagrees with itself in one statement |
| draft 29 | An attribute write on a boxed receiver is built from the writer table alone, gets no arm for a method-defined writer, and is silently discarded |

Three more are the same shape in different machinery, listed for the pattern rather than as part of the ask: [#3807](https://github.com/matz/spinel/issues/3807) (`equal?` constant-folded on the proved path where the boxed path answers correctly), and [#3790](https://github.com/matz/spinel/issues/3790) and [#3810](https://github.com/matz/spinel/issues/3810) (a boxed key reaching a String-keyed Hash without a tag check).

## Where it comes from

`src/codegen_call_recv.c` carries twenty-two hand-rolled resolution guards, one per builtin name that a user class might shadow — `has_user_cnt`, `has_user_rnd`, `has_user_dig`, `has_user_len`, and so on. Each is separately responsible for remembering to consult both tables, and the comment above `has_user_len` (`src/codegen_call_recv.c:10238`) is [#3805](https://github.com/matz/spinel/issues/3805) written up by the person who fixed it:

> `has_user_len` must also consult `comp_reader_in_chain`: a user class's `.size`/`.length` is very often an attr_reader/attr_accessor — or a Struct member, which registers the same way — rather than a `def` method. `comp_method_in_chain` alone missed those…

That is the whole family in one sentence. The policy is correct; it just has to be retyped at each site, and twenty-two chances to retype it correctly is twenty-two chances not to.

## The write path specifically

`src/codegen_stmt.c` has two polymorphic-write emitters, and they are not guarded alike.

The typed-receiver one (line 5947) asks the method table first and only falls back to attribute dispatch:

```c
else if (comp_method_in_chain(c, ty_object_class(rt), nm, NULL) < 0) {
  /* writer not in chain and no explicit method: try subclass dispatch via cls_id */
```

The boxed-receiver one (line 5988, `else if (rt == TY_POLY)`) has no such guard. It goes straight to `comp_is_writer` (line 6012) and never consults the method table at all. And `comp_is_writer` cannot answer the question:

```c
int comp_is_writer(ClassInfo *ci, const char *name) { return name_in(ci->writers, ci->nwriters, name); }
```

`writers[]` is populated from four places — `attr_writer`/`attr_accessor` (`src/analyze_scope.c:1618`), `Struct` members (1242, 1252), module inclusion (3307), and superclass copy (3832). A hand-written `def x=` never enters it, so a class defining its writer by hand is structurally absent from the switch. Unlike its reader counterpart the predicate is also not chain-aware.

There is a second way an arm disappears, in the same loop (line 6019): a class whose ivar slot type cannot hold the concrete right-hand side is `continue`d past, so even an attribute-backed class can silently drop out on a type mismatch.

## Fail-open versus fail-closed

The read dispatch closes its switch with a raising default, and the comment explaining why is the argument this issue is making (`src/codegen_call.c:4408`):

> Nothing claimed the fallthrough: the value is not one of the enumerated classes and no pre-arm recognised its tag, so it does not answer this method. Raise, as every other unresolved call does. Leaving the slot at its zero handed callers a NULL container that read back as empty — `str.split.join(" ")` answered `""` once a user class owned `split` (#3394), which is the silent form of the same gap.

Both write emitters close with a bare `" } }\n"` (lines 5977 and 6026). So on the write side a resolution miss is not an error — it is a no-op. A receiver that genuinely does not respond to the name is swallowed the same way, with no `NoMethodError`.

That difference is what makes this cluster expensive out of proportion to its size. A refusal costs an afternoon. Draft 29 compiles clean, runs clean, draws a window, and quietly discards every `shape.x = …` on an object held in an array — and it passed all five of the checks this port runs, because each asks whether something compiles, runs or draws, and none asks whether it behaves the way it does on CRuby.

## Suggested fix

Three, in increasing size. The first two are small and would between them have prevented all four.

1. **Give both write emitters in `src/codegen_stmt.c` the raising default the read emitter got in #3394.** Smallest possible change, and it converts this whole class from silent-wrong to loud-wrong. Draft 29 would have crashed on the first frame instead of hiding.

2. **Guard the boxed write path with `comp_method_in_chain` the way its typed sibling at line 5947 already is**, and emit a call arm for classes whose writer is a method rather than an attribute. This is draft 29 directly, and it makes the two write paths agree with each other.

3. **Longer term, one resolution function** — something shaped like `resolve(class_id, name, READ|WRITE)` returning *method*, *attribute*, or *none* — that every emission site calls instead of composing its own answer. That is what would retire the twenty-two `has_user_*` guards and stop the next dispatch site from starting over. Not proposed as urgent; proposed as the thing that makes 1 and 2 the last of their kind.

## Environment

- Spinel commit: `84f5a236`
- Ruby version: 4.0.6
- Platform: macOS 26 (arm64), Apple clang 21
