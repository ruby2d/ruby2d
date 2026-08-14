# [Runtime] `Array#rfind` desugars to `reverse.find`, so it iterates a snapshot and a block that empties the receiver still finds a match

Found by a Ruby-versus-Spinel differential survey while porting [Ruby 2D](https://github.com/ruby2d/ruby2d) to Spinel.

## Description

`Array#rfind` is lowered by interposing a `reverse` call and reusing the existing `find` machinery. `reverse` materializes a copy, so the loop runs over a snapshot taken before the first block call. A block that mutates the receiver is invisible to it: Spinel keeps scanning elements the array no longer holds and returns one of them.

CRuby iterates the receiver itself and stops once the index falls outside the live length, so the same program finds nothing.

This is the mirror image of [#36](36-reverse-each-reads-past-the-live-length-after-the-block-shrinks-the-array.md), and the pair is worth reading together: `reverse_each` trusts a stale length over a live receiver, `rfind` trusts a live length over a stale receiver. Neither tracks the array the block is actually mutating.

## Reproduction

```ruby
a = [1, 2, 3]
r = a.rfind { |x| a.clear; x == 2 }
p [r, a]
```

**Ruby 4.0.6:**
```
[nil, []]
```

**Spinel (42649df7):**
```
[2, []]
```

## Additional Findings

| Variant | Result |
|---|---|
| `rfind` with the block clearing the receiver | **returns `2`** where Ruby returns `nil` |
| forward `find` with the block clearing the receiver | correct — both return `nil` |
| `a.reverse.find` written out by hand | matches Spinel's `rfind`, and is the correct answer *for that program* |

The middle row is what makes this a lowering bug rather than a design choice: forward `find` already tracks the live receiver, so the two directions disagree about what the same mutation means.

## Cause

`src/analyze.c:5033` rewrites the call rather than emitting a reverse scan:

```c
if (nm && sp_streq(nm, "rfind")) {
  /* Array#rfind { block } == reverse.find { block }: interpose a reverse
     call so the existing find machinery serves it (#2320) */
```

The identity holds for a pure block, which is what #2320 needed, but not for one with side effects: `reverse` is a real materialization, so the `find` that follows walks a copy. The emitted C shows the receiver copied into `_t2` before the loop, and the loop bound reading that copy:

```c
for (mrb_int _t3 = 0; _t3 < sp_IntArray_length(_t2); _t3++) {
  mrb_int lv_x = sp_IntArray_get(_t2, _t3);
```

`lv_a` is never consulted again after the copy.

## Suggested fix

Emit `rfind` as a reverse scan over the receiver, sharing whatever live-length rule [#36](36-reverse-each-reads-past-the-live-length-after-the-block-shrinks-the-array.md) settles on, instead of desugaring through `reverse`. If the desugaring is worth keeping for its simplicity, it is only sound when the block provably cannot reach the receiver — and that is not a property the current rewrite checks.

## Impact

Silent, and rarer than #36 — `rfind` with a mutating block is an unusual thing to write. It is filed because it fixes the same contract from the other side, and because a fix for #36 that does not also cover this one leaves the two reverse iterators disagreeing.

## Environment

- Spinel commit: `42649df7`
- Ruby version: 4.0.6
- Platform: macOS 26 (arm64), Apple clang 21
