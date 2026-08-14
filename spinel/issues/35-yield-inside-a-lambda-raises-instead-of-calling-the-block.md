# [Runtime] `yield` inside a lambda raises `LocalJumpError` instead of calling the method's block

Found while porting [Ruby 2D](https://github.com/ruby2d/ruby2d) to Spinel.

## Description

A lambda created inside a method can call that method's block with `yield`. Spinel compiles the program and then raises `no block given (yield)` when the lambda runs, even though the method was given a block.

The same `yield` in an ordinary iteration block within the same method works, so it is specific to a proc that is lifted to a standalone function. Naming the block as `&blk` and calling `blk.call` is the working form.

## Reproduction

```ruby
def wrap
  w = ->(e) { yield e }
  w.call(7)
end

wrap { |v| puts "got #{v}" }
```

**Ruby 4.0.6:**
```
got 7
```

**Spinel (e05feeb9):**
```
no block given (yield) (LocalJumpError)
```

## Additional Findings

| Variant | Result |
|---|---|
| `yield` inside a lambda | **raises** |
| `yield` inside a `proc { }` literal | **raises** |
| the lambda returned and called by the caller | **raises** |
| `yield` inside an ordinary iteration block (`[7].each { \|e\| yield e }`) | correct |
| the block named `&blk` and called as `blk.call(e)` inside the lambda | correct |
| in a plain class, in a module used with `extend`, and at the top level | **raises** in all three |

The last row is what separates this from [#34](34-proc-capturing-a-block-parameter-refused-in-an-included-module.md): that one turns on `include` and refuses at compile time, this one is independent of where the method lives and fails at run time.

## Cause

`src/analyze.c:13073` marks a proc form's block parameter as a cell when a nested proc's body contains a `YieldNode`, with the comment that "the `YieldNode` is not a local read, so the capture pass cannot see it". `src/codegen.c` has the matching force for a lowered self-recursive yield method. What the reproduction shows is a case the pair does not cover: an ordinary method, not a proc form and not lowered, whose block is reached by a `yield` inside a lifted lambda. No capture is arranged, so the lambda finds no block at run time.

## Suggested fix

Treat a `YieldNode` in a lifted proc's body as a read of the enclosing method's block, the way the proc-form and lowered-method paths already do, so the block is captured and reaches the lambda. Raising is the correct answer only when the enclosing method genuinely received no block.

## Impact

Lower than the compile-time refusals — it is loud, and the `&blk` form is a direct rewrite. It is listed because the diagnostic points at the caller ("no block given") rather than at the construct, so the misleading part is where it sends you.

## Environment

- Spinel commit: `e05feeb9`
- Ruby version: 4.0.6
- Platform: macOS 26 (arm64), Apple clang 21
