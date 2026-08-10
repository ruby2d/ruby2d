# [Runtime] `next` inside a `Hash#each` block loops forever

Found while porting [Ruby 2D](https://github.com/ruby2d/ruby2d) to Spinel.

## Description

Taking `next` inside a block passed to `Hash#each` does not advance the iterator, so the program hangs. The block runs, but reaching `next` restarts the same entry rather than moving to the following one.

`Array#each` is unaffected. `Hash#each_pair` fails the same way.

This is a regression. `git bisect` over the 78 commits since `1c3d998` gives a first bad commit of `ffb0587c` ("Refuse a new key, and keep iterating past a deleted one, in `Hash#each`").

## Reproduction

```ruby
{ a: 1 }.each do |k, v|
  next
  puts "unreachable #{k}#{v}"
end
puts 'ok'
```

**Ruby 4.0.6:**
```
ok
```

**Spinel (c70ed332):**
```
(hangs; no output, must be killed)
```

## Additional Findings

**Working — `Array#each` with the same block:**

```ruby
[1, 2].each do |v|
  next
  puts "unreachable #{v}"
end
puts 'ok'                 # prints ok
```

**Working — `Hash#each` whose `next` is never taken:**

```ruby
{ a: 1 }.each do |k, v|
  next unless v.is_a?(Numeric)
  puts "#{k}=#{v}"
end
puts 'ok'                 # prints a=1, then ok
```

The hang depends on `next` actually firing, not on its presence: rewriting the guard to the equivalent `if` form makes the same loop terminate.

**Failing — `each_pair`, same shape:**

```ruby
{ a: 1 }.each_pair do |k, v|
  next
end
```

We hit this in a validation helper that skips non-numeric entries while iterating a keyword-splat hash, which put every shape constructor into an infinite loop.

## Environment

- Spinel commit: `c70ed332` (good at `1c3d998`)
- Ruby version: 4.0.6
- Platform: macOS 26 (arm64), Apple clang 21
