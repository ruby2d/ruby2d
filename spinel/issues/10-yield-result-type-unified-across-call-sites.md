# [Codegen] A block's result type is unified across call sites, dispatching to the wrong class

Found while porting [Ruby 2D](https://github.com/ruby2d/ruby2d) to Spinel.

## Description

When a method uses the value of `yield`, the type of that value appears to be fixed from one call site and applied to all of them. A second call site whose block returns a different class is compiled as though it returned the first class, so the wrong method is dispatched and the wrong fields are read.

The generated C makes it visible: the assignment is emitted with mismatched struct pointers, which clang reports as `-Wincompatible-pointer-types` — a warning by default, so the build succeeds and the failure only shows at run time.

This looks like the same block-return channel as [#3278](https://github.com/matz/spinel/issues/3278), with two differences that may put it outside that fix: both types here are plain user classes with no rbs involved, and the result is a warning and a wrong answer rather than a failed compile.

## Reproduction

```ruby
class A
  def initialize(v); @v = v; end
  def show; "A=#{@v}"; end
end
class B
  def initialize(v); @v = v; end
  def show; "B=#{@v}"; end
end

def fire
  puts yield.show
end

fire { A.new(1) }
fire { B.new(2) }
```

**Ruby 4.0.6:**
```
A=1
B=2
```

**Spinel (c70ed332):**
```
A=1
A=2
```

Compiling also emits:

```
warning: incompatible pointer types initializing 'sp_A *' (aka 'struct sp_A_s *')
  with an expression of type 'sp_B *' (aka 'struct sp_B_s *') [-Wincompatible-pointer-types]
```

## Additional Findings

`A#show` is called on a `B` instance. Here both classes happen to lay out `@v` identically, so the value survives and only the label is wrong; with differing layouts this reads the wrong memory.

We hit this on an event dispatcher with 19 call sites, each yielding a different event class:

```ruby
def fire_event_handlers(type)
  handlers = @events[type]
  return if handlers.empty?

  handlers.values.each { |e| e.call(yield) }
end

fire_event_handlers(:key_down) { KeyEvent.new(...) }
fire_event_handlers(:gamepad_button_up) { GamepadButtonData.new(pad, button) }
```

Every site was typed as the first one, producing 16 such warnings in one file.

## Environment

- Spinel commit: `c70ed332` (also present at `1c3d998`)
- Ruby version: 4.0.6
- Platform: macOS 26 (arm64), Apple clang 21
