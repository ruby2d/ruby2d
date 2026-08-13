# [Runtime] A keywords-only call still types an optional positional as the keyword hash: its `nil` default renders as `{}`, and a Hash method on it segfaults

Filed as [#3911](https://github.com/matz/spinel/issues/3911). Follow-up to [#3808](https://github.com/matz/spinel/issues/3808). Found while porting [Ruby 2D](https://github.com/ruby2d/ruby2d) to Spinel.

## Description

#3808's double-binding is fixed: a keywords-only call no longer passes the keyword hash to the optional positional, and the emitted call site passes the parameter's nil sentinel instead. But the keyword hash still *types* the parameter. When no call site in the program passes a real positional argument, the optional positional's C type becomes the keyword hash's type, and its `nil` default is represented as a `NULL` hash pointer.

The predicates read that sentinel correctly — `x.nil?` answers `true`, `if x` does not take the branch, `x == nil` answers `true`. Everything else reads it as a hash: `inspect` and string interpolation render `{}` instead of `nil`, and a Hash method call such as `x.size` dereferences the `NULL` and segfaults, where CRuby raises `NoMethodError`.

The trigger is program-global: one unrelated call site passing any positional argument re-types the parameter and every call behaves correctly, including the keywords-only one.

## Reproduction

```ruby
def a(x = nil, **kw)
  puts "x=#{x.inspect} kw=#{kw.inspect}"
end

a(k: 1)
```

**Ruby 4.0.6:**
```
x=nil kw={k: 1}
```

**Spinel (e05feeb9):**
```
x={} kw={k: 1}
```

## Additional Findings

| Variant | Result |
|---|---|
| single keywords-only call | **`x={}`** |
| a bare call `a` added after the keywords-only call | **both** calls print `x={}` — the zero-argument call is affected too |
| an unrelated call `a(7)` added instead | both calls correct, including the keywords-only one |
| default `:none` instead of `nil` | correct |
| explicit positional hash plus keywords, `a({h: 3}, k: 4)` | correct — binding is right, per the #3808 fix |
| `x.nil?`, `if x`, `x == nil` | all correct |
| `"#{x}"` (`to_s`) | `{}` |
| `x.size` | **segfault** — CRuby raises `NoMethodError` |

The second row is the bounding one: the corruption is in the parameter's representation, not in the keywords-only call's binding, since a call that passes nothing at all produces the same `{}`.

**The emitted C shows the fixed binding and the unfixed type.** The parameter and the keyword rest have the same type, and the call site passes `NULL` for the positional:

```c
static inline void sp_a(sp_SymPolyHash * lv_x, sp_SymPolyHash * lv_kw) { ...

  sp_SymPolyHash * _t5 = NULL;
  SP_GC_ROOT(_t5);
  sp_SymPolyHash *_t6 = sp_SymPolyHash_new();
  SP_GC_ROOT(_t6);
  sp_SymPolyHash_set(_t6, sp_sym_intern("k"), sp_box_int(1LL));
  sp_a(_t5, _t6);
```

`_t5 = NULL` is the fix from #3808 working: the keyword hash no longer funds `x`. But `lv_x` is declared `sp_SymPolyHash *`, so `NULL` is a nil that only the predicates understand: `sp_SymPolyHash_inspect(NULL)` answers `{}`, and `sp_SymPolyHash_size(NULL)` dereferences it.

## Cause

The type-inference half of the old double-binding survives the fix: the keyword hash's type still unifies into the optional positional's parameter type even though its value no longer binds there. With no other call site contributing a positional type, the parameter's slot becomes the hash type, and `nil` has no representation in it besides `NULL`.

## Suggested fix

Exclude the keyword hash from the optional positional's type the same way the fix excluded it from the binding: the parameter's type should come from actual positional arguments and its default value only. That removes both symptoms at once.

Separately, `sp_SymPolyHash_size` (and any sibling that dereferences the receiver without a `NULL` check) turns a nil that reaches a hash-typed slot into a native crash rather than a `NoMethodError`; a `NULL` guard there would keep any future instance of this class of type mismatch at the Ruby-error level.

## Environment

- Spinel commit: `e05feeb9`
- Ruby version: 4.0.6
- Platform: macOS 26 (arm64), Apple clang 21
