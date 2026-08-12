# [Runtime] A keywords-only call binds the keyword hash to an optional positional parameter as well as to `**kwargs`

Filed as [#3808](https://github.com/matz/spinel/issues/3808). Found while porting [Ruby 2D](https://github.com/ruby2d/ruby2d) to Spinel.

## Description

A method declaring an optional positional parameter followed by `**kwargs`, called with keyword arguments and no positional, binds the keyword hash **twice**: once to `**kwargs`, correctly, and again to the optional positional, which should keep its default.

There is no error. The program compiles and runs, and any branch that tests the positional for `nil` takes the wrong path.

## Reproduction

```ruby
def inner(event = nil, **filters)
  puts "event=#{event.inspect} filters=#{filters.inspect}"
end

inner(key_down: :escape)
```

**Ruby 4.0.6:**
```
event=nil filters={key_down: :escape}
```

**Spinel (83d1315d):**
```
event={key_down: :escape} filters={key_down: :escape}
```

## Additional Findings

**Passing any explicit positional argument fixes it.** Only the keywords-only call form is wrong:

| Call | Result |
|---|---|
| `inner(key_down: :escape)` | **`event` gets the hash** |
| `inner(**{ key_down: :escape })` | **`event` gets the hash** |
| `inner(nil, key_down: :escape)` | correct — `event=nil` |
| `inner(nil, **f)` | correct — `event=nil` |
| `inner(:sym, key_down: :escape)` | correct — `event=:sym` |

So the double-splat is not the trigger; the absence of a positional argument is.

The declaration is a common idiom for an API taking either a symbol or keyword filters:

```ruby
def on(event = nil, **filters, &proc)
```

A method written that way dispatches on `event.nil?`, which is exactly the test the double binding defeats.

## Environment

- Spinel commit: `83d1315d`
- Ruby version: 4.0.6
- Platform: macOS 26 (arm64), Apple clang 21
