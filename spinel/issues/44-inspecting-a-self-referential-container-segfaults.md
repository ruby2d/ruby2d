# [Runtime] Inspecting a self-referential container recurses until the stack is exhausted and **segfaults**

Found by a Ruby-versus-Spinel differential survey while porting [Ruby 2D](https://github.com/ruby2d/ruby2d) to Spinel.

## Description

`inspect` has no cycle detection. A container that reaches itself — directly, mutually, or through an object's instance variable — sends `sp_inspect_container` and `sp_poly_inspect` into unbounded mutual recursion until the stack guard page is hit.

CRuby prints the elision CRuby has always printed: `[[...]]` for an array holding itself, `{self: {...}}` for a hash, and `#<Node:0x… @peer=#<Node:0x… ...>>` for an object graph that closes.

The crash is a hard `EXC_BAD_ACCESS (code=2)` — a stack-guard hit, not a null dereference — and it takes the process down with no output, including the output already written before the `p`.

This is the shape any back-reference produces: a child that holds a pointer to the parent that holds it. Printing one while debugging is enough.

## Reproduction

```ruby
a = []
a << a
p a
```

**Ruby 4.0.6:**
```
[[...]]
```

**Spinel (42649df7):**
```
[1]    56780 segmentation fault
```

```
* thread #1, stop reason = EXC_BAD_ACCESS (code=2, address=0x16f603fc0)
    frame #0: 0x0000000100001528 cyc`sp_poly_length
->  0x100001528 <+0>: stp x24, x23, [sp, #-0x40]!
```

`code=2` is the stack guard page: the fault is exhaustion, not a bad pointer.

## Additional Findings

| Variant | Result |
|---|---|
| an Array holding itself | **segfault** |
| a Hash holding itself as a value | **segfault** |
| an object whose ivar points back at the object | **segfault** |
| two arrays holding each other (`a << b; b << a`) | **segfault** |
| `puts a.to_s` instead of `p a` | **segfault** — `to_s` routes to the same helper |

Every route into the inspect path crashes; there is no spelling that survives.

## Cause

The inspect helpers recurse with no traversal context. `sp_PolyArray_inspect` (`lib/spinel_rt.h:4269`) delegates to `sp_inspect_container`, which walks elements through `sp_poly_inspect` (`lib/spinel_rt.h:4176`), whose `SP_TAG_OBJ` arm dispatches straight back into the typed container helper:

```c
static const char *sp_PolyArray_inspect(sp_PolyArray *a) {
  if (!a) { ... return r; }
  return sp_inspect_container(sp_box_poly_array(a));
}
```

Nothing in that cycle carries a set of containers already being rendered, and there is no depth cap, so a self-referential container recurses until the stack runs out. The same applies to the Hash helpers at `lib/spinel_rt.h:4399` and `4612`, which reach `sp_inspect_container` the same way.

## Suggested fix

Give the inspect path a traversal context — the standard shape is a small thread-local stack of container pointers currently being rendered. On entry, if the container is already on it, emit the elision CRuby emits (`[...]` for an array, `{...}` for a hash, `...` for an object's ivar) and return; otherwise push, render, pop.

A depth cap alone would convert the crash into truncated output, which is better than a segfault but still not parity — the elision has to key on identity to print `[[...]]` for this program.

## Impact

A native crash on four lines of valid Ruby, reachable from any object graph with a back-reference. There is no diagnostic and no partial output, so from the program's side it looks like `p` itself killed the process — which, for a graph the developer was printing precisely because they did not yet understand it, is a hard place to start debugging.

## Environment

- Spinel commit: `42649df7`
- Ruby version: 4.0.6
- Platform: macOS 26 (arm64), Apple clang 21
