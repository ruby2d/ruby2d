# `[Runtime] self stored from an inherited constructor loses its concrete type, breaking later dispatch`

Found while porting [Ruby 2D](https://github.com/ruby2d/ruby2d) to Spinel.

## Description

When a subclass instance stores `self` into a collection from a constructor it inherits, the stored value is later typed as the *defining* class rather than the actual one. Any method call on it then raises `NoMethodError`, naming the base class.

Instantiating the base class directly works. Defining the constructor on the subclass works. Only the inherited-constructor path fails.

## Reproduction

```ruby
$objects008 = []

class Base008
  def initialize
    $objects008 << self
  end
  def visible008?
    true
  end
end

class Sub008 < Base008; end

Sub008.new
p $objects008.map { |o| o.visible008? }
```

**Ruby 4.0.6:**
```
[true]
```

**Spinel (1c3d99897ef3):**
```
undefined method 'visible008?' for an instance of Base008 (NoMethodError)
```

Note the reported class is `Base008`, though the object is a `Sub008`.

## Additional Findings

**Working:** instantiating `Base008` directly instead of `Sub008`; defining `initialize` on `Sub008` rather than inheriting it; appending the object from outside the constructor (`$objects008 << Sub008.new`).

**Failing:** any method call on the stored object. This is not specific to modules or to `include` — a method defined directly on the base class fails the same way, as does one added by the subclass.

With a **local** array in place of the global, the receiver degrades further and the error becomes `undefined method 'vis?' for an instance of Object`:

```ruby
class Base
  def initialize(sink); sink << self; end
  def vis?; true; end
end
class Sub < Base; end
o = []
Sub.new(o)
p o.map { |x| x.vis? }
# Ruby:   [true]
# Spinel: undefined method 'vis?' for an instance of Object (NoMethodError)
```

The two error messages together suggest the element type is fixed from where `self` was captured — the base class's `initialize` — rather than from the allocation site.

## Environment

- Spinel commit: `1c3d99897ef3`
- Ruby version: 4.0.6
- Platform: macOS 15 (arm64), clang
