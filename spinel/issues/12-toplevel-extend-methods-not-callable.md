# [Compile] Top-level `extend` of a module does not make its methods callable

Found while porting [Ruby 2D](https://github.com/ruby2d/ruby2d) to Spinel.

## Description

`extend`ing a module at the top level should add its instance methods to `main`. Calling one afterwards is rejected at compile time as undefined.

Top-level `include` of the same module works, so this looks like the sibling case of [#3775](https://github.com/matz/spinel/issues/3775) — which fixed `include` — rather than a new area.

## Reproduction

```ruby
module DSL
  def hello; 'hi'; end
end

extend DSL

puts hello
```

**Ruby 4.0.6:**
```
hi
```

**Spinel (489cbde7):**
```
spinel: t.rb:7: undefined local variable or method 'hello' for main (NameError)
```

## Additional Findings

**Working — `include` in the same position:**

```ruby
module DSL
  def hello; 'hi'; end
end

include DSL

puts hello              # prints hi
```

**Failing differently — an explicit receiver:**

```ruby
extend DSL

puts self.hello
```
> `unsupported puts argument: node 13 (CallNode `hello`) recv=-/ty-1`

So the method is not reachable either way, but the two forms are rejected at different points.

A module whose method takes and forwards a block is rejected as `unsupported call` rather than `NameError`:

```ruby
module DSL
  def self.window; @window ||= Win.new; end
  def update(&b); DSL.window.update(&b); end
end
extend DSL
update { }
```
> `unsupported call: node 39 (CallNode `update`) recv=-/ty-1 argc=0`

Ruby 2D reaches this through its public API. The library defines a `DSL` module of one-line delegations and extends it at the top level, which is what makes `set`, `update`, `render` and `show` available to a script. The port works around it by generating a top-level copy of each DSL method instead of extending.

## Environment

- Spinel commit: `489cbde7`
- Ruby version: 4.0.6
- Platform: macOS 26 (arm64), Apple clang 21
