# [Compile] A block parameter the body never reads emits invalid C when the receiver is an empty array literal

Found by a Ruby-versus-Spinel differential survey while porting [Ruby 2D](https://github.com/ruby2d/ruby2d) to Spinel.

## Description

`[].map { |unused| 1 }` fails to compile. The iterator emits the block parameter's binding into the loop body, but the declaration pass prunes the parameter's local, so the generated C assigns to an identifier it never declared:

```
error: use of undeclared identifier 'lv_unused'
    lv_unused = sp_PolyArray_get(_t1, _t3);
```

The two conditions are an **empty array literal** as the receiver and a block parameter the body never reads. Either one alone is fine: `[1].map { |unused| 1 }` declares the local as `mrb_int lv_unused = 0`, and `a = []; a.map { |unused| 1 }` declares it as `sp_RbVal lv_unused = sp_box_nil()`. Only the literal-empty receiver leaves the element type uninferred, and only then is the declaration dropped while the assignment is still emitted.

`each` compiles, because it builds no result and emits no binding of this shape. The value-producing iterators — `map`, `select`, `flat_map` — all fail.

An empty collection literal is ordinary starting state, and `{ |unused| ... }` or `{ |_| ... }` is the ordinary way to write a block that ignores its element, so this is reachable from plain code.

## Reproduction

```ruby
p([].map { |unused| 1 })
```

**Ruby 4.0.6:**
```
[]
```

**Spinel (42649df7):**
```
error: use of undeclared identifier 'lv_unused'
    8 |     lv_unused = sp_PolyArray_get(_t1, _t3);
      |     ^~~~~~~~~
1 error generated.
spinel: C compilation failed
```

## Additional Findings

| Variant | Result |
|---|---|
| `[].map { \|unused\| 1 }` | **invalid C** |
| `[].select { \|unused\| true }` | **invalid C**, two errors — the binding and the push |
| `[].flat_map { \|unused\| [1] }` | **invalid C** |
| `[].map { \|_\| 1 }` | **invalid C** — `lv__` undeclared |
| `[].map { \|x\| x }` (parameter read) | compiles |
| `[1].map { \|unused\| 1 }` (non-empty literal) | compiles — declares `mrb_int lv_unused = 0` |
| `a = []; a.map { \|unused\| 1 }` (empty via a local) | compiles — declares `sp_RbVal lv_unused = sp_box_nil()` |
| `[].each { \|unused\| ... }` | compiles |
| `[].each_with_index { \|unused, i\| ... }` | compiles |

The `_` row matters for reporting: the idiomatic spelling of "I am ignoring this parameter" is the one that fails.

## Cause

The emitted body and the emitted prologue disagree. For the failing program `main` opens with no declaration at all, and the loop still binds:

```c
int main(int argc,char**argv){
  ...
  sp_PolyArray * _t1 = _t4;
  sp_IntArray *_t2 = sp_IntArray_new();
  for (mrb_int _t3 = 0; _t3 < sp_PolyArray_length(_t1); _t3++) {
    lv_unused = sp_PolyArray_get(_t1, _t3);     /* never declared */
```

The two working receivers show what the declaration would have been, and that the element type is what decides it: the non-empty literal gives `mrb_int`, the empty local gives `sp_RbVal`. An empty *literal* infers neither, and the local is pruned as unused — while the iterator emitter binds the parameter unconditionally.

## Suggested fix

Make the two agree in whichever direction is cheaper:

1. Do not prune a local that an iterator will bind — the parameter is "unused" in the Ruby body but is still an assignment target in the emitted C; or
2. do not emit the binding when the local was pruned, since a body that never reads the parameter does not need it bound.

The second is the smaller change and matches what the body actually needs. Either way the fix should cover `map`, `select` and `flat_map` together — they share the binding shape, and the `select` case emits the undeclared identifier twice, once for the binding and once for the push.

## Impact

A hard compile failure on a line of ordinary Ruby, and the diagnostic names a C identifier rather than the Ruby construct, so it does not point at the block. The workaround — read the parameter, or name the empty array first — is not something a user would guess from the message.

## Environment

- Spinel commit: `42649df7`
- Ruby version: 4.0.6
- Platform: macOS 26 (arm64), Apple clang 21
