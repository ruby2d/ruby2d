# [Runtime] `self` escaping a superclass method is typed as the superclass, breaking later dispatch

Found while porting [Ruby 2D](https://github.com/ruby2d/ruby2d) to Spinel.

## Description

When a method defined on a superclass stores `self` somewhere, and that method is called on a *subclass* instance, the stored value is later typed as the superclass rather than the actual class. Any method call on it then raises `NoMethodError`, naming the superclass.

Calling the same method on an instance of the defining class works. Defining the method on the subclass works. Only the inherited path loses the type.

## Reproduction

```ruby
$o007 = []

class Base007
  def register007
    $o007 << self
  end
  def visible007?
    true
  end
end

class Sub007 < Base007; end

Sub007.new.register007
p $o007.map { |x| x.visible007? }
```

**Ruby 4.0.6:**
```
[true]
```

**Spinel (1c3d99897ef3):**
```
undefined method 'visible007?' for an instance of Base007 (NoMethodError)
```

Note the reported class is `Base007`, though the object is a `Sub007`.

## Additional Findings

**Working:**

```ruby
# self escaping a method on the object's own class
class C; def reg; $o << self; end; def vis?; true; end; end

# self escaping a module method, where the module is included directly
module M; def reg; $o << self; end; end
class C; include M; def vis?; true; end; end
```

**Failing:** any method reached through inheritance. A constructor is one case but not required — an ordinary instance method behaves identically. A module included into the *base* class and called on a subclass instance also fails, which is how we first hit it:

```ruby
module M; def reg; $o << self; end; end
class Base; include M; def vis?; true; end; end
class Sub < Base; end
Sub.new.reg
# Ruby:   [true]
# Spinel: undefined method 'vis?' for an instance of Base (NoMethodError)
```

With a **local** array in place of the global, the receiver degrades further, to `Object`:

```ruby
class Base
  def reg(sink); sink << self; end
  def vis?; true; end
end
class Sub < Base; end
o = []
Sub.new.reg(o)
p o.map { |x| x.vis? }
# Ruby:   [true]
# Spinel: undefined method 'vis?' for an instance of Object (NoMethodError)
```

Both messages suggest the escaping value's type is taken from where `self` was captured — the defining class — rather than from the allocation site.

## Environment

- Spinel commit: `1c3d99897ef3`
- Ruby version: 4.0.6
- Platform: macOS 15 (arm64), clang
