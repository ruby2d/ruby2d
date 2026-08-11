# [Codegen] A forwarded block's callee resolves to the first same-named method, losing captures when that one is another forwarder

Found while porting [Ruby 2D](https://github.com/ruby2d/ruby2d) to Spinel.

## Description

Follow-up to [#3783](https://github.com/matz/spinel/issues/3783), whose reproduction passes at `489cbde7`. The same loss of captured locals still happens when more than one method shares the forwarded name.

When the escape analysis cannot resolve a forwarded block's callee from the receiver, it falls back to matching by method name and takes the first scope it finds. If several methods share that name, the first one is not necessarily the callee — and when it is another forwarder, the forward is judged harmless, the block is inlined, and its captures are never celled.

The result is that the same program compiles correctly or incorrectly depending on the **order the classes are defined in**.

## Reproduction

```ruby
class Decoy
  def store(&b); b.call; end          # same name, takes a block, does NOT store it
end

class Holder
  def store(&b); @proc = b; end
  def run; @proc.call; end
end

module Registry
  def self.holder; @holder ||= Holder.new; end
end

def forward(&b); Registry.holder.store(&b); end

n = 0
forward { n += 1 }
3.times { Registry.holder.run }
puts "n=#{n}"
```

**Ruby 4.0.6:**
```
n=3
```

**Spinel (489cbde7):**
```
n=0
```

Moving `class Decoy` below `class Holder`, changing nothing else, prints `n=3`.

## Additional Findings

`Decoy` is never instantiated and its `store` is never called. Its presence in the source, ahead of `Holder`, is the whole difference — dead code changes the compiled behaviour of a live path.

The receiver has to be unresolvable for the name fallback to run at all. `Registry.holder` is a call, so `infer_type` gives no object and the node is neither `ConstantReadNode` nor `ConstantPathNode`. With a receiver the pass can resolve — a local holding a `Holder`, for instance — the correct callee is found and both orderings work. Dropping `Decoy` entirely also works, leaving `Holder#store` as the only candidate.

Twenty-one other variations were tried before this one and all behave correctly at `489cbde7`, so the ambiguity appears to be the whole trigger: repeated invocation, an ivar initialized to `nil`, the arity read before storing, two callbacks stored on one object, an arity-dependent `call` vs `call(dt)`, a receiver from a module accessor, a bare same-named call that never executes, and two forwarding shims side by side.

In Ruby 2D this is reached through an ordinary DSL callback. The library defines four methods named `update` that take a block — a top-level shim, `Ruby2D::DSL#update`, `Window::ClassMethods#update`, and `Window#update` — of which only `Window#update` stores it, and it is not the first. Every `update { }` block therefore runs each frame against a copy of its captured locals, so counters and accumulators stay at their initial values with no error.

## Cause

`src/analyze.c`, in the callee resolution added by [`0780e65a`](https://github.com/matz/spinel/commit/0780e65a):

```c
if (fmi < 0) {
  for (int si = 1; si < c->nscopes; si++) {
    Scope *cs3 = &c->scopes[si];
    if (cs3->is_cmethod || !cs3->name || !sp_streq(cs3->name, fn)) continue;
    if (!cs3->blk_param || !cs3->blk_param[0]) continue;
    fmi = si; break;
  }
}
```

The comment there notes the fallback is safe because at worst it leaves a forwarder uninlined. That holds when the guess is a method that keeps the block. When the guess is another forwarder the error goes the other way: a block that really is stored gets inlined, and its writes to enclosing locals are lost.

This is the same shape as [`28b4e9f9`](https://github.com/matz/spinel/commit/28b4e9f9) *"Keep two name-based heuristics from tripping over an unrelated class"* (refs #3781), where bundling `csv` changed unrelated inference because two checks asked "does ANY user class define this name?". This is a third such site: it asks "is there ANY block-taking method with this name?", and an unrelated class answering first decides the question.

## Suggested fix

One option, offered to show the cause is reachable rather than to propose the design — resolving a call receiver like `Registry.holder` would fix it closer to the source. This one stops guessing instead: treat an ambiguous forward as an escape rather than picking a candidate.

```diff
         if (fmi < 0) {
+          int nmatch = 0;
           for (int si = 1; si < c->nscopes; si++) {
             Scope *cs3 = &c->scopes[si];
             if (cs3->is_cmethod || !cs3->name || !sp_streq(cs3->name, fn)) continue;
             if (!cs3->blk_param || !cs3->blk_param[0]) continue;
-            fmi = si; break;
+            if (nmatch++ == 0) fmi = si;
+            else break;
           }
+          if (nmatch > 1) fmi = BLK_FWD_AMBIGUOUS;
         }
```

with `BLK_FWD_AMBIGUOUS` (-2) handled where the callee is consulted:

```diff
       else if (blk_arg_expr && blk_arg_expr[id] && blk_fwd_callee) {
         int callee = blk_fwd_callee[id];
-        if (callee >= 0 && callee < c->nscopes) {
+        if (callee == BLK_FWD_AMBIGUOUS) escapes = 1;
+        else if (callee >= 0 && callee < c->nscopes) {
```

With this applied: the reproduction above prints `n=3` in both orderings, Ruby 2D's callbacks work with its workaround removed, and `make test` reports no failures and no errors (2853 tests, measured at `28b4e9f9`).

It leaves more forwarders uninlined than before — the same cost the single-match fallback already accepts, but incurred more often. That has not been measured.

## Environment

- Spinel commit: `489cbde7`
- Ruby version: 4.0.6
- Platform: macOS 26 (arm64), Apple clang 21
