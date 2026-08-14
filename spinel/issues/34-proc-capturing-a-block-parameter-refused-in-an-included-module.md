# [Compile] A proc capturing a method's block parameter is refused when the method comes from an included module

Found while porting [Ruby 2D](https://github.com/ruby2d/ruby2d) to Spinel.

## Description

A method that takes a block as `&blk` and creates a proc capturing it compiles in a class, and compiles in a module used with `extend`. In a module mixed in with `include` it is refused:

```
unsupported proc referencing an uncaptured outer variable `blk` (later slice)
```

Nothing else has to be present — no intervening block, no other captured local, no iteration. Moving the identical method body from the module into the class it is included into compiles it. The parameter's name is immaterial; it is reported by whatever name the block parameter has.

Adjacent to [#3912](https://github.com/matz/spinel/issues/3912), which needs an enclosing iteration block and a mix of captured local and block parameter. This one has neither: the refusal turns on `include` alone.

## Reproduction

```ruby
module M
  def wrap(&blk)
    w = ->(e) { blk.call(e) }
    w.call(7)
  end
end

class Widget
  include M
end

Widget.new.wrap { |v| puts "got #{v}" }
```

**Ruby 4.0.6:**
```
got 7
```

**Spinel (e05feeb9):**
```
spinel: repro.rb:3: unsupported proc referencing an uncaptured outer variable `blk` (later slice): node 45 (LambdaNode)
```

## Additional Findings

| Variant | Result |
|---|---|
| the method defined in a module, mixed in with `include` | **refused** |
| the identical method defined directly in the class | compiles |
| the identical method in a module used with `extend` | compiles |
| a `proc { }` literal rather than a lambda | **refused**, reported as a `CallNode` |
| an ordinary block (`[7].each { \|e\| blk.call(e) }`) rather than a stored proc | compiles |
| the module included into two classes | **refused** |

Aliasing the block parameter to an ordinary local first — `p = blk` — and capturing that local compiles and behaves correctly, which is the shape this port is using as a workaround.

## Cause

The capture pass looks each name used by the proc up in the *immediately* enclosing scope and only marks `is_cell` on what it finds there — anything else is skipped as "not an enclosing local" (`src/analyze.c:743`). Emission then requires every name to be proc-local or celled and refuses otherwise (`src/codegen.c:3335`). For a method reached through `include`, the block parameter is evidently not a local of the scope the pass consults, so it is skipped as "not an enclosing local" and never celled — the `continue` is silent, so the mismatch only surfaces at emission as an unresolvable name. `extend` places the method somewhere the lookup does find it, which is why only `include` fails.

## Suggested fix

Resolve the block parameter against the scope that actually declares it rather than the immediately enclosing one, so an included module's method cells its `&blk` the same way a class's method already does. The `extend` and in-class rows show the celling itself works once the name is found.

## Impact

Whole-program compilation reaches every method whether or not the application calls it, so one such method anywhere in a mixin fails the build of programs that never use the feature. In Ruby 2D the per-object event registration lives in an `Interactive` module included into `Renderable`, and its filtered form wraps the caller's block in a lambda. Until this was worked around, no script using input events compiled — that is every example program in the library bar none.

## Environment

- Spinel commit: `e05feeb9`
- Ruby version: 4.0.6
- Platform: macOS 26 (arm64), Apple clang 21
