# Spinel build path

Research notes and working checklist for compiling Ruby 2D apps with [Spinel](https://github.com/matz/spinel), Matz's Ruby AOT compiler, as an opt-in alternative to the mruby default. Findings are from 2026-08-07 to 2026-08-10 on macOS arm64; mruby stays the default for `ruby2d build`. Spinel moves fast, so the commit matters: the initial research ran against `8b029022e663`, the MVP work against `f0f7dc0d7131`, and **everything was last re-verified against `1c3d99897ef3` (2026-08-10)**.

## What's in this directory

Everything worth keeping from the Spinel spike. Nothing here is a final home — it is a holding area for this branch.

| File | What it is |
|---|---|
| `README.md` | This document: findings, checklist, workarounds, and what to report upstream |
| `bouncing_balls.rb` | A port of `examples/bouncing_balls.rb` to the FFI path — the demo that runs today |
| `issues/` | Drafted upstream bug reports, one file per issue |

Experiments live in a scratchpad outside the repo and are disposable; anything worth surviving belongs here.

## Why Spinel fits

Spinel parses Ruby with libprism, infers types across the whole program, emits one C file, and invokes the system `cc`. The result is a standalone binary needing only libc and libm. Two pieces of Ruby 2D's existing design carry most of the integration:

**The main loop is already Ruby-owned on CRuby.** Spinel's FFI has no callbacks — C can never call back into Ruby — which would normally rule out an engine whose C layer drives the frame loop. But `Window#show` (`lib/ruby2d/window.rb:442`) already branches: CRuby runs `tick until @close` in Ruby, while mruby and WASM hand the loop to C. Spinel takes the CRuby-shaped path that already exists.

**`ext.c` already separates C primitives from Ruby bindings.** Its header describes "Ruby-callable bindings exposing libruby2d C primitives", and the shape "full-flatten" pattern passes vertices and colors as flat numeric args with nothing stored C-side. That maps onto Spinel FFI directly; the mruby binding layer drops out.

## Verified results

All of the following were run, not inferred. Spinel was built from source with `make deps && make`.

**A Spinel-compiled Ruby app opened a real SDL3 window** and rendered 30 frames from a Ruby-owned loop, linked against this repo's own `assets/platform/macos-arm64/lib/libSDL3.a` plus the macOS frameworks. Produced a 2.9 MB standalone binary.

**FFI covers the patterns Ruby 2D needs**: a 10-double positional call (the shape full-flatten pattern), an opaque `:ptr` handle held as a class ivar (the audio/image pattern), and an `:int_array` out-buffer (the `drain_events` pattern).

**Language constructs that work**, several of which `docs/limitations.md` reads as unsupported: `class << self`, `extend ClassMethods` inside a class body, `Struct.new` with a block, literal `instance_variable_get(:@x)`, mixin `include`, inheritance with `super` and keyword args, `sort_by(&:z)`, and stored user blocks (`w.update { }` then `@update_proc.call`) — the pattern every Ruby 2D app depends on.

**The sharp edge is module bodies.** A module that gets `include`d carries only plain `def` methods into the including class. `attr_reader`, `attr_accessor`, `alias_method`, and `alias` declared in a module body do *not* reach it — the method comes back undefined at the call site. The same declarations inside a *class* body are fine, as is `attr_reader` inside `class << self`; only `alias_method` fails there. This is the single most important rule for porting `lib/`, and it is not in Spinel's own docs.

### Performance

600 frames × 500 sprites of rotation math and z-sorting, pure Ruby so all three runtimes execute identical code, checksums verified identical. Best of 3, macOS arm64:

| Runtime | Time |
|---|---|
| mruby (bundled, current default) | 776 ms |
| CRuby 4.0.6 | 455 ms |
| Spinel | 175 ms |

**4.4× faster than mruby**, in a 205 KB binary. Spinel's own README claims ~6.1× over CRuby+YJIT across its benchmark suite; 2.6× over CRuby here reflects a workload dominated by float math and allocation rather than method dispatch.

## Step 0 results: the real `lib/` under Spinel

Done 2026-08-08. All 37 `LIB_FILES` were concatenated (8,628 lines) and run through `spinel -c`, then the MVP subset was compiled separately. **The MVP subset compiles clean**: 25 files, 5,439 lines of the real library, producing 7,138 lines of C, exit 0.

Getting there needed four mechanical fixes, plus neutralizing two features that are genuinely out of reach. The inventory:

| # | Issue | Sites | Kind |
|---|---|---|---|
| 1 | `attr_reader`/`attr_accessor` in `module Renderable` | `renderable.rb:171-173` — 13 declarations → 18 defs | **Mechanical** |
| 2 | `alias_method` in `class << self` | `window.rb:98` | **Mechanical** |
| 3 | `alias_method` / `alias` in `module Renderable` | `renderable.rb:174,347` | **Mechanical** |
| 4 | Dynamic `send` with a runtime/interpolated name | `window.rb:316,325`, `interactive.rb:39` | Needs redesign |
| 5 | Closure capture in the same filter lambda | `interactive.rb:39` | Needs redesign |
| 6 | `Window.<class method>(object)` fails to resolve | `add`, `remove`, `register_interactive`, `unregister_interactive` — 5 sites | **Spinel bug, unreduced** |
| 7 | `define_singleton_method` with `super()` | `button.rb:353` | Needs redesign; outside MVP |

Items 1–3 are the whole of the "module bodies" rule above and are semantics-preserving under CRuby and mruby too, so they can land on `main` independently of any Spinel work. Item 1 is the one that matters most — `Renderable` is included by every shape.

Items 4 and 5 are the same feature: the `on event: { ... }` hash-filter DSL, implemented twice (once in `window.rb` for window events, once in `interactive.rb` for per-object events). Both build a predicate name at runtime, which whole-program AOT cannot dispatch. **This is the most Spinel-hostile part of the library** and needs a compile-time-known predicate table rather than interpolated sends. The symbol-and-value forms of `on` are unaffected.

Item 6 is the one real unknown, and it now has a **partial workaround** (2026-08-08). `ClassMethods#add(object)` is defined as exactly `DSL.window.add(object)`, so rewriting the four internal call sites in `renderable.rb` and `interactive.rb` to call `DSL.window.<m>(self)` directly just inlines one delegation hop — semantically identical, and valid under CRuby and mruby too. With that plus the three mechanical fixes, **the MVP subset compiles clean with nothing neutralized**: 5,439 lines in, 7,520 lines of C out, exit 0.

The workaround is partial. It unblocks the internal path — which is what matters, since shapes default to `add: true` and auto-register on construction — but the public class method still fails: appending `Window.add(c)` as user code to the compiled subset reproduces the error. `Window.add`/`Window.remove` are not documented in `USAGE.md` and are unused by any example, so the practical exposure is low, but the underlying bug is unfixed.

Seven hand-reductions have now all *passed* in isolation: extend-with-object-argument, module-before-class ordering, extend delegating to another object, class/instance name collision, polymorphic argument types, class-to-instance self-delegation, and a single shared call site in an included module fanning out to five including classes. The last of those was the leading hypothesis and it did not hold. The trigger needs `bin/spinel-reduce` (run it with `SPINEL=/path/to/bin/spinel` in the environment) against the full concatenated lib, not more guessing.

## Deliberate feature gaps on the Spinel target

These are **not** compiler bugs and there is nothing to report upstream. They are things the Spinel target does not offer, decided rather than discovered. Both are switched off in `cli/spinel.rb`; the mruby and CRuby builds are unaffected.

### The class pattern is unsupported

`USAGE.md` documents two usage patterns. The **DSL pattern** (`update do ... end`, top-level shapes) works. The **class pattern** — subclassing `Ruby2D::Window` and overriding `update` / `render` — does not.

It hinges on `Window#overrides?`, which asks the ancestor chain which module defines a method:

```ruby
wrappers = Window.ancestors - [Window]
owner = self.class.ancestors.find do |mod|
  !wrappers.include?(mod) && mod.instance_methods(false).include?(name)
end
```

That is runtime reflection over the class graph. Whole-program AOT bakes the graph at compile time and keeps no metaobject to query, so this is inherent to the model, not a defect in Spinel. `overrides?` is rewritten to `false` on this target, so `@overrides_update` / `@overrides_render` are always off and the frame loop runs the DSL procs only.

**It is not permanently unsupportable** — only this *mechanism* is. Detecting the pattern without reflection (for instance, having the base `update` record that it was used as the DSL setter, and treating "never set" as the class pattern) would restore it for every runtime. That is a `window.rb` design change affecting all three targets, and it has to respect the prepended-module case the current comment at `window.rb:841-848` calls out, so it was out of scope here.

### Per-object events are unsupported

`Interactive` reaches the shapes through a nested include — `Renderable` includes it, the shapes include `Renderable` — and that second hop does not carry the methods across, so `object.interactive?` is undefined at run time. The `respond_to?` guard in front of it is answered from the compile-time class graph and gets it wrong.

Registration is switched off rather than worked around, so `on` / `off` on a shape does nothing on this target. Unlike the class pattern this one probably *is* a bug rather than a limit — a nested include is ordinary Ruby — but it was not isolated, so it is listed here rather than as a reproducer.

## To report upstream

Every workaround in this document exists because of one of these. Spinel's contributing notes ask for "a 5-line Ruby that fails in Spinel but passes in CRuby", so the table separates the ones already in that shape from the ones that still need work. Filing the top group costs little and could clear whole categories at once.

**Filed upstream on 2026-08-10** as #3771-#3777, each verified against `1c3d99897ef3` with both CRuby and Spinel output captured. The drafts stay here as the local record:

| Issue | Draft | Bug |
|---|---|---|
| [#3771](https://github.com/matz/spinel/issues/3771) | `issues/01-safe-navigation-nan.md` | Safe navigation on the right of `\|\|` returns `NaN` instead of `nil` — **silent** |
| [#3772](https://github.com/matz/spinel/issues/3772) | `issues/02-forwarded-stored-block-loses-capture.md` | A block forwarded with `&b` and then stored loses its captured locals — **silent** |
| [#3773](https://github.com/matz/spinel/issues/3773) | `issues/03-self-escaping-superclass-method.md` | `self` escaping a superclass method is typed as the superclass — the bug that blocked the MVP |
| [#3774](https://github.com/matz/spinel/issues/3774) | `issues/04-module-body-declarations.md` | `attr_accessor` / `alias_method` in a module body do not reach the including class |
| [#3775](https://github.com/matz/spinel/issues/3775) | `issues/05-toplevel-include-arity.md` | Top-level `include` emits a call with the wrong arity, failing the C compile |
| [#3776](https://github.com/matz/spinel/issues/3776) | `issues/06-alias-method-in-singleton-class.md` | `alias_method` inside `class << self` produces no callable class method |
| [#3777](https://github.com/matz/spinel/issues/3777) | `issues/07-return-in-expression-position.md` | `return` in expression position rejected (`x = expr or return`) |

Filed in this order. The ranking weighs three things:

**Silent first.** The top two produce wrong values with no error, no exception, and no diagnostic. They are worse than their frequency suggests because they generate no bug reports — a user hits one and sees a program that quietly misbehaves, so nothing ever reaches an issue tracker. Everything below them announces itself.

**Then breadth.** #3 blocks any object that registers itself through an inherited method, and carries the nastiest property of the set: a mistyped call site poisons inference for that path even when it never executes, so avoiding the pattern at run time does not help. #4 is `attr_accessor` in a module, which is everywhere in Ruby.

**Loud and narrow last.** #5 through #7 fail at compile time with a clear message and have simple rewrites.

Ordered by suggested filing priority, not discovery (the filenames keep their original numbers). The ranking weighs three things:

**Silent first.** The top two produce wrong values with no error, no exception, and no diagnostic. They are worse than their frequency suggests because they generate no bug reports — a user hits one and sees a program that quietly misbehaves, so nothing ever reaches an issue tracker. Everything below them announces itself.

**Then breadth.** #3 blocks any object that registers itself through an inherited method, and carries the nastiest property of the set: a mistyped call site poisons inference for that path even when it never executes, so avoiding the pattern at run time does not help. #4 is `attr_accessor` in a module, which is everywhere in Ruby.

**Loud and narrow last.** #5 through #7 fail at compile time with a clear message and have simple rewrites.

**Duplicate check (2026-08-10).** Searched the tracker before filing. No open issue covers any of the seven. One relevant piece of prior art: safe navigation returning a wrong value is the subject of two *closed* issues, [#701](https://github.com/matz/spinel/issues/701) (`&.` on nil returning `""` / `0`) and [#3269](https://github.com/matz/spinel/issues/3269) (`&.` on an ivar producing a wrong value). Both were read and are the same family as draft 01, which now cites them — ours is likely a variant those fixes missed, since the plain `&.` form is correct today and only the `||` case is wrong. The nearest module-related issues, [#3734](https://github.com/matz/spinel/issues/3734) (`module_function` private copy unavailable to an including class) and one on `Method#owner` naming the including class, are adjacent to draft 04 but not the same bug.

Each follows the format of [#3765](https://github.com/matz/spinel/issues/3765) and [#3766](https://github.com/matz/spinel/issues/3766): a titled category, a short description, a minimal reproducer, CRuby and Spinel output side by side, an "Additional Findings" section contrasting what *does* work, and a pinned commit. The working/failing contrast is worth keeping — it is what makes each report actionable rather than just a complaint.

**Not yet drafted — reproducer still missing:**

| Bug | Reproducer |
|---|---|
| `ffi_func` rejects a computed type array | `ffi_func :f, [:double] * 2, :void` vs the spelled-out list |
| `-Wl,-dead_strip` is chosen by **host** OS, so an Emscripten cross-build from macOS fails at link (`wasm-ld` wants `--gc-sections`) | `spinel prog.rb --cc=emcc` on macOS, against an emcc-built runtime |
| `spinel-reduce --oracle unsupported` reports "the input is not interesting" on a program that does fail with an unsupported-call error | any of the above under that oracle |

**Needs more work before filing:**

| Bug | State |
|---|---|
| **Poly value assigned into a monomorphic slot.** A poly expression (e.g. indexing a parameter that an optional kwarg made `NilClass \| Array`) is assigned straight into an `mrb_int` / `sp_sym` local with no unboxing. Assigning `sp_RbVal` to `mrb_int` is never valid C | No minimal case — plain destructuring compiles fine; it needs the polymorphism. But the emitted C is self-evidently wrong, so this is probably filable as-is with the generated snippet. **Highest value: it is the single largest source of failures here** |
| **A module method is called but never emitted.** `sp_Renderable__unrotate` appears once as a call and zero times as a definition or declaration | Not isolated. Only shows in whole-program context |
| **`extend`-provided class methods unresolvable through a constant receiver** (issue 6) | Not isolated after ten attempts, all of which passed standalone. Needs `spinel-reduce` with an oracle that runs the candidate under CRuby, not just greps compiler output |

## Where fixes belong

Two homes, and the choice is deliberate:

- **`lib/`** — when the change is defensible Ruby on its own merits, it goes in the library, the way mruby accommodations already do. `@key_names = {}` instead of `[]` is the model: scancodes are sparse, so a Hash was the better structure anyway, and an empty Array literal gives an AOT compiler no element type to infer from. These changes stay correct under CRuby and mruby and need no build-time machinery.
- **`cli/spinel.rb`** — only when the change would make `lib/` worse to read, or is pure build-time synthesis (the DSL top-level shims, `Ruby2D.web?`). Each transform asserts it still matches, so drift fails the build.

Prefer `lib/`. The transforms are string matching against library source and are the fragile half.

**Stopping rule:** grind through codegen failures, flagging each as an upstream candidate — but if one turns out to be a user-facing feature or a DSL form Ruby 2D cannot express under Spinel, stop and file upstream rather than degrade the public API.

## Workarounds to re-check

Spinel moves fast, so every workaround here is provisional. **Last re-checked against `1c3d99897ef3` on 2026-08-10.** That pass dropped two rows — `Hash#delete_if` is now implemented, and an extend-provided method returning nil-or-raise now resolves — which is the whole point of keeping this table. After a `git fetch` in the Spinel checkout, re-run the probes and delete any row that passes. **Do not let these calcify into permanent Ruby 2D design.**

One caution learned the hard way: a probe passing in isolation does **not** mean the workaround can be dropped. The nested-`include` bug behind the disabled per-object events is fixed in a standalone probe yet still fails in the real library. Re-check by removing the transform and rebuilding the subset, not by running the probe alone.

The probes live in the research scratchpad, which is disposable — recreate them from the "Re-check by" column, which describes each in one line.

| Workaround | Re-check by |
|---|---|
| Rewrite `Window.<m>` → `DSL.window.<m>` for every delegating `ClassMethods` entry (issue 6) | Drop `spinel_bypass_window_class_methods` and recompile the smoke subset |
| Top-level `def` shims instead of `include Ruby2D` + `extend Ruby2D::DSL` | `include`/`extend` a module with instance methods at top level, call one |
| Expand `attr_*`/`alias` out of `module Renderable` (issues 1-3) | `attr_reader` in a module, `include` it, call the reader |
| Define `Ruby2D.web?` and `Ruby2D.render_ready_check` in Ruby | Drop them and recompile the smoke subset |
| Expand `x = expr or return` to a statement guard | `return` in expression position |
| Spell out `ffi_func` type arrays instead of `[:double]*6` | Declare an `ffi_func` with a computed type array |
| `emcc` shim rewriting `-Wl,-dead_strip` → `-Wl,--gc-sections` | `spinel hello.rb --cc=emcc` against a wasm-built runtime |

Two of these are worth upstreaming rather than carrying: the `-dead_strip` host-vs-target flag bug, and issue 6 once reduced. The `attr_*`-in-module expansion is worth keeping regardless — it is a plain refactor that costs nothing under CRuby or mruby.

## Milestone: a square on screen (2026-08-08)

**A Spinel-compiled Ruby program opened a real window, ran a Ruby-owned main loop, moved a square, rendered 180 frames through Ruby 2D's own `R2D_*` core, and exited cleanly.** 4.9 MB binary.

What that establishes, all of it previously unproven:

- The C core compiles with **no Ruby engine at all** (`-DRUBY2D_NO_RUBY`) — `ruby2d.c`, `window.c`, `shapes.c`, `fps.c`, `font.c` into a 70-symbol `libruby2d_core.a`.
- It links into a Spinel binary alongside the bundled SDL3 statics and the macOS frameworks.
- Spinel's FFI drives the real `R2D_*` API: 12-argument calls, `:float` color components, `:bool` returns, `:str` error strings.
- A Ruby-owned loop pumps SDL3 at 60fps without C ever calling back into Ruby.

**What it does not yet establish**, and the distinction matters: the test program is hand-written Ruby calling `ffi_func` declarations directly. It is *not* a `ruby2d` script — nothing in `lib/` is involved. The MVP as defined ("a plain Ruby 2D script that draws a moving square") still needs the `Ext` adapter that maps `lib/`'s calls onto these entry points, plus the CLI wiring. The runtime risk that motivated the narrowed MVP is now retired; what remains is integration.

### How the C was made Ruby-free

`window.c` is the awkward one: 37 `ruby2d_ext_*` wrappers interleaved with 20 `R2D_*` cores across 2,000 lines, with no region to guard wholesale. Each wrapper is individually wrapped in `#ifndef RUBY2D_NO_RUBY`. Ugly but mechanical and reversible; the cleaner end state is splitting bindings into their own file once all 37 wrappers are thin adapters (only 6 are so far).

`font.c` needed just one guard — it has a `// Ruby Bindings` section header with nothing Ruby-free after it. **`window.c` is the outlier here**: `text.c`, `image.c`, `canvas.c`, `audio.c`, and `ext.c` have no such header either, so they will need per-wrapper guards or a tidy-up when their turn comes.

In `ruby2d.h`, `R_VAL` / `R_CLASS` / `R_ID` become placeholder types under `RUBY2D_NO_RUBY` so the ~91 binding *declarations* still parse — a declaration costs nothing, and guarding them all would bury the header. The accessor macros (`r_ivar_get` and friends) are deliberately left **undefined**, so a Ruby call that creeps into an `R2D_*` core fails to build rather than silently doing nothing on the Spinel target.

## Stub-`Ext` smoke test: does `lib/` actually *run*? (2026-08-09)

Compiling `lib/` proved nothing about running it, so the next step stubbed every `Ext` entry point as a no-op and asked whether the library itself works under Spinel — no C, no FFI, so a failure can only be Spinel or `lib/`. A CRuby run of the same generated source is the baseline, and it passes: objects construct, register, z-order, mutate, tick, and remove.

The adapter's key assumption checks out: `instance_variable_set(:@mouse_x, v)` on *another* object with a literal name works, so the Ruby-side ivar sync that replaces C's is viable.

Getting the subset to compile needed five more transforms beyond the original three, all now in `cli/spinel.rb`:

| Issue | Sites | Fix |
|---|---|---|
| `Ruby2D.web?` is registered from C, so it vanishes with the binding layer | 1 | Define it in Ruby; the Spinel target is native |
| `shown?` with an implicit receiver inside the extended `ClassMethods` | 1 | Make it `Window.shown?` |
| `Window.render_ready_check` — a `ClassMethods` entry that is not a delegation | 13 call sites | Route through a module function |
| `return` in expression position (`x = expr or return`) | 6 | Expand to a statement guard |

**Issue 6 is systemic, not a fixed list of sites.** The earlier MVP compile needed only four rewrites; the smoke test exercises more code and surfaced more, because Spinel's whole-program inference only analyzes *reachable* code. Chasing call sites is therefore wrong — `spinel_bypass_window_class_methods` now reads the delegating methods out of `window/class_methods.rb` and rewrites by method name, so the list cannot go stale as new paths become reachable.

Hand-reduction of issue 6 is now abandoned at **ten attempts**, every one passing in isolation: extend-with-object-argument, module-before-class ordering, extend delegating to another object, class/instance name collision, polymorphic argument types, class-to-instance self-delegation, a shared call site in an included module fanning out to five classes, an extended method that always returns a value, one that only returns nil or raises, and the same body via `class << self`. The trigger exists only in whole-program context. It needs upstream eyes, not more guessing.

### Root cause of the codegen failures (2026-08-09)

**Not a user-facing blocker.** The suspicion that this was symbolic alignment (`x: :center` making a variable Integer-or-Symbol) was tested and is wrong.

The actual pattern, from the generated C: an optional keyword argument like `points: nil` makes the parameter polymorphic (`NilClass | Array`), so Spinel types it `sp_RbVal` and cannot resolve `points[0]`. It emits a runtime tag dispatch instead — if Integer do a bit shift, if String char-at, if Set `Set#[]`, and so on — whose result is also `sp_RbVal`. That poly result is then assigned straight into locals Spinel typed `mrb_int`, which is the invalid C. The same shape explains the `sp_sym` cases and the `void`-return mismatches.

So it is one bug with many symptoms: **a poly value assigned into a monomorphic slot with no unboxing**. Assigning `sp_RbVal` to `mrb_int` is never valid C, so this is squarely a Spinel codegen bug and a good upstream report even without a minimal reproducer — plain destructuring (`x, y = arr`) compiles fine in isolation; it only breaks when the source expression is polymorphic.

**The workaround is proven**: replacing `x, y = expr` with an indexed temporary (`p = expr; x = p[0]; y = p[1]`) removed 18 of 60 errors in one pass. There are roughly 40 such sites in `lib/`. Because that rewrite is a real readability regression, it belongs in `cli/spinel.rb` rather than `lib/` — the exception to the prefer-`lib/` rule above.

Error count trajectory:

| Step | square-only (19 files) | full subset (25 files) |
|---|---|---|
| Baseline | — | 60 |
| `_unrotate` destructuring rewritten by hand | — | 42 |
| `@key_names = {}` (landed in `lib/`) | — | 41 |
| Trim to square-only | 24 | — |
| `spinel_expand_massign` — general destructuring transform | 8 | 15 |
| `Color.set(colors)` qualified (landed in `lib/`) | 7 | — |
| `Quad.draw_immediate` returns `nil` explicitly (landed in `lib/`) | 5 | — |
| `x_align=` / `y_align=` drop safe navigation (landed in `lib/`) | 3 | — |
| `Hash#delete` on a poly ivar rewritten | **2** | **5** |

The destructuring transform is the single biggest lever, which follows from the root cause above: it is one bug reached from ~40 call sites. Its matcher tracks bracket depth rather than using a regex, because `x, y = f(a, b)` (rewrite) and `a, b = @x, @y` (leave alone — parallel assignment compiles fine) are otherwise indistinguishable; splats and block parameters are skipped too. Nine edge cases are covered by a unit test.

Most errors live in gamepad handling, mouse dispatch, and shapes a square never touches — hence the gap between the two columns, and why the MVP trims the subset.

Four more Ruby shapes that trip codegen, each confirmed by fixing it and re-measuring:

- **Safe navigation.** `@x_align = sym&.to_sym` is typed as returning a plain Symbol, then miscompiled for the nil case. Writing `sym.nil? ? nil : sym.to_sym` — identical semantics — types correctly. Only four `&.` uses exist in `lib/`; the other three are untested.
- **A method returning different types on different paths.** `Quad.draw_immediate` returned a void `Ext` call on one branch and an incidental color array on another. It is called for effect, so an explicit trailing `nil` settles it.
- **An ambiguous method name on a polymorphic receiver.** An ivar first assigned in a module body stays poly, and `@gamepads_by_id.delete(id)` then resolves to `String#delete`. Unambiguous methods (`[]`, `[]=`, `key?`) are fine, which is why only `delete` needed rewriting.
- **A bare call colliding with a top-level DSL shim.** `Color.for_render` called `set(colors)`, which resolved to the generated top-level `set` rather than `Color.set`. Qualifying the receiver fixes it — and is clearer Ruby anyway, since Ruby 2D really does have both.

### Runtime: the scene graph, and the bug behind it (2026-08-10)

The square-only subset **compiles to zero C errors, links, and runs**. `Square.new` succeeds and the object registers with the window. Execution then fails in `Window#render_objects` — `@objects.each { |obj| obj._render_scene if obj.visible? }` — with `NoMethodError`, reporting the object as `Ruby2D::Quad` when it is a `Square`.

**Root cause found, and it is not what the symptom suggested.** It has nothing to do with polymorphic receivers. When a method defined on a *superclass* stores `self`, and that method is called on a subclass instance, the stored value is typed as the superclass and every later dispatch on it fails. The constructor is incidental — an ordinary inherited method behaves the same. Modules alone are fine; it is inheritance that loses the type, including a module included into a base class and called on a subclass instance, which is Ruby 2D's exact shape: `Renderable` is included by `Quad`, and every `Square` reaches `add` through it.

Reduced to 15 lines and filed as `issues/03-self-escaping-superclass-method.md`.

**The subset now runs.** Removing the mistyped call site — the `self.add if add` in `Quad#initialize` — and registering from `Square#initialize` instead gets the square-only subset all the way to completion under Spinel. Note it is not enough to *skip* the bad call site at run time by passing `add: false`: the site has to be gone. A single mistyped call poisons the inferred parameter type for everything flowing through that path, whether or not it ever executes.

Progress is now visible directly: `gh issue list --repo matz/spinel --state all --search "3771..3777"`, or `gh issue view <n> --repo matz/spinel`. A closed issue is the signal to re-check the matching workaround.

**Decision (2026-08-10): wait for upstream rather than work around this.** Moving registration out of `Quad#initialize` into each concrete shape class does fix it, but that is roughly 13 classes each repeating a line that exists only to dodge a compiler bug, in `lib/` where all three runtimes would carry it. The bug is filed, it is squarely Spinel's to fix, and the branch is cheap to resume — so the Spinel target stays blocked here on purpose. Re-check by restoring `self.add if add` to `Quad#initialize` and rebuilding the subset.

One behavioral difference survived: the per-frame `update` block ran but every counter it wrote to stayed at zero. That is a second silent bug — a block forwarded through the generated DSL shim and then stored loses its captured locals — filed as `issues/02-forwarded-stored-block-loses-capture.md`.

**How it was found matters more than the bug.** Eleven attempts to reduce *down* from the failing program all passed in isolation. Scaling *up* from a passing probe — adding one structural feature at a time until it broke — found it on the first try, then bisected to two required ingredients (an inheritance chain, and self-registration from inside the constructor) in one more pass. For whole-program-context failures, build up rather than cut down.


**Earlier, on compilation: 2 errors, both from the single `sp_Renderable__unrotate` call** — one undeclared-function, one cascade from it. Three hypotheses have been tested and killed: multiple assignment, `instance_variable_defined?`, and the module-typed receiver being unable to resolve `rx`/`ry`. It is the last thing between the subset and clean C.

Measure with `-ferror-limit=0`. Clang's default limit is 20, and it will silently cap the count — an early before/after comparison here read "20 → 20" while the real numbers were 60 → 42.

### The current blocker: invalid generated C

With those transforms the subset **passes Spinel's Ruby analysis** (`spinel -c` succeeds, 5,806 lines in) but the **emitted C does not compile** — 20 errors. This is a different and harder class than the API gaps above: not "Spinel rejects this Ruby" but "Spinel accepts it and emits bad C."

Two distinct shapes, from `--no-line-map` output (the `#line` map points at misleading places, so disable it before reading these):

- **A module method is called but never emitted.** `sp_Renderable__unrotate` is called from `Rectangle#contains?` and has no definition in the output. `Renderable#_unrotate` returns a two-element array destructured by the caller (`x, y = _unrotate(x, y)`), which is the likeliest trigger. This is the "module bodies" rule again in a more severe form — not a missing accessor, a missing function.
- **Type confusion between `mrb_int`, `sp_RbVal`, and `const char *`** — 15 of the 20 errors are assignments of `sp_RbVal` to `mrb_int`, plus `void` returned from functions typed to return a value.

Both are Spinel codegen bugs rather than anything a source transform can paper over, so this is where the MVP currently stands. The good news is that it is a *narrow* failure surface with the FFI and C layers already proven independently, and the smoke test is a much better reduction vehicle than the earlier attempts — it is pure Ruby, has a passing CRuby baseline, and needs no SDL.

## Blockers

**Top-level `include` / `extend` is miscompiled.** `lib/ruby2d/cli/build.rb:248` appends exactly `include Ruby2D` and `extend Ruby2D::DSL`. Spinel emits a call like `sp_DSL_on_thing(1LL)` for a function expecting two arguments, so it fails as a C compile error rather than silently misbehaving. Not a keyword-argument issue — positional-only fails identically. `include` inside a class body is fine.

*Workaround, verified:* `lib/ruby2d/dsl.rb` defines only 14 instance methods, so the Spinel path emits explicit top-level `def` shims delegating to module functions instead of the two-line `include`/`extend` preamble.

**`ffi_func` type arrays must be literal.** `[:double]*6` fails to parse; the spelled-out list works. Affects codegen style only.

**Apps using `method_missing`, `eval`, or runtime `define_method` will not compile.** This is inherent to whole-program AOT, not a bug. It is the main reason mruby stays the default, and it belongs in user-facing docs when this ships.

## Porting inventory

The C bridge is 91 `r_define_class_method` bindings against 91 distinct `Ext.*` call sites in `lib/` — they match exactly, so the surface is closed and countable.

| File | Bindings | ivar ops | Notes |
|---|---|---|---|
| `shapes.c` | 0 | 0 | **Zero Ruby API references — links as-is** |
| `fps.c` | 0 | 0 | **Zero Ruby API references — links as-is** |
| `audio.c` | 11 | 0 | Opaque-handle pattern, maps straight to `:ptr` |
| `ext.c` | 16 | 1 | Shape full-flatten, near-direct port |
| `ruby2d.c` | 1 | 0 | — |
| `canvas.c` | 18 | 7 | Mostly flat drawing ops |
| `image.c` | 4 | 14 | Pass-self, needs flattening |
| `text.c` | 2 | 5 | Pass-self, needs flattening |
| `font.c` | 2 | 5 | Pass-self, needs flattening |
| `window.c` | 37 | 34 | See below |

The cost is concentrated in the **pass-self** pattern: 66 `r_ivar_get`/`r_ivar_set` sites (57 of them reads) where C reaches into Ruby objects. Spinel FFI cannot do that, so each needs a scalar-argument variant.

`window.c` needs more than flattening. It holds 37 ext wrappers against only 11 `R2D_*` definitions, interleaved from line 247 through 1231 — the SDL3 window lifecycle and event-polling logic lives *inside* the binding functions, not in separable `R2D_*` primitives. The Spinel path therefore needs a thin Ruby-free C shim exposing flat window and event entry points, rather than linking the existing layer.

## WebAssembly

Spinel documents no wasm support; the only "wasm" mention in the repo is a note about a CLI name collision with Fermyon's `spin`. It nonetheless works, and the blockers are small:

1. Its runtime ships as a native archive. **All 25 runtime modules recompiled with `emcc` with zero source changes and zero failures.**
2. It emits `-Wl,-dead_strip` based on *host* OS (`src/main.c:585`), which `wasm-ld` rejects. Swapping to `--gc-sections` fixes it — a genuine host-vs-target bug worth reporting upstream.

With those two, `hello.rb` built to a 132 KB wasm module running Ruby classes and loops under node. Wiring this to SDL3 and Emscripten is a separate lift and is explicitly out of MVP scope, but the path is real.

## MVP

**Goal: a plain Ruby 2D script that draws a moving square, built with `ruby2d build --spinel`, that runs.** One binary, one shape, closeable.

Narrowed to this on 2026-08-08. Everything verified up to that point was compile-time, and compiling proves nothing about whether the thing works — the remaining risk is all runtime (GC interaction, float marshalling across FFI, the Ruby-owned loop actually pumping SDL). A single running binary collapses that category. The square *moves* because a static one can pass while frame 2 crashes, and the per-frame path is where both the risk and the performance story live.

The walking skeleton needs about 8 FFI entry points, not 91: `window_show`, `poll_events`, `begin_frame`, `end_frame`, `window_close`, `draw_quad_uniform`, `now`, and display dimensions. Notably it does **not** need `drain_events` — the hardest extraction, since it returns a Ruby array — because window close runs off the flag `poll_events` sets (`window.rb:610`), not the event queue. Input dispatch, and therefore `drain_events`, comes after the skeleton runs.

Deliberately not proven by the MVP: input handling, textured objects (image/text/canvas/audio), the variadic shapes (Polygon/Polyline, which need a `float`/`double` conversion shim — Spinel's `:float_array` is `const double *` while `R2D_DrawPolygon` takes `const float *`), and the performance claim on a real workload. All follow-ons, none risky once a binary runs.

That cut line is deliberate. Shapes are where the bindings are already flat (`ext.c`, `shapes.c`), and image/text/canvas/font are where 31 of the 66 pass-self ivar sites live. The MVP proves every structural question end to end — CLI opt-in, lib compilation, the FFI bridge, SDL3 linking, a Ruby-driven frame loop with real input — while deferring the expensive, repetitive flattening work.

The subset, as a `LIB_FILES` slice — this is the exact list that compiled clean in Step 0, 25 of the 37 files:

```ruby
mruby_compat cli/colorize exceptions warnings
window/class_methods window/key_events window/mouse_events
window/gamepad_events window/object_events
gamepad window interactive renderable color
circle ellipse line polygon polyline quad rectangle square triangle vertices
dsl
```

Dropped for the MVP: `audio`, `canvas`, `font`, `image`, `text`, `bitmap_text`, `sprite`, `sprite_sheet`, `tileset`, `button`, `json_parser`, `atlas_parser`.

### Checklist

- [x] **Step 0 — compile the real `lib/`.** Done; see [Step 0 results](#step-0-results-the-real-lib-under-spinel). The MVP subset compiles clean.
- [ ] Land fixes 1–3 from the Step 0 table (expand `attr_*`/`alias` in `module Renderable`, `alias_method` in `class << self`). Safe under CRuby and mruby, so these can go to `main` on their own.
- [x] Unblock issue 6 for the MVP — rewrite the 4 internal call sites to `DSL.window.<m>(self)`. Verified: MVP subset compiles clean, nothing neutralized. Provisional; see [Workarounds to re-check](#workarounds-to-re-check).
- [ ] Reduce issue 6 with `bin/spinel-reduce` and report upstream. The public `Window.add(obj)` class method still fails, so the bug is worked around, not fixed.
- [ ] Redesign the `on event: { ... }` hash-filter path around a compile-time predicate table (issues 4 and 5), or gate it off on the Spinel target for the MVP.
- [ ] `find_spinel` in `build.rb`, mirroring `find_mrbc` (`build.rb:162-174`): `RUBY2D_SPINEL` → stamped cache → `$PATH`. See [Getting Spinel](#getting-spinel).
- [ ] `ruby2d setup --spinel` builds Spinel into the per-user cache, reusing the existing stamp model (`build.rb:126-137`). Not needed while `RUBY2D_SPINEL` covers development.
- [ ] `--spinel` flag in `bin/ruby2d`, position-independent like `--native`/`--web` (`bin/ruby2d:138`), plus a `# ruby2d:compiler spinel` source directive mirroring `# ruby2d:assets`.
- [ ] Thin C shim: flat, Ruby-free window lifecycle and event entry points. Compile with `shapes.c` and `fps.c` (both already Ruby-free) into a static archive.
- [ ] `lib/ruby2d/spinel/ext.rb`: hand-written `ffi_func` declarations for the MVP subset. Hand-writing is right at this size, but it duplicates the binding list and *will* drift from `ext/` — a shared manifest generating both is the eventual answer, and the drift is a conscious MVP tradeoff, not an oversight.
- [ ] Replace the `include Ruby2D` / `extend Ruby2D::DSL` preamble with generated top-level DSL shims on the Spinel path only.
- [ ] Link step: `--link <archive>` for the SDL3 statics (Spinel places them between the generated TU and its runtime, exactly where they need to go) and `--cc` to carry the macOS frameworks.
- [ ] Run an existing example unmodified — a shapes-only one — and confirm it renders and takes input.
- [ ] Benchmark that example against the mruby build.

Reusable without change: asset bundling, `ruby2d launch --native`, and the macOS `.app` bundle step. Only compile and link are swapped.

### Explicitly out of scope for the MVP

Image, text, canvas, font, and audio bindings; the WebAssembly target; Windows and Linux (Spinel supports Linux and macOS, but not native Windows — Windows needs WSL); and any generated-binding tooling.

## Getting Spinel

Spinel is **not** vendored into `assets/`. Two reasons beyond keeping the submodule clean: `assets/` is a shallow submodule of a separate repo (`ruby2d/assets`), so anything added there means a commit in that repo plus a pointer bump here; and the gem is already ~34 MB, while Spinel is a large repo that builds its own compiler and runtime archives. Taxing every user for a feature few opt into is what `ruby2d setup` already exists to avoid.

Instead, Spinel is resolved at build time in this order:

1. `RUBY2D_SPINEL` — path to a `spinel` binary. The development path: the compiler is a moving target, and this keeps a local checkout entirely out of the tree. Mirrors how `RUBY2D_ASSETS_ROOT` lets `setup` and `build` agree on a location.
2. The per-user cache built by `ruby2d setup --spinel`, version-stamped like the SDL3/mruby build (`.ruby2d-version`, `setup.rb:171`).
3. `$PATH`.

Spinel builds to a self-contained `bin/spinel` with no runtime dependencies, so a checkout anywhere plus `RUBY2D_SPINEL` is enough to develop against — no repo changes at all. That is how the research in this document was done.

Note that `make deps` fetches libprism and rbs from RubyGems, so `setup --spinel` needs network access. Same as the existing SDL3 flow, but a different enough failure mode to deserve its own message.

## Open questions

- What is the root cause of issue 6 (`Window.<class method>(object)`)? Seven hand-reductions all passed in isolation, including the leading shared-call-site hypothesis. Worked around for the MVP but not fixed.

  Reducing it needs `bin/spinel-reduce` with `SPINEL=/path/to/bin/spinel` set and a **custom, structure-guarded oracle**. Two traps, both hit on 2026-08-08. The built-in `unsupported` oracle reports "not interesting" and refuses to start. And an oracle that only greps the compiler output for the error is too loose: the reducer cheerfully deletes `include Ruby2D` and the shape class, converging on a 249-line case that errors because `Window` is an undefined constant — which fails under CRuby too (`NameError`) and is worthless as an upstream report, since the ask is code that fails in Spinel but *passes* in CRuby. Guard the oracle with `grep` assertions for the structure that makes it a real reproducer (`include Ruby2D`, `module ClassMethods`, `extend ClassMethods`, `def add(object)`, `Window.add(`, `DSL.window`) before checking the compiler output.
- ~~Does the shim approach for `window.c` stay thin?~~ **Answered 2026-08-08: it does not.** `ruby2d_ext_window_poll_events` alone runs ~250 lines (`window.c:374-626`) of gamepad enumeration, SDL event translation, and event-buffer pushes that are already Ruby-free — the wrapper touches Ruby only at its boundaries, to read the window object and sync state back to ivars. The other tick functions (`drain_events`, `begin_frame`, `end_frame`) have the same shape. A standalone shim would have to duplicate all of it and would drift from `window.c` immediately, so the `#ifdef`-and-expose approach is the right one: guard the Ruby-specific boundaries and add flat scalar entry points beside them, letting one body serve both bridges.
- Spinel string literals are always frozen and `--disable=frozen-string-literal` is rejected outright. `lib/ruby2d/text.rb` already does `.dup.freeze` deliberately, so this looks fine, but it is unverified against the real library.
- How should `ruby2d build` report a Spinel compile error? Its diagnostics point at the concatenated source, so the path-rewriting trick used for `mrbc` (`build.rb:286-297`) likely needs an equivalent.

## Reproducing

```sh
git clone --depth 1 https://github.com/matz/spinel.git
cd spinel && make deps && make          # builds bin/spinel and bin/spin
./bin/spinel app.rb --link /path/to/libSDL3.a --cc="cc -framework Cocoa ..." -o app
```

Useful flags: `-c` emits C without linking, `-S` prints it to stdout, `-E` compiles and runs, `--link` adds an archive, `--cc` overrides the compiler, `-I` adds a feature root for `require`.

`--cc` is used verbatim as the command prefix, so extra flags can ride along: `--cc="cc -L/path -framework Cocoa"`. That is how the macOS frameworks were passed.

**Gotcha with `-c`:** driving the linker yourself means supplying Spinel's runtime too, or the link fails on undefined `sp_*` symbols. Add `-I<spinel>/lib` and `<spinel>/lib/libspinel_rt.a`. Prefer `--link` and let Spinel drive `cc`; it places archives between the generated TU and its runtime, which is the order that resolves.

### Redoing the wasm build

Compile the runtime with emcc and archive it (all 25 modules build unmodified), then point Spinel at it:

```sh
RT="sp_bigint sp_crypto sp_pack sp_time sp_core sp_net sp_system sp_gc sp_alloc sp_dtoa \
    sp_marshal sp_format sp_string sp_inspect sp_array sp_str sp_hash sp_proc sp_exc \
    sp_re sp_random sp_fiber sp_sched sp_io sp_cold"
for m in $RT; do emcc -c -O2 -Wno-all -Ilib -Ilib/regexp lib/$m.c -o build/wasm/$m.o; done
for f in lib/regexp/*.c; do emcc -c -O2 -Wno-all -Ilib -Ilib/regexp $f -o build/wasm/re_$(basename $f .c).o; done
emar rcs lib/libspinel_rt.a build/wasm/*.o     # keep a copy of the native one first
```

Then wrap `emcc` in a shim that rewrites `-Wl,-dead_strip` to `-Wl,--gc-sections` (Spinel picks that flag from the *host* OS) and pass it as `--cc=/path/to/emcc-shim`. `RT_MEMBERS` in Spinel's `Makefile` is the authoritative module list if it drifts.

### Redoing the benchmark

There is no bundled `mruby` binary — only `mrbc`. A ~12-line C driver calling `mrb_load_file`, linked against `assets/platform/macos-arm64/lib/libmruby.a` with `-Iassets/platform/include`, gives a runnable mruby for comparison. Run the same `.rb` under it, CRuby, and a Spinel-compiled binary, and check the checksums match before trusting the timings.

## Working artifacts

Everything from the research — the Spinel clone and build, the ~34 language probes, the Step 0 harness (concatenator, line-mapper, patch script), the SDL3 window test, the wasm build, and the benchmark — lives in a **session-scoped scratchpad and is disposable**. Nothing in this repo depends on it. The sections above are written so each result can be reproduced from a clean checkout; re-clone Spinel and rebuild rather than hunting for those files.

The one piece worth recreating early is the Step 0 harness, since the checklist leans on it: concatenate the `LIB_FILES` slice into one `.rb`, keep a line-map back to source files (offsets accumulate as `lines + 2` for the `"\n\n"` join), run `spinel -c`, and patch forward one error at a time.
