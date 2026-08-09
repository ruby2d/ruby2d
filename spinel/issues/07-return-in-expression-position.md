# [Compile] `return` in expression position is rejected (`x = expr or return`)

Filed as [#3777](https://github.com/matz/spinel/issues/3777). Found while porting [Ruby 2D](https://github.com/ruby2d/ruby2d) to Spinel.

## Description

`return` used as an expression rather than a statement is rejected at compile time, so the guard idiom `value = lookup or return` fails. The diagnostic points at the assignment rather than at `return`.

## Reproduction

```ruby
def fetch006(h006, k006)
  v006 = h006[k006] or return
  v006
end
p fetch006({ a: 1 }, :a)
```

**Ruby 4.0.6:**
```
1
```

**Spinel (1c3d99897ef3):**
```
spinel: v6_or_return.rb:2: unsupported expression: node 13 (ReturnNode)
```

## Additional Findings

**Working:** `return` as a statement, including the modifier form:

```ruby
v006 = h006[k006]
return if v006.nil?
return nil unless v006
```

**Failing:** `return` on the right of `or` / `||` in an assignment. `x = expr or return nil` fails identically.

## Environment

- Spinel commit: `1c3d99897ef3`
- Ruby version: 4.0.6
- Platform: macOS 15 (arm64), clang
