# `[Compile] alias_method inside class << self produces no callable class method`

Found while porting [Ruby 2D](https://github.com/ruby2d/ruby2d) to Spinel.

## Description

An `alias_method` inside a `class << self` block does not produce a callable class method; calling the alias is rejected at compile time. `attr_reader` in the same block works, so in the reproducer below the reader and the alias differ only in how they were defined.

## Reproduction

```ruby
class C003
  @shown003 = true
  class << self
    attr_reader :shown003
    alias_method :shown003?, :shown003
  end
end
p C003.shown003?
```

**Ruby 4.0.6:**
```
true
```

**Spinel (1c3d99897ef3):**
```
spinel: v3_alias_singleton.rb:8: unsupported call: node 19 (CallNode `shown003?`) recv=ConstantReadNode/ty48 argc=0
```

## Additional Findings

**Working:** `attr_reader` inside `class << self`; `def` inside `class << self`; `def self.name`; `alias_method` in an ordinary class body.

```ruby
class C
  @s = true
  class << self
    attr_reader :s
  end
end
p C.s          # true
```

**Failing:** `alias_method` inside `class << self`. The alias target resolves — only the alias itself is missing.

## Environment

- Spinel commit: `1c3d99897ef3`
- Ruby version: 4.0.6
- Platform: macOS 15 (arm64), clang
