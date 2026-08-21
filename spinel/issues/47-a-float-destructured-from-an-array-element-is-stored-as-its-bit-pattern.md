# [Runtime] A Float destructured from an array element into an Integer-defaulted local is stored as its raw bit pattern

Found while porting [Ruby 2D](https://github.com/ruby2d/ruby2d) to Spinel: `Quad.new(points: [[0.5, 0], …]).width` answered a 19-digit integer.

## Description

A keyword parameter with an Integer default (`x1: 0`) is reassigned through multiple assignment from an array element (`x1, _ = points[0]`). When that element holds a Float, the local keeps its Integer type and the Float's 64 bits are stored as the integer. Everything downstream — `[@x1, @x2].max - [@x1, @x2].min` here — computes on the bit pattern: `4602678819172646912` is `0.5` read as an `int64`.

No diagnostic at this size. In a larger program the same mismatch surfaces as `error: incompatible pointer types assigning to 'sp_IntArray *' from 'sp_PolyArray *'`, which is the `-Werror` added in `77cc33c9` doing its job — the small program slips under it and answers garbage.

Destructuring `[x, y]` pairs from a `points:` array into coordinates that default to integers is the ordinary way a 2D API takes vertices.

## Reproduction

```ruby
class Quad
  def initialize(x1: 0, x2: 100, points: nil)
    if points
      x1, _ = points[0]
      x2, _ = points[1]
    end
    @x1 = x1; @x2 = x2
  end
  def width
    xs = [@x1, @x2]
    xs.max - xs.min
  end
end
puts Quad.new.width
puts Quad.new(points: [[0.5, 0], [50, 0]]).width
```

**Ruby 4.0.6:**
```
100
49.5
```

**Spinel (f13e0ada):**
```
100
4602678819172646862
```

## Additional Findings

| Variant | Result |
|---|---|
| As above | **bit pattern** |
| Integer-only points (`[[0, 0], [50, 0]]`) | correct — `50` |
| Same class, four vertices, inside a 4,500-line program | **C error**: `sp_IntArray *` local assigned an `sp_PolyArray *`, and a `sp_FloatArray *` function returning an `sp_PolyArray *` |

`4602678819172646862` is 50 less than `0.5`'s `int64` reading `4602678819172646912`: `max - min` ran on the raw bits.

## Environment

- Spinel commit: `f13e0ada`
- Ruby version: 4.0.6
- Platform: macOS 26 (arm64), Apple clang 21
