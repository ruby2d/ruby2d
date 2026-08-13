# [Compile] A stored block capturing an array of one user class is refused; the same array holding two classes compiles

Filed as [#3908](https://github.com/matz/spinel/issues/3908). Found while porting [Ruby 2D](https://github.com/ruby2d/ruby2d) to Spinel.

## Description

A block that is stored and called later — the shape of any callback registration — cannot capture a local holding an array of instances of exactly one user class. The compile stops with `unsupported closure capturing a non-integer variable (later slice)`, and the diagnostic carries no source location — `node -1 (?)`.

The boundary is the array's element homogeneity, not the capture itself: append an instance of a *second* class to the same array and the program compiles and runs. An array of `Integer` is accepted, an empty array is accepted, a bare object is accepted, and the identical block body compiles in every case when invoked immediately by `yield` instead of stored.

That inversion is the tell (cause below): the refusal fires only when the `narrow_object_arrays` optimization succeeds in promoting a monomorphic object array to its typed representation, which the closure-capture path does not recognize. The un-narrowed representation captures fine — so the more statically uniform the program, the less of it compiles.

## Reproduction

```ruby
class Item
  attr_accessor :name
end

class Callbacks
  def register(&blk)
    @blk = blk
  end

  def run
    @blk.call
  end
end

c = Callbacks.new
items = []
items << Item.new

c.register do
  puts items.size
end

c.run
```

**Ruby 4.0.6:**
```
1
```

**Spinel (e05feeb9):**
```
spinel: unsupported closure capturing a non-integer variable (later slice): node -1 (?)
```

## Additional Findings

| Variant | Result |
|---|---|
| the array holding instances of one user class | **refused** |
| the same array also holding an instance of a second user class | compiles, prints the count |
| the array holding a `Struct` instance | **refused** — a `Struct` registers as a user class |
| the array pushed into only from *inside* the stored block | **refused** |
| the array holding `Integer` | compiles |
| the array declared but never populated | compiles |
| a bare `Item.new` captured instead of an array of them | compiles |
| the same block `yield`ed instead of stored | compiles |

The second row is the sharpest edge: whether a program compiles depends on how many classes its collection happens to hold. In Ruby 2D this is every callback registration over the scene's shape list — an app drawing only `Square`s is refused, and the same app also drawing a `Circle` compiles.

## Cause

The refusal is the composition of an optimization with a capture path that predates it.

- `items` is first typed `TY_POLY_ARRAY`. The post-fixpoint `narrow_object_arrays` pass then narrows a monomorphic object array to `TY_OBJ_ARRAY_BASE + class` (`src/types.h:154`), the unboxed `sp_PtrArray` representation. The pass is documented as conservative-only: "Produced ONLY by the conservative post-fixpoint narrow_object_arrays pass, never by forward inference."
- When the block is stored, each captured local becomes a heap cell (`src/codegen.c:1008`). A cell is supported for the scalar kinds, float, poly, and any kind `cell_is_typed_ptr` accepts (`src/codegen.c:2519`), which delegates to `proc_slot_is_ptr`: the enumerated builtin handles plus `ty_is_array(t) || ty_is_hash(t) || ty_is_object(t)`.
- None of the three covers the narrowed kind: `ty_is_array` (`src/types.c`) enumerates exactly `TY_INT_ARRAY`, `TY_FLOAT_ARRAY`, `TY_STR_ARRAY`, `TY_POLY_ARRAY`, `TY_INT_ARRAY_ARRAY`, and `ty_is_object` stops below `TY_OBJ_ARRAY_BASE` (`src/types.h:157`). The capture falls through to `unsupported(...)` at `src/codegen.c:1012`.

The two-class variant compiles because a mixed array never leaves `TY_POLY_ARRAY`, which `ty_is_array` accepts and the cell path already handles.

## Suggested fix

Either of the first two closes it; they differ in whether the optimization survives being captured.

1. Decline to narrow a captured local: have `narrow_object_arrays` skip a local that is marked captured-by-stored-proc (`is_cell`). The array stays `TY_POLY_ARRAY`, and the two-class variant demonstrates the exact working codegen that results. Smallest change, and legal by the pass's own conservative-only contract; costs the typed-element optimization inside stored blocks.
2. Support the typed capture: include the `ty_is_ptr_array` kinds in `proc_slot_is_ptr`, giving the cell a real `sp_PtrArray *` element type and `sp_cell_scan_ptr`. Keeps the optimization at the cost of touching the cell-emission and element-cast paths.
3. Independently of which: the diagnostic should name the variable and its capture site. `unsupported` here receives `s->def_node`, which a stored proc does not have, so the message prints `node -1 (?)` and a large program has to be bisected by hand to find which closure is meant.

## Environment

- Spinel commit: `e05feeb9`
- Ruby version: 4.0.6
- Platform: macOS 26 (arm64), Apple clang 21
