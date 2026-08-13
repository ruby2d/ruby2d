# [Compile] A stored block capturing an array of objects is refused: "unsupported closure capturing a non-integer variable"

Found while porting [Ruby 2D](https://github.com/ruby2d/ruby2d) to Spinel.

## Description

A block that is stored and called later — the shape of any callback registration — cannot capture a local holding an array of user-class instances. The compile stops with `unsupported closure capturing a non-integer variable (later slice)`.

An array of `Integer` is accepted, an array that is never populated is accepted, and a bare object rather than an array is accepted. The same block invoked immediately, by `yield` or through `&blk`, is accepted in every case. It is specifically the combination: a block that outlives the call that registered it, capturing an array whose elements are objects.

The diagnostic carries no source location — `node -1 (?)` — so in a program of any size there is nothing to point at.

## Reproduction

```ruby
class Box
  attr_accessor :color
end

class Loop
  def update(&blk)
    @blk = blk
  end

  def tick
    @blk.call
  end
end

l = Loop.new
shapes = []
shapes << Box.new

l.update do
  puts shapes.size
end

l.tick
```

**Ruby 4.0.6:**
```
1
```

**Spinel (83d1315d):**
```
spinel: unsupported closure capturing a non-integer variable (later slice): node -1 (?)
```

## Additional Findings

| Variant | Result |
|---|---|
| the array holding a user-class instance | **refused** |
| the array holding a `Struct` instance | **refused** |
| the captured array only asked its `size`, never indexed | **refused** |
| the captured array indexed and mutated inside the block | **refused** |
| the array passed from the block to a method, rather than used in it | **refused** |
| the array holding `Integer` | compiles, prints `1` |
| the array declared but never populated | compiles, prints `0` |
| a bare `Box.new` captured instead of an array of them | compiles |
| the same block `yield`ed instead of stored | compiles |
| the same block taken as `&blk` and called before returning | compiles |

The last two rows are the ones that bound it: nothing about the block's *body* is unsupported, since the identical body compiles when the block is called immediately. It is storing the block that makes the capture unsupported.

The `Integer` row and the never-populated row together suggest the check is on the captured array's element type rather than on the array itself, which the message's wording — "a non-integer variable" — also points at.

**The boundary is not fully characterized.** A real program that registers a per-frame callback capturing an array of objects and pushes into it *from inside* that callback does compile, so something in that arrangement avoids the check. The reproduction above is the smallest shape found that fails, not a complete account of when the check fires.

## Suggested fix

Two things, of which the second is useful even if the first is a longer job:

1. Support the capture. A stored block capturing an array of objects is what every callback registration looks like — `on_click`, `update`, an observer list — so the shape is hard to design around: the array has to become a constant or an ivar purely to avoid being captured.
2. Give the diagnostic a source location. `node -1 (?)` means a large file has to be bisected by hand to find which closure is meant; every other unsupported-construct message in the compiler names its node and line.

## Environment

- Spinel commit: `83d1315d`
- Ruby version: 4.0.6
- Platform: macOS 26 (arm64), Apple clang 21
