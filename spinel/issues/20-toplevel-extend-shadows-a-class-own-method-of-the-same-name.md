# [Runtime] A top-level `extend` shadows a class's own method of the same name, silently

**Fixed upstream before it was filed**, by [`80a3beb2`](https://github.com/matz/spinel/commit/80a3beb2) *"Keep a module usable from a class and the top level at once"* on 2026-08-12. Its parent is `b51c880d`, where the reproduction below fails, so the attribution is exact. Kept as the local record; do not file.

The fix came from [#3795](https://github.com/matz/spinel/issues/3795), reported against `include` rather than `extend` — the same underlying defect described there as "a receiverless call inside such a class reached for the top-level copy — the module's own null-receiver function — rather than the class's transplanted one", which is precisely the `sp_DSL_update(NULL)` below. **The `extend` shape is not covered by a test upstream.** `test/module_included_class_and_toplevel.rb` uses `include`, and no test exercises a class whose own method is shadowed. If this regresses, their suite will not catch it, so the reproduction below is worth offering as a test case.

Found while porting [Ruby 2D](https://github.com/ruby2d/ruby2d) to Spinel.

## Description

When a module is brought in with `extend` at the top level, a class that defines a method of the same name loses it: an implicit-receiver call inside that class dispatches to the *module's* method instead of the class's own.

There is no error and no warning. The program compiles, runs, and prints the wrong thing — which makes this worse than the two compile-time bugs in the same area, [#3787](https://github.com/matz/spinel/issues/3787) and the block-parameter one filed alongside this, both of which fail loudly.

A top-level `extend` adds the module to `main`'s singleton class. It has no bearing on how a call inside an unrelated class resolves.

## Reproduction

```ruby
module DSL
  def update
    puts 'DSL#update'
  end
end

class Window
  def update
    puts 'Window#update'
  end

  def update_callback
    update
  end
end

extend DSL

Window.new.update_callback
update
```

**Ruby 4.0.6:**
```
Window#update
DSL#update
```

**Spinel (b51c880d):**
```
DSL#update
DSL#update
```

## Additional Findings

**The top-level `extend` is required.** Deleting it, and the top-level `update` call with it, leaves the program printing `Window#update` correctly. The module can still be defined; it is extending it that breaks the class.

**Definition order does not matter.** Moving `module DSL` after `class Window` gives the same wrong output, so this is not the ordering-dependent resolution of [#3786](https://github.com/matz/spinel/issues/3786).

**The receiver is emitted as NULL.** Inside `Window#update_callback`, the call compiles to

```c
sp_DSL_update(NULL);
```

so it is not that `Window`'s method is missing — the wrong callee is selected outright and handed no receiver.

**It is only the implicit-receiver form.** Writing `self.update` inside `update_callback` prints `Window#update` under both, so the explicit receiver resolves correctly — the same split [#3788](https://github.com/matz/spinel/issues/3788) had.

## Impact

This is the shape Ruby 2D hits. `Window` defines `update` and `render`; the DSL module of the same names is extended at the top level so scripts can write `update do … end`; and `Window`'s own internals call `update` and `render` with an implicit receiver. Every one of those dispatches to the DSL method, so the window's update and render hooks never run.

Ruby 2D works around it by generating standalone top-level shims instead of using `extend`, which is the only reason the port draws anything. That workaround — `dsl_shims` — outlives the fix: dropping it now leaves the block-parameter bug in `issues/19-…`, which is a separate defect at the same call site.

## Environment

- Spinel commit: `b51c880d`
- Ruby version: 4.0.6
- Platform: macOS 26 (arm64), Apple clang 21
