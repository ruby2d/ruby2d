# [Design] Method resolution is re-derived independently at each emission site

**Status:** research notes

Filed as [#3910](https://github.com/matz/spinel/issues/3910). Found while porting [Ruby 2D](https://github.com/ruby2d/ruby2d) to Spinel. This is a meta-issue over several already-filed bugs rather than a new reproducer: it documents a mechanism those bugs share, so it can be closed by closing the gap between code paths that already exist.

## Description

Thirty reproducers came out of this port. Most are unrelated. Four share one mechanism, and three more show the same shape in adjacent machinery. Each instance so far has been fixed correctly and locally; this issue records the shared mechanism so the next emission site does not have to rediscover it.

The mechanism: **a call site has two possible lowerings — a proved one and a boxed one — and each derives method resolution independently.** The bugs are where the two derivations disagree. There is no single function that answers "what does name `N` mean on receiver `R`"; there are three chain queries — `comp_method_in_chain` (`src/compiler.c:445`, ~368 uses), `comp_reader_in_chain` (`:962`, ~55 uses), and the recently added `comp_writer_in_chain` (`:968`, 18 uses) — plus the non-chain-aware `comp_is_writer` (`:828`), and each emission site composes its own policy from them.

## The family

| Report | Status at `e05feeb9` | What diverged |
|---|---|---|
| [#3805](https://github.com/matz/spinel/issues/3805) | fixed | `empty?` on a boxed receiver became an unconditional raise once any class owned `length` — the guard consulted the method table but not the reader table |
| [#3806](https://github.com/matz/spinel/issues/3806) | fixed | `delete` on a boxed receiver lowered to `String#delete` — resolution matched a builtin ahead of the user's method |
| [#3909](https://github.com/matz/spinel/issues/3909) | reproduces (segfault) | dispatch of an attr override now arbitrates reader-vs-method (`codegen_call_recv.c:8554`) but the expression's *type* still comes from the reader entry — the emitted C calls the override and casts its `mrb_int` result to `const char *` in one statement |
| [#3907](https://github.com/matz/spinel/issues/3907) | reproduces (silent) | the boxed write switch is built from `comp_is_writer` alone: no arm for a `def x=` class, no `default`, so the store is discarded without a `NoMethodError` |

Three more show the same shape in different machinery, listed for the pattern only (all since fixed): [#3807](https://github.com/matz/spinel/issues/3807) (`equal?` constant-folded on the proved path where the boxed path answers correctly), [#3790](https://github.com/matz/spinel/issues/3790) and [#3810](https://github.com/matz/spinel/issues/3810) (a boxed key reaching a String-keyed Hash without a tag check).

## Recent fixes have each re-implemented the same policy

- [#3805](https://github.com/matz/spinel/issues/3805)'s fix taught `has_user_len` to also consult the reader table. Its comment states the general rule: *"`has_user_len` must also consult `comp_reader_in_chain`: a user class's `.size`/`.length` is very often an attr_reader/attr_accessor … `comp_method_in_chain` alone missed those."* Ten `has_user_*` guards remain in `src/codegen_call_recv.c`, each separately responsible for applying it.
- The boxed read emitter arbitrates reader-vs-method with a more-derived-wins chain walk (`src/codegen_call_recv.c:8554`).
- The typed write emitter performs the same arbitration again — `comp_writer_in_chain` vs `comp_method_in_chain`, more-derived wins, same-class tie to the explicit `def` (`src/codegen_stmt.c:5901-5913`).
- `0da7012c` memoized `an_user_defines_or_reads` after measuring 388.7 million `comp_method_in_chain` calls compiling one program.

[#3909](https://github.com/matz/spinel/issues/3909) is a site that has the dispatch half of the policy but not the typing half; [#3907](https://github.com/matz/spinel/issues/3907) is a site that predates the policy entirely.

## Fail-open versus fail-closed

The read dispatch closes its switch with a raising default; the comment on the #3394 fix explains why (`src/codegen_call.c`):

> Nothing claimed the fallthrough: the value is not one of the enumerated classes and no pre-arm recognised its tag, so it does not answer this method. Raise, as every other unresolved call does. Leaving the slot at its zero handed callers a NULL container that read back as empty — `str.split.join(" ")` answered `""` once a user class owned `split` (#3394), which is the silent form of the same gap.

Both write emitters close with a bare `" } }\n"` instead, so on the write side a resolution miss is a no-op rather than an error. At `e05feeb9`, a boxed receiver that does not respond to `x=` at all runs past the assignment where CRuby raises `NoMethodError`.

The two failure modes are not equivalent in practice. An unsupported diagnostic or a raise is caught the first time the program runs. [#3907](https://github.com/matz/spinel/issues/3907) compiles, runs, and draws, and was found only by comparing program output against CRuby — it passed all five of this port's build-and-run checks.

## Suggested fix

Three items, increasing in size. If the preferred route for 1 and 2 is to land them as part of [#3907](https://github.com/matz/spinel/issues/3907)'s fix, this issue can close with it; only 3 needs a decision of its own.

1. **Give both write emitters in `src/codegen_stmt.c` the raising default the read emitter received in #3394.** This converts the write-side silent no-op into a `NoMethodError`.

2. **Drive the boxed write switch through the arbitration the typed emitter already has** (`codegen_stmt.c:5901-5913`): per candidate class, an arm calling `sp_<Class>_x_set` where the method wins, an ivar store where the attr wins. This is [#3907](https://github.com/matz/spinel/issues/3907)'s fix, and it makes the two write paths agree with each other.

3. **Longer term: one resolution function** — shaped like `resolve(class_id, name, READ|WRITE)` returning *method*, *attribute*, or *none* — called by every emission site instead of each composing its own answer. The pieces exist (`comp_writer_in_chain`, the chain-walk arbitration, the `an_user_defines_or_reads` memo); consolidating them would retire the remaining `has_user_*` guards. Not urgent, and worth doing only if the maintainers agree the consolidation carries its weight.

## Environment

- Spinel commit: `e05feeb9`
- Ruby version: 4.0.6
- Platform: macOS 26 (arm64), Apple clang 21
