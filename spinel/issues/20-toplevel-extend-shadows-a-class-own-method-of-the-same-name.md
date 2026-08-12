# [Runtime] A top-level `extend` shadows a class's own method of the same name, silently

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

**Spinel (9678c99b):**
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

Ruby 2D works around it by generating standalone top-level shims instead of using `extend`, which is the only reason the port draws anything.

## Environment

- Spinel commit: `9678c99b`
- Ruby version: 4.0.6
- Platform: macOS 26 (arm64), Apple clang 21
