# [Runtime] A positional Hash silently satisfies a single required keyword, binding it to `{}` instead of raising `ArgumentError`

Found by a Ruby-versus-Spinel differential survey while porting [Ruby 2D](https://github.com/ruby2d/ruby2d) to Spinel.

## Description

A method declaring exactly one required keyword, called with a positional Hash and no keywords, is accepted. Ruby 4 separated positional and keyword arguments: a Hash passed positionally is a positional argument, the required keyword is missing, and the call raises `ArgumentError`. Spinel consumes the Hash as the keyword source, then binds the keyword to an empty Hash rather than to the value the Hash actually holds.

The boundary is the *count*: declare a second required keyword and Spinel raises correctly. So the divergence is not a general "keywords are optional" rule but something specific to the single-keyword arity check.

This is adjacent to [#3808](https://github.com/matz/spinel/issues/3808) and [#3911](https://github.com/matz/spinel/issues/3911) — the same confusion between a positional Hash and the keyword channel — but neither covers a *required* keyword being satisfied by one, so a fix for those does not obviously reach this.

## Reproduction

```ruby
def m(x:)
  p x
end

opts = { x: 1 }

begin
  m(opts)
rescue ArgumentError => e
  p [ArgumentError, e.message]
end
```

**Ruby 4.0.6:**
```
[ArgumentError, "wrong number of arguments (given 1, expected 0; required keyword: x)"]
```

**Spinel (42649df7):**
```
{}
```

## Additional Findings

| Variant | Result |
|---|---|
| one required keyword, positional Hash in a local | **accepted**, binds `{}` |
| one required keyword, positional Hash literal `m({x: 1})` | **accepted**, binds `{}` |
| one required keyword **and** a required positional, `m(1, opts)` | **accepted**, binds `[1, {}]` |
| **two** required keywords, `m(opts)` | correct — raises `ArgumentError` |
| one required keyword, called with nothing at all | correct — raises `ArgumentError` |
| one required keyword, called correctly as `m(x: 1)` | correct — binds `1` |

The value bound is `{}`, not the Hash and not the Hash's value, so no reading of the call gets the right answer — the argument is consumed and then discarded.

## Cause

Not root-caused. The two working rows bound it: the arity check does fire when the keyword count is two, and does fire when there is no argument at all, so what is wrong is narrower than "positional Hashes are treated as keywords". The `{}` that arrives suggests the Hash is matched against the keyword channel, consumed there, and then the keyword's own binding falls through to an empty-Hash default rather than to a lookup in the consumed Hash.

## Suggested fix

Reject a positional Hash as a source for required keywords regardless of how many are declared, so the one-keyword case raises the same `ArgumentError` the two-keyword case already does. If matching a positional Hash to keywords is deliberate for some compatibility reason, it should at minimum bind the declared keyword to the Hash's value rather than to `{}`.

## Impact

Silent, and the value that arrives is wrong rather than merely late — a method that reads `x` gets `{}` where CRuby would never have entered the method at all. Any keyword-shaped API called with an options Hash hits it, which for Ruby 2D means the shape most of the library's constructors use.

## Environment

- Spinel commit: `42649df7`
- Ruby version: 4.0.6
- Platform: macOS 26 (arm64), Apple clang 21
