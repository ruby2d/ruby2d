# [Runtime] A forwarded block stored in an instance variable still loses its captured locals

Found while porting [Ruby 2D](https://github.com/ruby2d/ruby2d) to Spinel.

## Description

Follow-up to [#3772](https://github.com/matz/spinel/issues/3772), which is fixed for the case its reproduction showed — a block forwarded with `&b` and stored in a **global**. The same block stored in an **instance variable** still loses its captured locals.

The block runs, and writes to its own locals behave normally within a call, but writes to captured outer locals never reach the enclosing scope.

## Reproduction

```ruby
class Holder
  def store(&b); @proc = b; end
  def run; @proc.call; end
end

def forward(h, &b); h.store(&b); end

h = Holder.new
n = 0
forward(h) { n += 1 }
h.run
puts "n=#{n}"
```

**Ruby 4.0.6:**
```
n=1
```

**Spinel (c70ed332):**
```
n=0
```

## Additional Findings

**Working — the same shape storing to a global (the #3772 reproduction, now fixed):**

```ruby
$p = nil
def store(&b); $p = b; end
def outer(&b); store(&b); end
n = 0
outer { n += 1 }
$p.call
puts "n=#{n}"           # n=1, correct
```

**Working — stored in an ivar without forwarding:**

```ruby
h = Holder.new
n = 0
h.store { n += 1 }      # called directly, not through `forward`
h.run
puts "n=#{n}"           # n=1, correct
```

So it takes both the `&b` forward and the ivar store together.

Calling the stored block repeatedly shows each call starting from the original value rather than accumulating — with `3.times { h.run }`, `n` inside the block reads 1 every time and the outer `n` ends at 0.

This is the shape a per-frame callback takes in Ruby 2D: a top-level `update { }` forwards the user's block to a window object that holds it and calls it once per frame. Counters and accumulators written by that block silently stay at their initial values.

## Environment

- Spinel commit: `c70ed332`
- Ruby version: 4.0.6
- Platform: macOS 26 (arm64), Apple clang 21
