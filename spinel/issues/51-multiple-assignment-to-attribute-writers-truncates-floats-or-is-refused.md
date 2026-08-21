# [Runtime] Multiple assignment to attribute writers truncates Floats to Integers on a Struct, and is refused on a user class

Found while porting [Ruby 2D](https://github.com/ruby2d/ruby2d) to Spinel: a flocking example reseeds a boid's velocity with `d.vx, d.vy = random_velocity`.

## Description

`a.x, a.y = pair` — multiple assignment whose targets are attribute writers — goes wrong two ways depending on the receiver. On a `Struct`, it compiles and stores each Float's integer part: `1.5, -2.5` arrive as `1, -2`, with no diagnostic. On an instance of an ordinary class with `attr_accessor`, the build is refused: `unsupported multiple assignment call target non-object: node N (MultiWriteNode)`.

The same values through two plain assignments (`a.vx = v[0]; a.vy = v[1]`) are stored correctly on both receivers, and multiple assignment to locals (`vx, vy = random_velocity`) is correct. It is the combination of a multiple assignment and call targets.

Destructuring a pair into two setters is ordinary Ruby — it is how a method that returns `[x, y]` lands on an object that stores `x` and `y` separately.

## Reproduction

```ruby
S = Struct.new(:vx, :vy)
def random_velocity = [1.5, -2.5]
s = S.new(0, 0)
s.vx, s.vy = random_velocity
p [s.vx, s.vy]
```

**Ruby 4.0.6:**
```
[1.5, -2.5]
```

**Spinel (f13e0ada):**
```
[1, -2]
```

## Additional Findings

| Variant | Result |
|---|---|
| As above (`Struct` receiver) | **`[1, -2]`** — Floats truncated, no diagnostic |
| Receiver is a class with `attr_accessor :vx, :vy` | **refused**: `unsupported multiple assignment call target non-object (MultiWriteNode)` |
| `s.vx = v[0]; s.vy = v[1]` (two plain assignments) | correct on both receivers |
| `vx, vy = random_velocity` (local targets) | correct |
| `Struct.new(:vx, :vy)` constructed with Floats (`S.new(0.0, 0.0)`) | **`[1, -2]`** — the member's declared type is not the cause |

## Environment

- Spinel commit: `f13e0ada`
- Ruby version: 4.0.6
- Platform: macOS 26 (arm64), Apple clang 21
