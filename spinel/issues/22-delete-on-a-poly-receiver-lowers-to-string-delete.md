# [Codegen] `delete` on a polymorphic receiver is lowered to `String#delete`, stringifying the receiver

Filed as [#3806](https://github.com/matz/spinel/issues/3806). Found while porting [Ruby 2D](https://github.com/ruby2d/ruby2d) to Spinel.

## Description

`delete` called on a receiver inferred as `untyped` is compiled as `String#delete`, with the receiver coerced by `sp_poly_to_s` so the string operation type-checks. The receiver is not dispatched on, so a Hash or an Array reaching that call is reinterpreted as its own `to_s`.

The inference is right — `--emit-types` reports the receiver as `poly (untyped)`. Only the lowering is wrong: it commits to the String overload rather than dispatching.

It fails in two ways depending on the argument. A String argument type-checks, so the program compiles, runs, and prints a wrong answer. Anything else is a C compile error at the call.

## Reproduction

```ruby
opts = { n: 1, map: { 'a' => 7 } }
h = opts[:map]
puts h.delete('a').inspect
```

**Ruby 4.0.6:**
```
7
```

**Spinel (83d1315d):**
```
"{\"\" => 7}"
```

The hash was rendered as `{"a" => 7}`, `String#delete` removed every `a` character from that text, and the remains were returned as the value of `Hash#delete`.

## Additional Findings

**The emitted C shows the coercion.** `lv_h` is an `sp_RbVal`:

```c
sp_str_delete(sp_poly_to_s(lv_h), "a")
```

**With any non-String argument it does not compile.** This is the form Ruby 2D hits, where the key is an Integer id:

```ruby
opts = { n: 'a', map: { 'a' => 7 } }
h = opts[:map]
k = opts[:n]
puts h.delete(k).inspect
```

```
error: passing 'sp_RbVal' to parameter of incompatible type 'const char *'
  sp_str_delete(sp_poly_to_s(lv_h), lv_k);
```

| Variant | Result |
|---|---|
| poly receiver, String argument | compiles, prints `"{\"\" => 7}"` |
| poly receiver, poly argument | **compile error** |
| poly receiver, Integer key — `{ 1 => 7 }`, `h.delete(1)` | **compile error** |
| poly receiver is an Array — `h.delete(3)` on `[3, 4]` | **compile error** |
| typed receiver — `h = { 'a' => 7 }` | prints `7` |
| `h.key?('a')` and `h['a']` on the *same* poly receiver | print `true` and `7` |
| a user class defining `delete` is present | compiles, prints `""` |

`key?` and `[]` resolving correctly on the same receiver in the same program is the sharp contrast: the poly path serves those two and only `delete` commits to a builtin overload.

**In Ruby 2D** the call is `@gamepads_by_id.delete(id)`, an ivar assigned `{}` and written with a key that reaches the method as `untyped`. Every other `delete` in the library — `@objects.delete(object)`, `@tiles.delete([x, y])`, `handlers.delete(descriptor.id)` — has a typed receiver and compiles correctly.

**Related, and already fixed:** [#3438](https://github.com/matz/spinel/issues/3438), a Hash reaching a `String`-declared parameter and being read back as a C string. At `83d1315d` that program is refused with *"A seed is trusted, so the emitted code would reinterpret the value rather than convert it. Fix the signature or the call."* The same reinterpretation is still reachable here without any RBS seed, through the compiler's own coercion inside a builtin lowering.

## Cause

`src/codegen_call_recv.c`, in the `if (rt == TY_STRING)` block that serves the String builtins:

```c
else if (sp_streq(name, "delete") && argc == 1) { buf_printf(b, "sp_str_delete(%s, ", r); emit_expr(c, argv[0], b); buf_puts(b, ")"); }
```

A poly receiver reaches this block with `r` already wrapped in `sp_poly_to_s(...)`, so the guard that is meant to select String behavior for a String receiver selects it for an untyped one instead. `key?` and `[]` do not go through this path, which is why they answer correctly on the same value.

## Suggested fix

A receiver the compiler knows is `untyped` should dispatch rather than commit to the String overload — the poly path already serves `key?`, `[]` and the rest of the container surface on the same value. Failing that, refusing the call the way the seed path in #3438 now does would at least name the problem, rather than emitting a stringified receiver that compiles when the argument happens to be a String.

## Environment

- Spinel commit: `83d1315d`
- Ruby version: 4.0.6
- Platform: macOS 26 (arm64), Apple clang 21
