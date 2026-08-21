# [Compile] A method added to `String` that interpolates `self` emits a call with an `sp_String *` receiver into a `const char *` parameter

Found while porting [Ruby 2D](https://github.com/ruby2d/ruby2d) to Spinel: the library's ANSI color helpers on `String` stopped building once `-Werror=incompatible-pointer-types` landed in `77cc33c9`.

## Description

A user-defined `String` method whose body interpolates `self` is emitted with a `const char *self` parameter. A second `String` method that calls the first is emitted with `self` as an `sp_String *`, and passes it straight through. Before `77cc33c9` this was a warning in the build log; now it fails the build.

Reopening `String` to add a couple of formatting helpers that call each other is an ordinary shape — it is how a CLI adds colors.

## Reproduction

```ruby
class String
  def colorize(c); "\e[#{c}m#{self}\e[0m" end
  def bold; colorize('1') end
end
puts 'hi'.bold
```

**Ruby 4.0.6:**
```
[1mhi[0m
```

**Spinel (f13e0ada):**
```
error: incompatible pointer types passing 'sp_String *' to parameter of type 'const char *' [-Werror,-Wincompatible-pointer-types]
```

## Additional Findings

| Variant | Result |
|---|---|
| As above | **C error** |
| `puts 'hi'.colorize('1')` directly, no `bold` | compiles |

The two methods disagree on what a `String` receiver is: the callee takes the immutable `const char *`, the caller holds the mutable `sp_String *` and forwards it without converting.

## Environment

- Spinel commit: `f13e0ada`
- Ruby version: 4.0.6
- Platform: macOS 26 (arm64), Apple clang 21
