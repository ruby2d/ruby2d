# [Codegen] Reading an instance variable from an `extend`-provided method emits invalid C

Filed as [#3789](https://github.com/matz/spinel/issues/3789). Found while porting [Ruby 2D](https://github.com/ruby2d/ruby2d) to Spinel.

## Description

A method a class picks up through `extend` becomes a class method, and its `self` is the class — so an instance variable read there is a class-level ivar. Spinel emits a compound literal for the receiver and then dereferences it, which does not compile:

```c
return ((sp_Class){1})->iv_label;
```

The same method body written as `def self.label` compiles and runs.

## Reproduction

```ruby
module ClassMethods
  def label; @label; end
end

class Win
  extend ClassMethods
end

puts Win.label.inspect
```

**Ruby 4.0.6:**
```
nil
```

**Spinel (489cbde7):**
```
t.rb:3:25: error: member reference type 'sp_Class' is not a pointer; did you mean to use '.'?
    3 |   return ((sp_Class){1})->iv_label;
      |          ~~~~~~~~~~~~~~~^~
t.rb:3:27: error: no member named 'iv_label' in 'sp_Class'
```

## Additional Findings

**Working — the same body as a plain singleton method:**

```ruby
class Win
  def self.label; @label; end
end

puts Win.label.inspect      # prints nil
```

Writing the ivar as well as reading it fails the same way, with the pointer error wrapped in a `typeof`:

```ruby
module ClassMethods
  def label=(v); @label = v; end
  def label; @label; end
end

class Win
  extend ClassMethods
end

Win.label = 'x'
puts Win.label.inspect
```
> `error: member reference type 'typeof (((sp_Class){1}))' is not a pointer`

Reading through a second method in the same module — `def check; label; end` — fails at the same place, so it is the ivar access rather than the call shape.

This one is incidental to the Ruby 2D port rather than blocking it: the library's `extend`-provided class methods delegate to a window object instead of holding state, so none of them reads a class-level ivar today. It is filed because it produces invalid C from ordinary Ruby, not because it stands in the way.

## Environment

- Spinel commit: `489cbde7`
- Ruby version: 4.0.6
- Platform: macOS 26 (arm64), Apple clang 21
