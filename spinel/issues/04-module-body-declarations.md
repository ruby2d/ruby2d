# [Runtime] `attr_accessor` and `alias_method` in a module body do not reach the including class

Filed as [#3774](https://github.com/matz/spinel/issues/3774). Found while porting [Ruby 2D](https://github.com/ruby2d/ruby2d) to Spinel.

## Description

Methods declared in a module body with `attr_reader` / `attr_accessor` / `attr_writer` or `alias_method` are not visible on a class that `include`s the module — calling one raises `NoMethodError`. A plain `def` in the same module body works, and the same declarations in a *class* body work.

## Reproduction

```ruby
module M001
  attr_accessor :x001
end
class C001
  include M001
  def initialize; @x001 = 5; end
end
p C001.new.x001
```

**Ruby 4.0.6:**
```
5
```

**Spinel (1c3d99897ef3):**
```
undefined method 'x001' for an instance of C001 (NoMethodError)
```

`alias_method` fails the same way:

```ruby
module M002
  def visible002; true; end
  alias_method :visible002?, :visible002
end
class C002
  include M002
end
p C002.new.visible002?
```

**Ruby 4.0.6:** `true` — **Spinel:** `undefined method 'visible002?' for an instance of C002 (NoMethodError)`

## Additional Findings

**Working:**

```ruby
class C; attr_accessor :x; def initialize; @x = 5; end; end; p C.new.x   # 5
module M; def x; @x; end; end
class D; include M; def initialize; @x = 5; end; end; p D.new.x          # 5
```

**Failing:** `attr_reader` / `attr_accessor` / `attr_writer` / `alias` / `alias_method` in a module body.

Specific to declaration-style definitions crossing an `include`; the class-body case and the plain-`def`-in-module case both resolve.

## Environment

- Spinel commit: `1c3d99897ef3`
- Ruby version: 4.0.6
- Platform: macOS 15 (arm64), clang
