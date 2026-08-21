# [Runtime] A method call through a Hash value fails with "for an instance of Class" when the Hash mixes a Module and an instance that both answer it

Found while porting [Ruby 2D](https://github.com/ruby2d/ruby2d) to Spinel: the event filter table maps some event types to a module (`Keyboard`, which answers `validate!` as a singleton method) and others to a `Vocabulary` instance, and every filtered `on` raised at registration.

## Description

A Hash whose values are a Module with singleton methods and an ordinary object, both responding to the same method, cannot dispatch that method through a value read out of the Hash: the call raises `undefined method 'v!' for an instance of Class`. With only modules as values ([mod1] below) or only instances, the same call works — it is the mix that breaks.

The receiver in the message is the value's *class* (`Class`, the module object's), which suggests the poly dispatch arm for a module-typed value looks the method up on the module's class rather than on the module's singleton.

Mapping a closed set of names to "the thing that validates them" and letting a module and an instance share that role is ordinary duck typing.

## Reproduction

```ruby
class Voc
  def initialize(n) = @n = n
  def v!(x) = "#{@n}#{x}"
end
module A; V = Voc.new('A'); def self.v!(x) = V.v!(x); end
module G; BUTTONS = Voc.new('G'); end
H = { a: A, g: G::BUTTONS }.freeze
if (m = H[:a])
  puts m.v!(1)
end
puts H[:g].v!(2)
```

**Ruby 4.0.6:**
```
A1
G2
```

**Spinel (f13e0ada):**
```
undefined method 'v!' for an instance of Class (NoMethodError)
```

## Additional Findings

| Variant | Result |
|---|---|
| As above | **NoMethodError** at the first call |
| Values are modules only (`{ a: A, b: B }`) | correct |
| Values are instances only (`{ a: A::V, b: B::V }`) | correct |
| Module's state memoized in a module ivar (`def self.voc = @voc \|\|= Voc.new`) | **NoMethodError** — the memoization is not the trigger |
| `A.v!(3)` called directly, no Hash | correct |

## Environment

- Spinel commit: `f13e0ada`
- Ruby version: 4.0.6
- Platform: macOS 26 (arm64), Apple clang 21
