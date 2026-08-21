# [Runtime] A lambda that is the value of a conditional — `if`/`else` or `?:` with a lambda in each arm — has its parameter typed Integer

Found while porting [Ruby 2D](https://github.com/ruby2d/ruby2d) to Spinel: the method that builds a filtered event handler picks one of two lambdas, and every filtered handler then raised `undefined method 'matches?' for an instance of Integer` on its first event.

## Description

When a method's value (or an assignment's right-hand side) is a conditional whose arms are both lambdas, the lambda that is chosen has its block parameter typed as `Integer`, whatever is later passed to it. Calling a method on that parameter raises `NoMethodError … for an instance of Integer`; passing it on raises `no implicit conversion of <Class> into Integer`.

The same two lambdas reach the caller correctly when the conditional is not the value: an early `return ->(e) { … } if cond` followed by the other lambda, two helper methods chosen by the conditional, or an `if`/`else` that *assigns* a local in each arm. It is specifically the conditional-as-expression over two lambda literals.

## Reproduction

```ruby
S = Struct.new(:key) do
  def m?(v) = key == v
end
def build(matcher)
  if matcher.is_a?(Hash)
    ->(e) { e.m?(matcher[:key]) }
  else
    ->(e) { e.m?(matcher) }
  end
end
f = build(:space)
p f.call(S.new(:space))
```

**Ruby 4.0.6:**
```
true
```

**Spinel (f13e0ada):**
```
undefined method 'm?' for an instance of Integer (NoMethodError)
```

## Additional Findings

| Variant | Result |
|---|---|
| As above (`if`/`else` as the method's value) | **NoMethodError** |
| `args = flag ? ->(e) { … } : ->(e) { … }` (ternary as an assignment's value) | **NoMethodError** — `undefined method 'key' for an instance of Integer` |
| Condition is a plain boolean parameter instead of `is_a?(Hash)` | **NoMethodError** — the test is not the trigger |
| Both arms textually identical | **NoMethodError** |
| `return ->(e) { … } if cond` then the other lambda | correct |
| Each arm in its own method, chosen by `cond ? a(m) : b(m)` | correct |
| `if cond then args = ->(e) { … } else args = ->(e) { … } end` (statement, assigning) | correct |

The statement form working while the expression form fails suggests the join of the two arms' types is what loses the parameter — a plain `if` statement never has to type the conditional itself.

## Environment

- Spinel commit: `f13e0ada`
- Ruby version: 4.0.6
- Platform: macOS 26 (arm64), Apple clang 21
