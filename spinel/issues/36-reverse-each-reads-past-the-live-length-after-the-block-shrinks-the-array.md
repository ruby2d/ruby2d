# [Runtime] `reverse_each` hoists the receiver's length before the loop, so a block that shrinks the array is yielded the freed slots

Found by a Ruby-versus-Spinel differential survey while porting [Ruby 2D](https://github.com/ruby2d/ruby2d) to Spinel.

## Description

`Array#reverse_each` reads the receiver's length once, before the loop, and counts down from it. The receiver itself is read live. When the block shrinks the array, the remaining indices are stale: the loop keeps indexing a shorter array and yields whatever the out-of-bounds read returns.

For an Integer or String array that is the element type's nil sentinel, so the block is handed `nil` where Ruby stops iterating. For an array of a user class the read still succeeds, so the block simply runs too many times.

Forward `each` is correct, because its loop condition re-evaluates the length on every iteration. The divergence is only in the reverse direction.

Removing entities from a list while walking it backwards is the ordinary way to write that loop — walking backwards is *why* you'd choose `reverse_each` for it — so this fires on the pattern the method exists to serve.

## Reproduction

```ruby
a = [1, 2, 3]
seen = []

a.reverse_each do |x|
  seen << x
  a.clear if x == 3
end

p [seen, a]
```

**Ruby 4.0.6:**
```
[[3], []]
```

**Spinel (42649df7):**
```
[[3, nil, nil], []]
```

## Additional Findings

| Variant | Result |
|---|---|
| `a.clear` in `reverse_each` over `Integer` | **yields `nil` twice more** |
| the same over `String` | **yields `nil` twice more** (`[["z", nil, nil], []]`) |
| the same over instances of a user class | **runs the block 3 times instead of once** — no `nil`, just extra iterations |
| `a.pop` instead of `a.clear` | correct — one slot lost, and the countdown never reaches it |
| forward `each` with `a.clear` | correct |
| `a.reverse.each` with `a.clear` | correct — `reverse` materializes a copy |

The user-class row is the one to read first: there is no `nil` to notice, so the block runs against elements the program already removed.

## Cause

`src/codegen_iter.c:2871` emits the length into a temporary *before* the loop when the iterator is reversed, and `src/codegen_iter.c:2873` counts down from that temporary:

```c
if (rev) { ... buf_printf(b, "mrb_int _t%d = sp_%sArray_length(%s);\n", tn, k, rb.p); }
...
if (rev) buf_printf(b, "for (mrb_int _t%d = _t%d - 1; _t%d >= 0; _t%d--) {\n", t, tn, t, t);
else {
  buf_printf(b, "for (mrb_int _t%d = 0; _t%d < sp_%sArray_length(", t, t, k);
  buf_puts(b, rb.p); buf_printf(b, "); _t%d++) {\n", t);
}
```

The forward arm re-reads `sp_*Array_length(recv)` in the condition on every iteration; the reverse arm reads it once. The element fetch below uses the live receiver in both. The emitted C for the reproduction is:

```c
mrb_int _t3 = sp_IntArray_length(lv_a);
for (mrb_int _t2 = _t3 - 1; _t2 >= 0; _t2--) {
  lv_x = sp_IntArray_get(lv_a, _t2);
```

After `a.clear`, `lv_a` has length 0 while `_t3` is still 3.

## Suggested fix

Bound the reverse loop by the live length as the forward arm already does — clamp the index each iteration rather than trusting the hoisted bound:

```c
for (mrb_int _t2 = sp_IntArray_length(lv_a) - 1; _t2 >= 0; _t2--) {
  if (_t2 >= sp_IntArray_length(lv_a)) continue;
```

or equivalently re-read the length at the top of the body and `break` when the index no longer addresses a live slot. CRuby's `reverse_each` re-checks the length on each step and stops when the index falls outside it, which is what makes the reproduction print `[[3], []]`.

## Impact

Silent. The Integer and String forms hand the block a `nil` that usually surfaces later as a `NoMethodError` somewhere else, and the user-class form produces no diagnostic at all — the block just runs against removed elements.

## Environment

- Spinel commit: `42649df7`
- Ruby version: 4.0.6
- Platform: macOS 26 (arm64), Apple clang 21
