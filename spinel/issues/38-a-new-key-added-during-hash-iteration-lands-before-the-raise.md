# [Runtime] A key added during `Hash#each` is inserted before the guard raises, so the rescued hash keeps the key CRuby refused

Found by a Ruby-versus-Spinel differential survey while porting [Ruby 2D](https://github.com/ruby2d/ruby2d) to Spinel.

## Description

Spinel raises the right error for adding a key during `Hash#each` — `RuntimeError: can't add a new key into hash during iteration` — but raises it one step too late. The guard is emitted in the loop's advance clause, which runs *after* the block body, so the insertion has already happened by the time the check fires.

CRuby refuses the insertion itself: the key never lands. Spinel refuses the *iteration*, and leaves the key behind. A program that rescues the `RuntimeError` therefore continues with a hash CRuby would never have produced.

## Reproduction

```ruby
h = { a: 1, b: 2 }

begin
  h.each { |k, _| h[:c] = 3 }
rescue RuntimeError => e
  puts e.class
end

p h
```

**Ruby 4.0.6:**
```
RuntimeError
{a: 1, b: 2}
```

**Spinel (42649df7):**
```
RuntimeError
{a: 1, b: 2, c: 3}
```

## Additional Findings

| Variant | Result |
|---|---|
| adding a new key during `each` | **raises, and the key is still there** |
| deleting the current key during `each` | correct — both end `{a: 1}` |
| assigning to an *existing* key during `each` | correct — both end `{a: 99, b: 2}`, no raise |

The last two rows show the surrounding contract is right; only the ordering of the new-key guard is wrong.

## Cause

`src/codegen_iter.c:2161`-`2163` places the guard in the third clause of the `for`, alongside the index advance:

```c
buf_printf(b, "for (mrb_int _t%d = 0; _t%d < %s->len; ", t, t, rb.p);
buf_printf(b, "({ if (%s->len > _t%d) sp_raise_cls(\"RuntimeError\","
              " \"can't add a new key into hash during iteration\"); ", rb.p, tn0);
```

`_t<tn0>` is the length captured before the loop. The comparison is therefore "did the body grow the hash", asked once the body has finished — a detector, not a guard. The comment above it is explicit that the shape exists to keep `next` working as a C `continue` (#3782), which is why the check ended up in the advance clause rather than at the mutation site.

## Suggested fix

Raise where the insertion happens rather than where it is noticed: have the hash `[]=` path check an "iterating" flag on the hash and refuse a *new* key while it is set, leaving updates to existing keys alone. That is the CRuby rule, and it keeps the current advance-clause logic free to do only what #3782 needs it to do.

If a per-hash flag is too invasive, the weaker fix is to move the length comparison to the top of the loop body and raise before the block runs — that still lets one insertion land, so it is not parity, but it stops the raise from reporting a state the program can then observe.

## Impact

Narrow, and loud enough to notice — the error class and message are already correct. It matters only for a program that rescues the `RuntimeError` and keeps going, which then diverges from CRuby by exactly the keys the guard was supposed to prevent.

## Environment

- Spinel commit: `42649df7`
- Ruby version: 4.0.6
- Platform: macOS 26 (arm64), Apple clang 21
