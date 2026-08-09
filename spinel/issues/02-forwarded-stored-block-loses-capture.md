# [Runtime] A block forwarded with `&b` and then stored loses its captured locals

Filed as [#3772](https://github.com/matz/spinel/issues/3772). Found while porting [Ruby 2D](https://github.com/ruby2d/ruby2d) to Spinel.

## Description

A block forwarded with `&b` through one method into another that *stores* it, then called later, runs without error but its writes to captured outer locals are lost. The block executes — side effects like `puts` inside it happen — only the captured binding is not shared.

Forwarding a block and calling it immediately works. Storing a block and calling it later works. Only the combination fails, and it fails silently.

## Reproduction

```ruby
$p007 = nil
def store007(&b007); $p007 = b007; end
def outer007(&b007); store007(&b007); end

n007 = 0
outer007 { n007 += 1 }
$p007.call
puts "n=#{n007}"
```

**Ruby 4.0.6:**
```
n=1
```

**Spinel (1c3d99897ef3):**
```
n=0
```

## Additional Findings

**Working — forwarded, called immediately:**

```ruby
def inner(&b); b.call; end
def outer(&b); inner(&b); end
n = 0
outer { n += 1 }        # n == 1, correct
```

**Working — stored, not forwarded:**

```ruby
$p = nil
def store(&b); $p = b; end
n = 0
store { n += 1 }
$p.call                 # n == 1, correct
```

**Failing:** forwarded *and* stored, then called after the forwarding frame has returned.

The same happens when the store is an ivar on an object rather than a global, which is how we hit it: a top-level DSL method forwards the user's block to a `Window` object that keeps it and calls it once per frame. The per-frame block ran, but every counter and accumulator it wrote to stayed at its initial value.

## Environment

- Spinel commit: `1c3d99897ef3`
- Ruby version: 4.0.6
- Platform: macOS 15 (arm64), clang
