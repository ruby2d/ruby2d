# [Runtime] A nil key looked up in a String-keyed Hash segfaults

Filed as [#3790](https://github.com/matz/spinel/issues/3790). Found while porting [Ruby 2D](https://github.com/ruby2d/ruby2d) to Spinel.

## Description

Asking a `Hash` with String keys whether it holds `nil` dereferences a null pointer. In Ruby the answer is `false` — a nil key is simply not present.

`sp_str_hash` reads the tag byte at `s[-1]` before hashing, so a NULL `const char *` faults at `0xffffffffffffffff`.

## Reproduction

```ruby
NAMED = { 'navy' => '#000080' }

def valid?(color)
  NAMED.key?(color)
end

puts valid?('navy').inspect
puts valid?(nil).inspect
```

**Ruby 4.0.6:**
```
true
false
```

**Spinel (489cbde7):**
```
true
[1]    66040 segmentation fault
```

```
* thread #1, stop reason = EXC_BAD_ACCESS (code=1, address=0xffffffffffffffff)
    frame #0: app`sp_StrStrHash_has_key + 132
->  0x1002f7bf0 <+132>: ldurb  w1, [x19, #-0x1]
```

## Additional Findings

Every String-keyed lookup is affected, and the value type does not matter:

| | result |
|---|---|
| `key?`, `has_key?`, `include?`, `[]` on `Hash{String=>String}` | segfault |
| same, on `Hash{String=>Integer}` | segfault |
| `Hash{Integer=>String}` | correct — prints `false` |
| a hash in a local, not a constant | segfault |
| a **literal** `nil` at the call site — `NAMED.key?(nil)` | correct — prints `false` |

The literal case is the one that hides this: written directly, the call is folded and never reaches the runtime. It only faults when the nil arrives through a variable — and the most ordinary source of one is a miss on another hash:

```ruby
NAMED = { 'navy' => '#000080' }
opts = { 'title' => 'My App' }
puts NAMED.key?(opts['background']).inspect   # segfault
```

That is the shape Ruby 2D hits: a window-options hash with no `background:` key, whose miss feeds a lookup in a table of color names. Nothing in the program is unusual, and the crash is the first sign anything is wrong — it dies before its first frame with no diagnostic.

## Cause

`lib/sp_str.h`, in `sp_str_hash`:

```c
static inline uint64_t sp_str_hash(const char*s){
  unsigned char m=((const unsigned char*)s)[-1];
```

`sp_str_eq`, just above it in the same file, already handles this and documents the convention:

> `dereference NULL on either side. nil-vs-string equality is false in Ruby; nil == nil is true, so falling back to pointer equality on the NULL path covers both.`

`sp_str_hash` is the same idea one step earlier, and it is the single point every string-keyed table operation goes through — `has_key`, `get`, `set`, `delete`, for `StrStrHash`, `StrIntHash` and `StrPolyHash` alike. The polymorphic dispatch path guards it explicitly (`spinel_rt.h`: `if (k.tag!=SP_TAG_STR||!k.v.s) return sp_box_nil();`); the direct typed calls the codegen emits do not.

## Suggested fix

A NULL key cannot be stored in a string-keyed table, so hashing it to a fixed bucket is enough: the probe loop only compares against non-NULL stored keys, `sp_str_eq` misses every one of them, and the lookup terminates at the first empty slot with the correct "not found".

```diff
 static inline uint64_t sp_str_hash(const char*s){
+  /* A NULL key is nil, which no string-keyed table can hold: hash it to a
+     fixed bucket and let sp_str_eq's NULL path miss every stored key. Same
+     convention sp_str_eq already documents above. */
+  if(!s)return 0;
   unsigned char m=((const unsigned char*)s)[-1];
```

With this applied, all nine variants above return what Ruby returns, the Ruby 2D script that found this builds and draws, and `make test` reports 2854 pass, 0 fail, 0 error.

This adds a predictable branch to an inlined hot path, and the file's own header notes the FNV cascade is optcarrot-sensitive. Guarding the callers instead would keep it off that path, but `sp_str_hash` has 23 call sites — 11 in `lib/sp_hash.c` and 12 in `lib/spinel_rt.h` — so that trades one line for twenty-three, and any site missed is still a crash. The cost of the single guard has not been measured.

## Environment

- Spinel commit: `489cbde7`
- Ruby version: 4.0.6
- Platform: macOS 26 (arm64), Apple clang 21
