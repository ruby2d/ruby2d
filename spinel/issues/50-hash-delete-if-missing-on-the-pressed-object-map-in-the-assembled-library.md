# [Runtime] `Hash#delete_if` is undefined on a Symbol-keyed Hash of Hashes in a 4,500-line program, and defined on every standalone replica

**Status:** research notes — reproduces only in the assembled Ruby 2D library; no standalone reproducer yet.

Found while porting [Ruby 2D](https://github.com/ruby2d/ruby2d) to Spinel: `examples/snake.rb` removes a segment after a click and raises.

## Description

`Window::ObjectEventDispatch` keeps the buttons currently pressed on objects in `@pressed_objects`, a Hash from a button Symbol to `{ object:, x:, y: }`. It is initialized to `{}` in an included module's method, written in `dispatch_object_mouse_down`, read with `delete` and `each`, and cleaned with

```ruby
@pressed_objects.delete_if { |_btn, info| info[:object] == object }
```

In the assembled library (the `lib/` slice plus an app, about 4,500 lines) that line raises `undefined method 'delete_if' for an instance of Hash` the first time an object is removed after a press. `reject!` is equally undefined. Iterating `keys` and calling `delete` works, which is what the port does meanwhile.

Every standalone replica tried compiles and answers correctly: the same methods in a plain class; in an included module with the ivar initialized from `initialize`; with poly user objects as the `object:` values; with `delete`, `each` and `delete_if` all present; with the object also held in an Array that `delete`s it. Whatever decides this Hash's kind in the whole program has not been isolated — the reproducer is `spinel/scratch/input/state_harness.rb` on the Ruby 2D `spinel` branch, which builds the real slice with a stubbed `Ext` and runs in seconds.

## Reproduction

On the `spinel` branch of Ruby 2D, with the `spinel_hash_delete_if` transform removed from `cli/spinel.rb`:

```sh
ruby spinel/scratch/input/state_harness.rb
ruby spinel/scratch/input/state_harness_out.rb          # CRuby: STATE OK
spinel spinel/scratch/input/state_harness_out.rb -o h --cc='cc -w' && ./h
```

**Ruby 4.0.6:**
```
STATE OK
```

**Spinel (f13e0ada):**
```
undefined method 'delete_if' for an instance of Hash (NoMethodError)
```

## Environment

- Spinel commit: `f13e0ada`
- Ruby version: 4.0.6
- Platform: macOS 26 (arm64), Apple clang 21
