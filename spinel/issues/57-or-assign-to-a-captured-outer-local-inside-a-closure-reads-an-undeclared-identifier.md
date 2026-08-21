# [Compile] `||=` / `&&=` on a captured outer local inside a closure emits an undeclared identifier

Found while porting [Ruby 2D](https://github.com/ruby2d/ruby2d) to Spinel: `examples/hill_driver.rb` keeps its input latches (`accel`, `braking`, `boosting`) as top-level locals and folds the live gamepad state into them each frame with `accel ||= pad.axis(:right_trigger) > 0.1 || …` inside the `update` block. The C reads `lv_accel`, which nothing declares.

## Description

A local defined outside a closure and captured by it lives in a cell; reads and plain writes inside the closure go through the cell. An or-assign (`||=`) or and-assign (`&&=`) to that same local is lowered as a test-and-store on the bare `lv_` name instead:

```c
if (!lv_accel) lv_accel = (lv_dt > 0.050000000000000003);
```

so the C compiler reports `use of undeclared identifier 'lv_accel'`. The operator forms (`+=`) take the cell path and compile; a local first assigned *inside* the closure compiles; and `x = x || …` spelled out compiles. The shape is the memoization idiom — `cache ||= compute` in a proc that outlives the definition — as much as it is an input latch.

## Reproduction

```ruby
accel = false
blk = lambda do |dt|
  accel ||= dt > 0.05
  puts accel
end
blk.call(0.1)
```

**Ruby 4.0.6:**
```
true
```

**Spinel (2aed9817):**
```
a.rb:3:8: error: use of undeclared identifier 'lv_accel'
    3 |   if (!lv_accel) lv_accel = (lv_dt > 0.050000000000000003);
      |        ^~~~~~~~
a.rb:3:18: error: use of undeclared identifier 'lv_accel'
2 errors generated.
spinel: C compilation failed
```

## Additional Findings

| Variant | Result |
|---|---|
| As above | **C compilation fails** |
| `accel &&= dt > 0.05` | fails the same way |
| `cache = nil` outside, `cache ||= x * 2` inside (memoization) | fails the same way, on `lv_cache` |
| `proc { … }` or a block stored through `def update(&b)` instead of `lambda` | fails the same way |
| The closure inside a `def` rather than at the top level | fails the same way |
| `total += n` (operator assign) on the captured local | compiles |
| `accel = accel \|\| dt > 0.05` | compiles |
| `accel = false` moved *inside* the closure | compiles |
| `[0.5, 2.0].each { \|pad\| accel \|\|= pad > 0.1 }` directly at the top level (an iteration block, not a stored closure) | compiles |
| `n = 0` outside, `n \|\|= x` inside | compiles — `0` is truthy, and the assignment appears to fold away |

## Environment

- Spinel commit: `2aed9817`
- Ruby version: 4.0.6
- Platform: macOS 26 (arm64), Apple clang 21
