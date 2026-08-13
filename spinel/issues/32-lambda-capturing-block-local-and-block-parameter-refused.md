# [Compile] A lambda capturing both a local and the parameter of its enclosing iteration block is refused

Filed as [#3912](https://github.com/matz/spinel/issues/3912). Found while porting [Ruby 2D](https://github.com/ruby2d/ruby2d) to Spinel.

## Description

A lambda created inside an iteration block can capture the block's locals, and it can capture the block's parameter — but not one of each. When its capture set contains both, the compile stops with `unsupported proc referencing an uncaptured outer variable`, and the diagnostic names the *local*, though it is adding the *parameter* that makes the local uncapturable: the identical lambda compiles with the parameter reference removed, and also compiles with the local reference removed.

The same mix at method scope — a method parameter plus a method local — compiles, so the refusal is specific to inlined iteration-block scope. Whether the lambda is stored or called immediately makes no difference.

## Reproduction

```ruby
[1].each do |k|
  values = [2]
  f = ->(e) { values.include?(k) }
  p f.call(0)
end
```

**Ruby 4.0.6:**
```
false
```

**Spinel (e05feeb9):**
```
spinel: repro.rb:3: unsupported proc referencing an uncaptured outer variable `values` (later slice): node 14 (LambdaNode)
```

## Additional Findings

| Variant | Result |
|---|---|
| lambda captures one block local | compiles |
| lambda captures two block locals | compiles |
| lambda captures the block parameter only | compiles |
| lambda captures a block local **and** the block parameter | **refused**, naming the local |
| the parameter referenced only inside a nested block within the lambda | **refused** the same way |
| the same mix at method scope (method parameter plus method local) | compiles |
| a method's `&proc` block parameter plus two block locals | compiles |

The single-variable rows are presumably the fixes for #2648 and #3416 working; the two-variable mix is the case they do not cover.

Found while reducing the library's per-object event registration, where a filter lambda in a `filters.map do |type, matcher| … end` block captures the block's locals and parameters together. Whole-program compilation reaches that method whether or not the application calls it, so the refusal fails the build of programs that never use the feature.

## Cause

The refusal itself is the emission-time capture check (`src/codegen.c:3330`): every name a proc reads must be proc-local or a celled (`is_cell`) enclosing local, and `values` arrives at emission with no cell. What the reproduction shows is that the analyzer's celling pass does mark `values` when it is the only capture, and stops marking it exactly when the capture set also contains the enclosing block's parameter — the parameter capture rides the separate cell-shadow mechanism for inlined loop parameters (`src/codegen.c:977`), and its presence appears to end the celling of the sibling local.

## Suggested fix

Cell every captured variable in the set independently: the parameter through its cell-shadow, the locals through ordinary cells, without either path short-circuiting the other. The two single-variable rows show both mechanisms already work in isolation.

## Environment

- Spinel commit: `e05feeb9`
- Ruby version: 4.0.6
- Platform: macOS 26 (arm64), Apple clang 21
