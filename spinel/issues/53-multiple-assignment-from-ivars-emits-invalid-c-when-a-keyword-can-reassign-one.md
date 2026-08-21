# [Compile] `a, b = @a, @b` emits invalid C when a keyword argument may reassign one of the ivars in the same method

Found while porting [Ruby 2D](https://github.com/ruby2d/ruby2d) to Spinel: `Canvas#render` saves its position and size, applies per-call overrides, draws, and restores.

## Description

A method that destructures two ivars into locals (`saved_width, saved_height = @width, @height`) and also conditionally assigns one of those ivars from a nil-defaulted keyword (`@width = width if width`) fails to compile: the local is declared as an integer and the multiple assignment hands it a boxed value.

```
error: assigning to 'sp_int' (aka 'long') from incompatible type 'sp_RbVal'
   11 |   lv_saved_height = _t2;
```

Two plain assignments in place of the multiple assignment compile and run correctly, as does the multiple assignment when the keyword reassignment is absent. It is the combination — the keyword widens the ivar's type, and the multiple assignment's target does not follow.

Save, override, draw, restore is the standard shape of an immediate-mode `render(x: nil, y: nil, …)` over an object's own state.

## Reproduction

```ruby
class C
  attr_accessor :width, :height
  def initialize(w, h)
    @width = w
    @height = h
  end
  def render(width: nil, height: nil)
    saved_width, saved_height = @width, @height
    @width = width if width
    @height = height if height
    puts "draw #{@width}x#{@height}"
    @width, @height = saved_width, saved_height
  end
end
c = C.new(10, 20)
c.render(width: 5)
c.width = 3
c.render
```

**Ruby 4.0.6:**
```
draw 5x20
draw 3x20
```

**Spinel (f13e0ada):**
```
error: assigning to 'sp_int' (aka 'long') from incompatible type 'sp_RbVal'
```

## Additional Findings

| Variant | Result |
|---|---|
| As above | **invalid C** |
| `saved_width = @width` and `saved_height = @height` as two statements | correct |
| No `render` keywords (`def render` with the save, the draw and the restore) | correct |
| Only the save-side multiple assignment, no restore and no keywords | correct |
| A Float assigned through the accessor before the second call | **invalid C** (same error) — the widening is from the keyword, not the value |

## Environment

- Spinel commit: `f13e0ada`
- Ruby version: 4.0.6
- Platform: macOS 26 (arm64), Apple clang 21
