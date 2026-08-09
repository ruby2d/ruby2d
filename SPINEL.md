# Spinel build path

Research notes and working checklist for compiling Ruby 2D apps with [Spinel](https://github.com/matz/spinel), Matz's Ruby AOT compiler, as an opt-in alternative to the mruby default. Findings are from 2026-08-07 and 2026-08-08 against Spinel `8b029022e663` on macOS arm64; mruby stays the default for `ruby2d build`.

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

## Workarounds to re-check

Spinel moves fast, so every workaround here is provisional. Each row is pinned to the Spinel commit it was needed at; after a `git fetch` in the Spinel checkout, re-run the probe and delete the row if it passes. **Do not let these calcify into permanent Ruby 2D design.**

| Workaround | Needed at | Re-check by |
|---|---|---|
| `DSL.window.<m>(obj)` instead of `Window.<m>(obj)` at 4 internal call sites (issue 6) | `8b029022e663` | Revert the 4 rewrites in `renderable.rb`/`interactive.rb`, recompile the MVP subset |
| Top-level `def` shims instead of `include Ruby2D` + `extend Ruby2D::DSL` | `8b029022e663` | `include`/`extend` a module with instance methods at top level, call one |
| Expand `attr_*`/`alias` out of `module Renderable` (issues 1-3) | `8b029022e663` | `attr_reader` in a module, `include` it, call the reader |
| Spell out `ffi_func` type arrays instead of `[:double]*6` | `8b029022e663` | Declare an `ffi_func` with a computed type array |
| `emcc` shim rewriting `-Wl,-dead_strip` → `-Wl,--gc-sections` | `8b029022e663` | `spinel hello.rb --cc=emcc` against a wasm-built runtime |

Two of these are worth upstreaming rather than carrying: the `-dead_strip` host-vs-target flag bug, and issue 6 once reduced. The `attr_*`-in-module expansion is worth keeping regardless — it is a plain refactor that costs nothing under CRuby or mruby.

## Milestone: a square on screen (2026-08-08)

**A Spinel-compiled Ruby program opened a real window, ran a Ruby-owned main loop, moved a square, rendered 180 frames through Ruby 2D's own `R2D_*` core, and exited cleanly.** 4.9 MB binary.

What that establishes, all of it previously unproven:

- The C core compiles with **no Ruby engine at all** (`-DRUBY2D_NO_RUBY`) — `ruby2d.c`, `window.c`, `shapes.c`, `fps.c`, `font.c` into a 70-symbol `libruby2d_core.a`.
- It links into a Spinel binary alongside the bundled SDL3 statics and the macOS frameworks.
- Spinel's FFI drives the real `R2D_*` API: 12-argument calls, `:float` colour components, `:bool` returns, `:str` error strings.
- A Ruby-owned loop pumps SDL3 at 60fps without C ever calling back into Ruby.

**What it does not yet establish**, and the distinction matters: the test program is hand-written Ruby calling `ffi_func` declarations directly. It is *not* a `ruby2d` script — nothing in `lib/` is involved. The MVP as defined ("a plain Ruby 2D script that draws a moving square") still needs the `Ext` adapter that maps `lib/`'s calls onto these entry points, plus the CLI wiring. The runtime risk that motivated the narrowed MVP is now retired; what remains is integration.

### How the C was made Ruby-free

`window.c` is the awkward one: 37 `ruby2d_ext_*` wrappers interleaved with 20 `R2D_*` cores across 2,000 lines, with no region to guard wholesale. Each wrapper is individually wrapped in `#ifndef RUBY2D_NO_RUBY`. Ugly but mechanical and reversible; the cleaner end state is splitting bindings into their own file once all 37 wrappers are thin adapters (only 6 are so far).

`font.c` needed just one guard — it has a `// Ruby Bindings` section header with nothing Ruby-free after it. **`window.c` is the outlier here**: `text.c`, `image.c`, `canvas.c`, `audio.c`, and `ext.c` have no such header either, so they will need per-wrapper guards or a tidy-up when their turn comes.

In `ruby2d.h`, `R_VAL` / `R_CLASS` / `R_ID` become placeholder types under `RUBY2D_NO_RUBY` so the ~91 binding *declarations* still parse — a declaration costs nothing, and guarding them all would bury the header. The accessor macros (`r_ivar_get` and friends) are deliberately left **undefined**, so a Ruby call that creeps into an `R2D_*` core fails to build rather than silently doing nothing on the Spinel target.

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
