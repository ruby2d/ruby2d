# [Compile] An implicit-receiver call to an `alias_method` singleton is unsupported from an extended module

Found while porting [Ruby 2D](https://github.com/ruby2d/ruby2d) to Spinel.

## Description

A class method created by `alias_method` inside `class << self` cannot be called with an implicit receiver from a method the class picked up through `extend`. The same method called as `Win.shown?` works, so the alias itself resolves — [#3776](https://github.com/matz/spinel/issues/3776) fixed that — but the receiverless call from inside the extended module is rejected at compile time.

The alias is what makes the difference. An ordinary `def self.shown?`, and an `attr_reader` without the alias, are both fine in the same position.

## Reproduction

```ruby
class Win
  class << self
    attr_reader :shown
    alias_method :shown?, :shown
  end

  module ClassMethods
    def check; shown? ? 'yes' : 'no'; end
  end
  extend ClassMethods
end

puts Win.check
```

**Ruby 4.0.6:**
```
no
```

**Spinel (20a06d01):**
```
spinel: t.rb:9: unsupported call: node 36 (CallNode `shown?`) recv=-/ty-1 argc=0
```

## Additional Findings

**Working — the same alias called with an explicit receiver:**

```ruby
class Win
  class << self
    attr_reader :shown
    alias_method :shown?, :shown
  end
end

puts Win.shown?.inspect     # prints nil
```

**Working — a plain singleton method in the same position:**

```ruby
class Win
  def self.shown?; false; end

  module ClassMethods
    def check; shown? ? 'yes' : 'no'; end
  end
  extend ClassMethods
end

puts Win.check              # prints no
```

**Working — `attr_reader` reached the same way, without the alias:**

```ruby
class Win
  class << self
    attr_reader :shown
  end

  module ClassMethods
    def check; shown ? 'yes' : 'no'; end
  end
  extend ClassMethods
end

puts Win.check              # prints no
```

So it takes the alias and the implicit receiver together.

In Ruby 2D this is a guard: a class method in an extended module checks `shown?` before drawing, and `shown?` is an alias of the `shown` reader on the window class. The port works around it by rewriting the call to name its receiver explicitly.

## Environment

- Spinel commit: `28b4e9f9`
- Ruby version: 4.0.6
- Platform: macOS 26 (arm64), Apple clang 21
