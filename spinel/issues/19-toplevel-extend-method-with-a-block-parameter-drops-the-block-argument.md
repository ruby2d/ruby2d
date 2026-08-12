# [Codegen] A method with a block parameter, reached through a top-level `extend`, is called with the block argument dropped

Found while porting [Ruby 2D](https://github.com/ruby2d/ruby2d) to Spinel.

Follow-up to [#3787](https://github.com/matz/spinel/issues/3787), whose reproduction passes. A top-level `extend` now makes a module's methods callable, but a method that declares a block parameter is called with that parameter missing.

## Description

A module instance method declaring `&block`, brought in with `extend` at the top level and called with an implicit receiver, is emitted as a call with the receiver `NULL` and the block argument omitted entirely. The function is declared to take both, so the generated C does not compile.

Declaring the block parameter is what triggers it. Whether a block is passed at the call site makes no difference.

## Reproduction

```ruby
module DSL
  def update(&proc)
    puts 'DSL#update'
  end
end

extend DSL

update { nil }
```

**Ruby 4.0.6:**
```
DSL#update
```

**Spinel (b51c880d):**
```
block_param.rb:9:21: error: too few arguments to function call, expected 2, have 1
spinel: C compilation failed
```

## Additional Findings

The generated C shows the shape directly. The definition takes two parameters:

```c
static mrb_bool sp_DSL_update(sp_DSL *self, sp_Proc *lv_proc);
```

and the call site passes one:

```c
sp_DSL_update(NULL);
```

| Variant | Result |
|---|---|
| `def update(&proc)`, called as `update { nil }` | rejected |
| `def update(&proc)`, called as bare `update` | rejected — the declaration alone is enough |
| `def update`, no block parameter | compiles and runs |
| `def update(n)`, an ordinary positional parameter | compiles and runs |
| a keyword parameter alongside the block, `def render(z: :foreground, &proc)` | rejected the same way — `sp_DSL_render(NULL, ((sp_sym)244))` against a three-parameter declaration, so the keyword is passed and only the block is dropped |

The last row is what shows the receiver and the block are handled separately: an explicitly passed keyword survives, and only the trailing block is lost.

## Environment

- Spinel commit: `b51c880d`
- Ruby version: 4.0.6
- Platform: macOS 26 (arm64), Apple clang 21
