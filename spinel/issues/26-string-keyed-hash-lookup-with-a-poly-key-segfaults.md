# [Runtime] A String-keyed Hash looked up with a polymorphic key segfaults

Filed as [#3810](https://github.com/matz/spinel/issues/3810). Found while porting [Ruby 2D](https://github.com/ruby2d/ruby2d) to Spinel.

Follow-up to [#3790](https://github.com/matz/spinel/issues/3790), whose reproduction passes at `83d1315d`. That issue was the `nil` key; this is the same unchecked read reached with an ordinary value of the wrong type.

## Description

`key?` (and `[]`) on a String-keyed Hash compiles to a lookup that reads the key's string member out of the boxed value without checking its tag. When the key is a `String` at every call site the read is safe. When the same call site is also reached with a non-String — a Float, in a method whose parameter is therefore `untyped` — that value's bits are reinterpreted as a `const char *` and dereferenced.

The result is a segfault, not a `false`.

## Reproduction

```ruby
NAMED = { 'red' => '#FF0000' }.freeze

def named?(v)
  NAMED.key?(v)
end

warn "  -> #{named?('red')}"
warn "  -> #{named?(0.5)}"
```

**Ruby 4.0.6:**
```
  -> true
  -> false
```

**Spinel (83d1315d):**
```
  -> true
[segmentation fault]
```

## Additional Findings

**The emitted C reads the union member unconditionally:**

```c
static mrb_bool sp_named_p(sp_RbVal lv_v) {
  return sp_StrStrHash_has_key(cst_NAMED, (lv_v).v.s);
}
```

`lv_v` is an `sp_RbVal`, so `.v.s` is only valid when the tag says String. Nothing checks it.

| Variant | Result |
|---|---|
| called with a String and a Float | **segfault on the Float call** |
| the same, Float call first | **segfault on the Float call** |
| called only with a Float | prints `false` |
| called only with an Integer, or only a Symbol | prints `false` |
| called with a String and an Array | prints `true` / `false` |
| the key literal inline — `NAMED.key?(0.5)`, no method | prints `false` |
| a `nil` key, the [#3790](https://github.com/matz/spinel/issues/3790) shape | prints `nil` — fixed |

Calling with only a non-String is safe because the parameter then has a concrete non-String type and the lookup is resolved away. It is the mixed call sites — the case that makes the parameter `untyped` — that reach the unchecked read. An `Array` key is safe for the same reason the `nil` key now is, so the gap is specifically the scalar types whose payload aliases the string pointer.

The mixed call sites are not contrived. A name table consulted as a type test — "is this one of the known names, or one of the other forms?" — is asked about every kind of value the caller might pass, which is exactly what makes the parameter `untyped`. The reproduction above is that shape reduced.

## Suggested fix

The tag needs checking before `.v.s` is read — a non-String key cannot be present in a String-keyed hash, so the lookup can answer `false` without hashing. That is the same conclusion #3790 reached for `nil`; this is the remaining half.

## Environment

- Spinel commit: `83d1315d`
- Ruby version: 4.0.6
- Platform: macOS 26 (arm64), Apple clang 21
