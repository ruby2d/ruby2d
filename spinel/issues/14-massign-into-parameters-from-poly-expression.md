# [Codegen] Destructuring into a method's own parameters from a polymorphic expression emits invalid C

**Fixed upstream before it was filed**, by [`ef8535c4`](https://github.com/matz/spinel/commit/ef8535c4) *"Unbox a poly multiple assignment into a scalar target"* (test: `massign_poly_scalar_target.rb`), found independently on 2026-08-11. The `expand_massign` workaround was dropped the same day, verified against the real library and not just this reproduction. Kept as the local record; do not file.

Found while porting [Ruby 2D](https://github.com/ruby2d/ruby2d) to Spinel.

## Description

`x, y = expr` fails to compile when the targets are the enclosing method's parameters and `expr` is polymorphic. The parameters are typed from their call sites — `mrb_int` here — while the destructuring helper returns a boxed `sp_RbVal`, and the assignment is emitted with no unboxing.

Both parts are needed. Destructuring into fresh locals compiles, and so does destructuring into the parameters from a monomorphic expression.

## Reproduction

```ruby
module R
  def self.unrotate(flag, px, py)
    return [px, py] if flag

    [px * 1.5, py * 1.5]
  end
end

class Box
  def contains?(x, y)
    x, y = R.unrotate(true, x, y)
    x > 0 && y > 0
  end
end

puts Box.new.contains?(3, 4)
```

**Ruby 4.0.6:**
```
true
```

**Spinel (20a06d01):**
```
t.rb:12:8: error: assigning to 'mrb_int' (aka 'long') from incompatible type 'sp_RbVal'
   12 |   lv_x = sp_poly_massign_get(_t3, 0LL);
      |        ^ ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
```

## Additional Findings

**Working — fresh locals instead of the parameters:**

```ruby
def contains?(x, y)
  a, b = R.unrotate(true, x, y)
  a > 0 && b > 0
end
```

**Working — the parameters, from a monomorphic right-hand side:**

```ruby
module R
  def self.unrotate(_flag, px, py)
    [px, py]
  end
end

def contains?(x, y)
  x, y = R.unrotate(true, x, y)
  x > 0 && y > 0
end
```

The polymorphism usually arrives through an optional keyword argument or an early return, as above, so it is pervasive rather than local: in Ruby 2D roughly 40 sites destructure this way and 22 of them fail to compile, all with this one error.

The site the reproduction is cut from is a hit test shared by every shape:

```ruby
def contains?(x, y)
  x, y = Renderable._unrotate(self, x, y)
  x >= @x && x <= (@x + @width) && y >= @y && y <= (@y + @height)
end
```

`_unrotate` returns `[px, py]` unchanged when the object has no rotation and a pair of computed Floats otherwise, which is what makes it polymorphic.

## Environment

- Spinel commit: `20a06d01`
- Ruby version: 4.0.6
- Platform: macOS 26 (arm64), Apple clang 21
