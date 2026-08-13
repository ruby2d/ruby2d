# Spinel build path

Research notes and working checklist for compiling Ruby 2D apps with [Spinel](https://github.com/matz/spinel), Matz's Ruby AOT compiler, as an opt-in alternative to the mruby default. Findings are from 2026-08-07 to 2026-08-10 on macOS arm64; mruby stays the default for `ruby2d build`. Spinel moves fast, so the commit matters: the initial research ran against `8b029022e663`, the MVP work against `f0f7dc0d7131`, and **everything was last re-verified against `83d1315d` (2026-08-12)** — `cd spinel && rake` green on all five checks.

## Start here

The rest of this document is a research log in discovery order. This section is the orientation; read it first.

### Status

**The feature is wired: `ruby2d build --spinel app.rb` compiles an ordinary Ruby 2D script to a standalone 5.2 MB binary.** No hand-run scripts, no paths to set — get the compiler with `ruby2d setup --spinel`, then build. The app goes through `lib/`'s own scene graph into the real `R2D_*` core, with Ruby owning the frame loop. See [The CLI](#the-cli-ruby2d-build---spinel-2026-08-10).

What's left is coverage, not plumbing: the target draws `Square`, `Rectangle`, `Quad` and `Circle`, and nothing else yet. All four draw **filled and stroked**, the quad family in a single color or per-vertex — see [Strokes drew nothing](#strokes-drew-nothing-2026-08-11), [Per-vertex colors](#per-vertex-colors-a-compiler-bug-and-one-of-ours-2026-08-11) and [`Circle` lands](#circle-lands-and-finds-a-bug-on-the-way-in-2026-08-12). An app using anything more stops before compiling with a message naming it — see [Preflight](#preflight).

**`spinel/square.rb` — USAGE.md's opening example, verbatim — builds and draws on a stock compiler.**

```sh
ruby2d build --spinel spinel/square.rb && ruby2d launch --native
```

It needed a patched Spinel for one day: any `set` call omitting `background:` passed a nil key to a String-keyed hash and segfaulted before the first frame. [#3790](https://github.com/matz/spinel/issues/3790) fixed that in `fcaf3fcc`. See [square.rb: the goal](#squarerb-the-goal-and-the-one-line-that-was-in-the-way-2026-08-11).

**`spinel/examples/` holds three scripts that run on all three engines unmodified** — `fountain.rb`, a sweeping emitter spraying bouncing, recycling balls; `balls.rb`, the fixed-workload benchmark scene; and `mandelbrot.rb`, 30,000 squares computed band by band and zooming itself. See [`fountain.rb`: a scene that moves](#fountainrb-a-scene-that-moves-2026-08-12) and [`mandelbrot.rb`, and what `Canvas` would take](#mandelbrotrb-and-what-canvas-would-take-2026-08-12).

**And it is fast: 3.5× mruby and 2.3× CRuby** on the same scene's Ruby work, via `rake fps`. Wall-clock fps cannot show this — every engine ties at the display's refresh rate — see [How fast is it, really](#how-fast-is-it-really-2026-08-12).

**Per-vertex colors work, and took two fixes to get there** — see [Per-vertex colors: a compiler bug and one of ours](#per-vertex-colors-a-compiler-bug-and-one-of-ours-2026-08-11). `rake compare` now builds a gradient fixture on both engines and gets byte-identical output.

`bouncing_balls.rb` separately drives the same core at 60fps from hand-written FFI, and is the reference for the FFI patterns.

**The `lib/` blocker is gone.** All seven of [#3771-#3777](https://github.com/matz/spinel/issues?q=%22porting+Ruby+2D%22+in%3Abody) are fixed upstream, including #3773, and `verify_issues.rb` confirms all seven independently. The square-only slice now compiles to zero C errors and runs end to end: it constructs a `Square`, registers it, dispatches through the scene graph, and prints `SUBSET OK`. Two workarounds were deleted as a result.

**Every filed bug is closed upstream** ([#3771-#3810](https://github.com/matz/spinel/issues?q=%22porting+Ruby+2D%22+in%3Abody)). At `84f5a236` `verify_issues.rb` reports 24 fixed, 3 reproduce, 1 parked, 1 to read by hand: the three reproducing are drafts 27, 28 and 29, **none of them filed**; the one to read by hand is draft 24, fixed except for a residue — see [24 of 28](#24-of-28-and-the-first-bug-that-fails-silently-2026-08-13).

**Two of them are fixed upstream and still worked around here.** A closed issue is not a dropped workaround: `rake sweep` is what answers that, and it keeps `dsl_shims` and `window_guards` even though both reproducers pass. Both residues are now reduced and filed as [#3803](https://github.com/matz/spinel/issues/3803) and [#3802](https://github.com/matz/spinel/issues/3802) — plus `issues/20-…`, which upstream fixed first — and each needed an ingredient the original reproducer had no reason to include: a block parameter, a name collision, and a reopened class body. See [Fixed upstream, still worked around](#fixed-upstream-still-worked-around-2026-08-11) and [A draft fixed by someone else's report](#a-draft-fixed-by-someone-elses-report-2026-08-12).

**What stands between here and zero workarounds is a finite, known list.** [`spinel-doctor`](#the-whole-library-at-once-spinel-doctor-2026-08-10) on the full 37-file library reported exactly one unsupported construct, the event filter's runtime-name `send`, until `lib/` removed it on 2026-08-12; the rest is FFI adapter work. On the compiler side, four workarounds cover compiler bugs. Three are now filed with a reduced reproducer — `dsl_shims` → [#3803](https://github.com/matz/spinel/issues/3803), and `window_guards` and `bypass_window_class_methods` → [#3802](https://github.com/matz/spinel/issues/3802), which covers both. Each needed a *second* reproducer written from the library's failure rather than from the original small case. The fourth, `expand_hash_delete`, is filed as [#3806](https://github.com/matz/spinel/issues/3806) — see [Every workaround now has a reproducer](#every-workaround-now-has-a-reproducer). **Every compiler-bug workaround on this branch now has a minimal reproducer**, which was not true this morning.

Two things remain gaps rather than bugs, both inherent to AOT: the class pattern needs `Module#ancestors` reflection, and `button.rb` needs `define_singleton_method`. Input events are no longer among them — the `send` that made them inherently incompatible is gone, and **no script using input events compiles today** for ordinary compiler-bug reasons instead. Three of the four are fixed as of 2026-08-13 and one construct remains; see [Input is one bug away](#input-is-one-bug-away-2026-08-13).

### Setup

Spinel is not vendored. For using the feature, one command gets it:

```sh
ruby2d setup --spinel     # clones and builds into the ruby2d cache; several minutes
```

For working **on** this branch, clone it **beside this repo** instead — the tools here look there, and a checkout you control is easier to `git bisect`:

```sh
git clone --depth 1 https://github.com/matz/spinel.git ../spinel
(cd ../spinel && make deps && make)     # builds bin/spinel; needs network for libprism
```

Nothing else to set: every tool here resolves the binary through `tools/spinel_path.sh` (shell) or `resolve_spinel` (Ruby), which look at `$SPINEL`, then `$RUBY2D_SPINEL`, then `../spinel/bin/spinel`, then `$PATH`. `find_spinel` in `cli/spinel.rb` is the same order minus the sibling checkout, with the `setup --spinel` build in its place. Keeping the recipes path-free is deliberate — this branch is shared, and a machine-specific path in a committed script is noise at best and a broken copy-paste at worst.

Any other location works, it just has to be named once:

```sh
export RUBY2D_SPINEL=/wherever/spinel/bin/spinel   # also what cli/spinel.rb honors
```

`make deps` fetches libprism and rbs from RubyGems. A rebuild after `git fetch` is just `make -j8`.

**Spinel is used from its checkout, never copied out of it.** It resolves `libspinel_rt.a` and its C sources relative to its own `bin/`, so a lone copied binary fails at link time. That is why `setup --spinel` builds into the cache's sources directory and leaves the compiler there.

### Check where things stand

```sh
cd spinel && rake     # all five checks; or `rake subset`, `rake cli`, …
```

```
  subset     pass     matches CRuby (4 lines)
  demo       pass     drew 2 distinct colors over 31 frames
  cli        pass     built an app that drew 3 colors over 31 frames
  preflight  pass     rejected unsupported features by name
  issues     pass     11 fixed, 5 reproduce
```

- **subset** compiles the `lib/` slice and diffs it against the same program run under CRuby. Any divergence is a compiler difference, because the control has to pass first.
- **demo** builds the square and checks the **pixels**, not the exit status.
- **cli** builds `tools/cli_app.rb` with `ruby2d build --spinel` and checks its pixels and its frame count. Both are load-bearing: a zero frame count would mean #3783 is back, and the fixture's shape is stroked so the color count is exactly three — two means a stroke went inert again.
- **preflight** builds an app using `Circle` and `on` and checks the build refuses it *by name*.
- **issues** re-runs every filed reproducer. A `FIXED` row is the cue to drop the matching workaround with `SPINEL_SKIP=` and rebuild.

Four more sit outside the default set, because they answer roadmap questions rather than regression ones and each takes minutes:

```sh
cd spinel && rake sweep      # drop each workaround in turn; the one to run after a pull
cd spinel && rake survey     # what blocks a clean build of all 37 files
cd spinel && rake compare    # build all three fixtures on both engines and diff the pixels
cd spinel && rake fps[name]  # one examples/ scene on CRuby, mruby and Spinel, Ruby-side cost
cd spinel && rake upstream   # pull, rebuild, then re-run issues and sweep
```

**`rake compare` is the one that answers "does it draw the same thing mruby does".** Every other check grades the Spinel target against itself, and a whole feature can be missing without any of them noticing — which is exactly how strokes stayed inert.

**`cli` and `preflight` go through the installed gem**, not the working tree — so run `rake` in the repo root first or they test your last install. Everything else reads `lib/` directly.

`spinel/tools/check.rb` is what these run, and it encodes the things that wasted the most time when they were manual:

- **Delete the binary before compiling.** A failed compile leaves the previous one in place, so the old result reads as a fresh success. This produced a wrong conclusion once already.
- **Always `-ferror-limit=0`.** clang stops at 20, so 23 errors reads as 20 and real progress looks like a plateau.
- **Always run the CRuby control.** A Spinel result is only attributable against it.
- **Cap every run.** Two open bugs are infinite loops (`tools/run_capped.sh` for one-offs; macOS has no `timeout(1)`).
- **Check pixels, not exit codes.** A window that draws nothing exits cleanly, reports a healthy per-frame draw count, and looks identical to a correct one from every angle except its pixels. Verified by reintroducing the Integer-to-`:float` bug: the check reports `rendered a blank window (1 distinct color)`.

### Resuming

```sh
(cd spinel && rake issues)
gh issue list --repo matz/spinel --state all --search '"porting Ruby 2D" in:body'
```

A `FIXED` row is the cue to re-check the matching workaround with `SPINEL_SKIP=` and rebuild the subset — not to run a standalone probe. Those diverge in both directions: a nested-`include` bug was fixed in isolation while the real library still failed, and #3772's own reproducer passes today while the library shape it was filed for still breaks.

Spinel ships many commits a day, so pull before trusting any measurement here.

### Where to read next

| If you want | Read |
|---|---|
| Why this is viable at all | [Why Spinel fits](#why-spinel-fits) |
| What breaks and how it is worked around | [Workarounds to re-check](#workarounds-to-re-check), then `lib/ruby2d/cli/spinel.rb` |
| Why "it runs and draws" is not enough | [Strokes drew nothing](#strokes-drew-nothing-2026-08-11) |
| What is filed upstream | [To report upstream](#to-report-upstream) and `issues/` |
| How the CLI is wired | [The CLI](#the-cli-ruby2d-build---spinel-2026-08-10) |
| How to rebuild the demo | [Building the demo](#building-the-demo) |
| How to chase a new whole-program bug | [Reducing a whole-program failure](#reducing-a-whole-program-failure) |
| What the MVP is and what is left | [MVP](#mvp) |

Sections below are dated where it matters. Anything describing a "current" state is current **as of its date**, not necessarily now — the Status section above is the only place kept up to date.

## What's in this directory

Everything worth keeping from the Spinel spike. Nothing here is a final home — it is a holding area for this branch.

| File | What it is |
|---|---|
| `Rakefile` | The checks, kept here rather than in the root Rakefile so this branch merges or disappears as one piece |
| `README.md` | This document: findings, checklist, workarounds, and what to report upstream |
| `bouncing_balls.rb` | A port of `examples/bouncing_balls.rb` to the FFI path — the demo that runs today |
| `square.rb` | USAGE.md's opening example, verbatim — the target this branch is aimed at, built with `ruby2d build --spinel` |
| `issues/` | The upstream bug reports, one file per issue |
| `tools/` | `check.rb` runs the checks behind `rake`; `spinel_path.sh`/`spinel_env.rb` resolve the compiler so no recipe hardcodes a path; `build_square.rb` + `link_square.sh` build the square demo; `build_subset.rb` assembles the slice with `Ext` stubbed (`SPINEL_SKIP=` drops workarounds); `cli_app.rb` is the fixture the `cli` check builds; `gradient_app.rb` is the per-vertex-color one; `compare.rb` diffs both fixtures' pixels between mruby and Spinel; `sweep.rb` drops each workaround in turn; `survey.rb` reports what blocks a clean build; `upstream.rb` pulls and rebuilds the compiler; `verify_issues.rb` re-runs every filed reproducer; `run_capped.sh` runs a binary under a time cap; `reduce_oracle.sh` and `reduce_oracle_diff.sh` are the two-sided oracles for `spinel-reduce` — the first for crashes, the second for silent wrong answers |
| `scratch/` | Working area for experiments — gitignored, safe to delete |

Experiments go in `scratch/`, which is gitignored: generated sources, object files, built binaries, probe scripts. It survives across sessions, unlike a system temp directory, but nothing there is precious — delete it freely. Anything worth keeping is promoted up a level and committed.

**The Spinel compiler itself stays outside the repo.** It is a large separate git repository that gets rebuilt on every upstream pull, so nesting it here would be awkward and would confuse tooling. Clone it beside this repo as `../spinel`, or point `RUBY2D_SPINEL` at `bin/spinel` — the same resolution order `find_spinel` implements. The recipes below need no path set.

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

### Events are unsupported — the `send` is gone, three compiler bugs remain (2026-08-12)

**The runtime-name `send` was removed from `lib/` on 2026-08-12.** It was the only blocker on this path that no upstream fix could have cleared: `e.send(:"#{k}?", v)` and `e.send(predicate, v)` name a method at run time, which whole-program AOT cannot resolve by construction. Both window-level and per-object filters now go through a per-event `matches?(field, value)`:

```ruby
# each event answers for its own fields
def matches?(field, value)
  case field
  when :gamepad then gamepad?(value)
  when :button  then button?(value)
  else false
  end
end
```

`EVENT_FILTER_PREDICATES` became `EVENT_FILTER_FIELDS` (and the same for the per-object map): the map keeps its indirection, but names a *field* rather than a method, so the dispatch is an ordinary call every event class owns. The public API is unchanged and all 867 specs pass. `rake survey` no longer lists a `send` among the AOT limits — only `define_singleton_method` and `undef_method` remain there.

**Input handling still does not work**, because three ordinary compiler bugs sit behind the one that was ours. (All but the last of these were fixed upstream on 2026-08-13 — see [Input is one bug away](#input-is-one-bug-away-2026-08-13).)

| Bug | Filed | Effect on `on` |
|---|---|---|
| A keywords-only call binds the keyword hash to an optional positional too | [#3808](https://github.com/matz/spinel/issues/3808) | `on(key_down: :escape)` raises "requires either an event symbol or event filters" — `def on(event = nil, **filters, &proc)` is the shape |
| `equal?` between a typed receiver and a poly argument folds to `false` | [#3807](https://github.com/matz/spinel/issues/3807) | gamepad identity filters never match, silently |
| An escaping lambda's parameter inferred as `Integer` | not reduced | `e.matches?` raises `NoMethodError` at the handler |
| A lambda capturing the enclosing block parameter (`Interactive#on`) | not filed | per-object `on` refuses to compile at all |

The refactor was verified rather than assumed: with only the last of those neutralized, `Window#on` compiles and runs, so it is these bugs and not the design that stop it. The preflight therefore still rejects `on`, with its reason updated — the feature is genuinely unavailable, and a silent half-working event system would be worse than a clear refusal.

**Related, and a clean negative result:** the library's three other `equal?` sites are *not* affected by #3807 — `sprite.rb`'s frozen-sentinel default, and the poly-vs-poly comparisons in `quad.rb` and `triangle.rb`. The fold needs a user-class-typed receiver against a poly argument specifically; both operands poly, or a sentinel default, compile and answer correctly. Checked because a silent identity failure in shipped code would be worse than the bug that prompted the look.

## #3783 is closed and still broken for us — root cause and patch (2026-08-10)

All ten filed bugs closed. Sweeping the workaround table found nine of the ten genuinely fixed in the real library, and one not. Chasing that one produced a root cause, a twenty-line reproducer, and a patch that passes Spinel's own suite — drafted as `issues/11-…`.

**The cause.** Escape analysis decides whether a forwarded block's captures need heap cells by resolving which method the block is forwarded into. When it cannot resolve the receiver it falls back to matching by name and takes the **first** scope it finds — and because that pass runs before receiver types settle, a plain local receiver reaches the fallback too, so the bug is not confined to call receivers (`src/analyze.c`, from [`0780e65a`](https://github.com/matz/spinel/commit/0780e65a)). Ruby 2D has four methods named `update` that take a block — `ClassMethods#update`, `Window#update`, `DSL#update`, and the generated top-level shim, in assembled order — and only `Window#update` stores it. `window/class_methods.rb` comes first and forwards, so the forward is judged harmless and the block is inlined with its captures uncelled.

**What made it findable** was reading Matz's own fix commits rather than guessing at shapes. Twenty-one hand-built probes all passed; the commit message for `0780e65a` named the mechanism in one sentence, and the code showed the `break`. The prediction that followed — that the bug depends on *definition order* — reproduced immediately:

```
storer defined first       ok    n=3
forwarder defined first    FAIL  n=0
```

**The fix** treats an ambiguous forward as an escape instead of betting on one candidate, which costs no more than the single-match case already accepts. Verified three ways: the reproducer, Ruby 2D's callbacks with `positional_callbacks` removed, and `make test` in the Spinel checkout, which reports no failures and no errors.

**Filed as [#3786](https://github.com/matz/spinel/issues/3786) and fixed upstream in `1c168009` on 2026-08-11**, and `positional_callbacks` was deleted the same day — the branch's longest-lived workaround, and the only one whose bug it root-caused and patched itself.

### How the evidence was gathered

Removing `positional_callbacks` left the subset compiling, running, and still printing `SUBSET OK` — with one earlier line wrong:

```
CRuby                            Spinel
block ran; it reads ticks as 1   block ran; it reads ticks as 1
block ran; it reads ticks as 2   block ran; it reads ticks as 1
block ran; it reads ticks as 3   block ran; it reads ticks as 1
...                              ...
ticks: 5                         ticks: 0
```

The block **runs** every frame. Each call gets a fresh copy of the captured local, increments it to 1, and the write never reaches the enclosing scope. That is the same signature #3783 was filed with, and #3772 before it.

Two experiments narrowed it before the source did, and both are worth reusing:

**Embed a passing probe in the failing program.** Probe A, appended verbatim to the failing 4,000-line subset, still returned the correct answer while the library's own callback failed in the same binary. That ruled out scale, call-graph size, and interference in one run, and proved a minimal reproducer had to exist.

**Vary only the call site.** Registering the callback four ways showed the generated shim was necessary: `update { }` through the shim failed, while `DSL.window.update { }`, a local receiver, and a pre-built `proc` passed with `&` all worked.

**Twenty-one probes all passed**, which is the useful negative space: repeated invocation, an ivar initialized to `nil`, the arity read before storing, two callbacks on one object, an arity-dependent `call` vs `call(dt)`, a receiver from a module accessor, a bare same-named call that never executes, two forwarding shims side by side, and the shared-name and dead-call-site factors both separately and together. `scratch/probe_*.rb` holds them.

Also worth knowing: `spinel-doctor --only inference` reports methods "widened to untyped (slow path)", and widening is **not** the cause — it appears in the passing cases too. That hypothesis cost an hour; the commit log answered in five minutes.

**Two lessons to carry.** `verify_issues.rb` reporting `FIXED` means the reproducer passes, nothing more — the workaround sweep is the real test, and it disagreed here. And when a bug resists guessing, read the fix history for the ones it follows: `git log --grep` in the Spinel checkout found the mechanism, the file, and the line.

`tools/reduce_oracle_diff.sh` was written for this and remains the right oracle for the silent class — a candidate counts only when CRuby and Spinel both run cleanly and disagree. It was not what cracked this one.

## What blocks a clean build of the whole library (2026-08-10)

```sh
cd spinel && rake survey
```

`tools/survey.rb` assembles all 37 `LIB_FILES` with the compatibility layer off and reports the complete gap. **Doctor alone cannot answer this**: Spinel stops at the first construct it refuses and never reaches the next, so a plain build names one blocker however many there are — which is exactly why they surfaced one per session. The survey edits out each known blocker so the one behind it becomes visible, and its `NEUTRALIZE` table is the catalogue. Add to it when a new blocker appears; delete an entry when the issue is fixed, and a missing site raises rather than passing quietly.

The gap falls into three kinds, and the middle one had been under-counted:

**Inherent AOT limits — a change in `lib/`, never an upstream fix.**

| | Why it cannot be fixed upstream |
|---|---|
| `send` with a runtime method name, 3 sites | AOT needs a compile-time-known name. Every value in the predicate maps is `:button?` today, so a compile-time table would replace it |
| `Object#define_singleton_method` (`button.rb`) | no per-object method table exists when every call site is a direct C call |
| `Module#undef_method` (`image`, `canvas`, `tileset`) | methods resolve statically, so there is nothing to undefine from |
| the class pattern's `ancestors` reflection | already handled by `disable_class_pattern` |

**Compiler bugs.** Six are worked around in `cli/spinel.rb` (four drafted as issues 11-14, two unreduced), and the survey found two more that no workaround covers: a lambda capturing the enclosing block parameter in `interactive.rb`, and `Hash#delete_if` on an ivar in `object_events.rb`. Neither is filed.

**What is left once all of that is edited out** — clang reports these together, so the list is complete:

```
  1  initializing 'sp_RbVal' with incompatible type 'const char *' → expand_hash_delete
  1  returning 'sp_RbVal' from a function returning 'sp_PolyArray *'  → unfiled
```

Both are the same shape: a boxed `sp_RbVal` assigned to an unboxed slot, with no conversion emitted. There were 20 on 2026-08-10; `ef8535c4` removed the 18 multiple-assignment ones.

Two cautions the survey itself taught. Neutralize an *expression*, not a line — blanking whole lines left `if/elsif/else` unbalanced and produced four parse errors that read as findings. And keep the surrounding variables used: replacing a call with a bare `true` left a block parameter unused, which changes the capture analysis and invented a blocker that vanished when both variables were kept.

## The whole library at once: `spinel-doctor` (2026-08-10)

Bugs were being found one at a time because a build stops at its first error, so widening the slice produced a queue. `spinel-doctor` — in the Spinel checkout's `bin/`, built alongside the compiler — analyses without stopping, and answers "what would we face if we widened all the way" in one run.

Assemble the **full** `LIB_FILES` (`scratch/survey_full.rb` does this by swapping `SPINEL_LIB_FILES` for `Ruby2D::CLI::LIB_FILES`; the result need not run, only be analyzed) and point doctor at it:

```sh
export SPINEL=../spinel/bin/spinel
ruby spinel/scratch/survey_full.rb
../spinel/bin/spinel-doctor --skip behavior spinel/scratch/full.rb
```

At `20a06d01`, across all 37 files and 9,226 assembled lines:

```
[ERR]  unsupported (1)
  [ok]   unresolved
[info] inference (850)
  [ok]   requires
[ERR]  build (1)
```

**One unsupported construct in the entire library**, and both errors are the same line — the event-filter hash form in `window.rb`:

```ruby
if matcher.all? { |k, v| e.send(:"#{k}?", v) }
```
> `unsupported send with a runtime method name (AOT needs a compile-time-known name)`

Everything else — image, text, canvas, audio, sprite, tileset, polygon — parses, resolves, and would compile. What stands between the slice and the whole library is that one line plus FFI adapter work, which is mechanical and countable.

> **Since 2026-08-12** that line is gone: `lib/` replaced the `send` with a per-event `matches?(field, value)`. Input handling is still unavailable, now for four ordinary compiler-bug reasons rather than an inherent AOT limit — see [Events are unsupported](#events-are-unsupported--the-send-is-gone-three-compiler-bugs-remain-2026-08-12).

The legs are worth knowing individually:

| Leg | Answers |
|---|---|
| `unsupported` | constructs Spinel refuses outright — the real blockers |
| `unresolved` | calls it cannot resolve, each marked whether CRuby agrees |
| `inference` | every method widened to untyped. **Informational** — widening is not a bug signal, and treating it as one cost an hour on #3783 |
| `requires` | files it could not load |
| `build` | does the C compile |
| `behavior` | runs it and diffs against CRuby. Opt in with `--only behavior`; reports *that* output differs, not where |

`behavior` is a ready-made differential tester. Pointed at a corpus rather than one program — every `USAGE.md` snippet, say, which the project already guarantees runs as written — it would find runtime divergences in bulk, the way the static legs find compile ones.

## To report upstream

Every workaround in this document exists because of one of these. Spinel's contributing notes ask for "a 5-line Ruby that fails in Spinel but passes in CRuby", so each draft carries a reproducer in that shape, plus the CRuby and Spinel output it produces.

Re-verify the whole set against a freshly built compiler before trusting any of it:

```sh
ruby spinel/tools/verify_issues.rb
```

Each draft is self-describing enough for the tool to check it: the code under "## Reproduction", the correct output under "**Ruby 4.0.6:**", the buggy output under "**Spinel (…):**". A row reading `FIXED` means the issue can be closed and its workaround re-checked; `CHANGED` means read it by hand before believing anything.

A draft the verifier cannot judge says so in its own text, with a `**Status:**` line naming why, and reports under that word instead of running. One exists today: `Spinel-only`, for a reproducer using a compiler-only DSL, where CRuby is not an oracle and the two-sided comparison is meaningless. It is not counted as something to read by hand — a permanent warning is one nobody reads — so it needs a human on a re-verification pass, which is what the table below is for. `research notes` is the other opt-out, for a draft that is root-caused but has no reproducer yet; draft 17 used it until 2026-08-12 and none does now.

**Filed on 2026-08-12**, nine in one day. The first five were reduced from a workaround this branch could not otherwise drop; the last two came out of removing the event-filter `send` from `lib/`. The last two came out of measuring what `examples/bouncing_balls.rb` needs. The first three were verified against `01bc08c8`, the rest against `83d1315d`:

| Issue | Draft | Bug | Workaround it covers |
|---|---|---|---|
| [#3802](https://github.com/matz/spinel/issues/3802) | `issues/21-…` | `extend` written in a *reopened* class body detaches the module's methods from the class, both for an implicit-receiver call inside it and for `Win.method` from outside — not about `alias_method` at all | `window_guards` **and** `bypass_window_class_methods`, which had resisted ten reduction attempts |
| [#3803](https://github.com/matz/spinel/issues/3803) | `issues/19-…` | A method declaring `&block`, reached through a top-level `extend`, is called with the block argument dropped | `dsl_shims`, all of it now that 20 is fixed |
| [#3804](https://github.com/matz/spinel/issues/3804) | `issues/18-…` | `ffi_func` given a computed type array — `[:float] * 6`, or a constant — silently drops the declaration, and the error lands on the first call instead, naming neither `ffi_func` nor the declaration's line | the adapter's spelled-out type arrays |
| [#3805](https://github.com/matz/spinel/issues/3805) | `issues/17-…` | A user class defining `length` diverts `empty?` on a poly receiver away from the builtin lowering into a dispatch keyed on `empty?`, which nothing owns, so the call becomes an unconditional raise — see [Per-vertex colors](#per-vertex-colors-a-compiler-bug-and-one-of-ours-2026-08-11) | `Color::Set#empty?` in `lib/`, which is a real method rather than a workaround |
| [#3806](https://github.com/matz/spinel/issues/3806) | `issues/22-…` | `delete` on a poly receiver is lowered to `String#delete`, stringifying the receiver — silently wrong with a String argument, a C compile error otherwise | `expand_hash_delete`, the last workaround to get a reproducer |
| [#3807](https://github.com/matz/spinel/issues/3807) | `issues/23-…` | `equal?` between a typed receiver and a poly argument is folded to the constant `false`, both operands discarded | none — found while removing the event-filter `send` |
| [#3808](https://github.com/matz/spinel/issues/3808) | `issues/24-…` | A keywords-only call binds the keyword hash to an optional positional parameter as well as to `**kwargs` | none — same |
| [#3809](https://github.com/matz/spinel/issues/3809) | `issues/25-…` | `obj.attr += value` is refused when the writer is a hand-written `def` rather than an `attr_writer`; longhand works | none — blocks `s.x += b.vx * dt`, the shape any physics loop has |
| [#3810](https://github.com/matz/spinel/issues/3810) | `issues/26-…` | A String-keyed Hash looked up with a poly key reads `.v.s` with no tag check and **segfaults** — the residue of #3790's `nil` key | none — crashes any app using a numeric `[r, g, b, a]` color |

The duplicate search before filing turned up one close relative worth citing rather than a duplicate: [#2856](https://github.com/matz/spinel/issues/2856), a class method added by *reopening* a class not being registered. Its reproduction passes at `83d1315d`, so a `def` in a reopened body registers while an `extend` does not — that contrast is in #3802 because it bounds the search.

**Not filed** — six, for different reasons:

| Draft | Bug | Status |
|---|---|---|
| `issues/20-…` | A top-level `extend` shadows a class's own same-named method, **silently** — `Window#update` never runs | **Fixed upstream 2026-08-12 before it could be filed**, by `80a3beb2`. Do not file; kept as the record, and kept in `verify_issues.rb` because upstream has no test for this shape |
| `issues/27-…` | An override of an inherited `attr_reader` is dispatched to correctly but typed as the attr, so a differing return type **segfaults** or fails to compile — the residue of [#1702](https://github.com/matz/spinel/issues/1702) | **Drafted 2026-08-12, awaiting review.** Found adding `Circle`; verified reproducing at `84f5a236` |
| `issues/28-…` | A stored block capturing an array of objects is refused — `unsupported closure capturing a non-integer variable`, with no source location | **Drafted 2026-08-12, awaiting review.** Found porting `mandelbrot.rb`; verified reproducing at `84f5a236` |
| `issues/29-…` | An attribute write on a run-time-typed receiver is **silently dropped** when the writer is a `def` and any class declares the name as an attr | **Drafted 2026-08-13, awaiting review.** Found re-testing the workarounds after the upstream sync; verified reproducing at `84f5a236` |
| the `Interactive#on` lambda | A proc referencing the enclosing method's block parameter is refused — the last thing between here and input events | **Not reduced.** The site is named in [Input is one bug away](#input-is-one-bug-away-2026-08-13); every standalone form of it compiles, so there is nothing filable yet |
| `issues/30-…` | **Design, not a bug.** Method resolution is re-derived at each emission site, and the boxed write path never consults the method table — the mechanism behind #3805, #3806 and drafts 27 and 29 | **Drafted 2026-08-13, awaiting review.** Written after reading `src/codegen_stmt.c` and `src/codegen_call.c`; parked in `verify_issues.rb` as research notes, since a design issue has no single reproducer |

**Twenty-five of the thirty drafts are filed** — every one except 20, which upstream fixed first, and 27, 28, 29 and 30, which are waiting on review. At `84f5a236` `verify_issues.rb` reports 24 fixed, 3 reproduce, 1 parked, 1 to read by hand: the three reproducing are drafts 27, 28 and 29; the one parked is draft 18, filed as #3804 but not machine-checkable; the one to read by hand is draft 24, whose double binding is fixed with a residue. The earlier five were filed on 2026-08-11 against `489cbde7` and fixed the same day, each closed by a commit citing its number:

| Issue | Draft | Bug | Fixed by | Workaround |
|---|---|---|---|---|
| [#3786](https://github.com/matz/spinel/issues/3786) | `issues/11-…` | A forwarded block's callee resolves to the first same-named method — the #3783 follow-up, root-caused and patched here | `1c168009` | `positional_callbacks` **dropped** |
| [#3787](https://github.com/matz/spinel/issues/3787) | `issues/12-…` | Top-level `extend` of a module does not make its methods callable (top-level `include` works — the sibling of #3775) | `e40fe331` | `dsl_shims` still needed |
| [#3788](https://github.com/matz/spinel/issues/3788) | `issues/13-…` | An implicit-receiver call to an `alias_method` singleton is unsupported from an extended module (the explicit-receiver form works, so #3776's fix holds) | `329050a6` | `window_guards` still needed |
| [#3789](https://github.com/matz/spinel/issues/3789) | `issues/15-…` | Reading an ivar from an `extend`-provided method emits invalid C — found while probing 13 | `bebef965` | none — the library's extended class methods hold no state |
| [#3790](https://github.com/matz/spinel/issues/3790) | `issues/16-…` | A nil key looked up in a String-keyed `Hash` segfaults — `sp_str_hash` reads the tag byte at `s[-1]` with no NULL check | `fcaf3fcc` | none — it blocked `square.rb`, which now builds unpatched |

The upstream fix for #3790 is our patch with a better constant: the guard returns the FNV offset basis rather than 0, so a nil key lands where the empty-string hash would rather than in bucket 0. **Two of the five cleared their reproducer without clearing the library**, which is the #3783 pattern for the third and fourth time — see [Fixed upstream, still worked around](#fixed-upstream-still-worked-around-2026-08-11).

The drafts keep the commit they were filed against, since that is what the filed copies say.

A crashing reproducer needs the same treatment a hanging one gets: the shell prints `segmentation fault` but the binary never wrote it, so `verify_issues.rb` reads the exit status for a fatal signal rather than comparing output. SIGKILL is excluded, since that is its own timeout killer.

### Every workaround now has a reproducer

**Read the failing line before writing a probe.** The first pass at these wrote one plausible minimal shape each, all passed, and the conclusion drawn — "these can't be reduced" — was wrong. Opening the assembled subset at the line the compiler names, and asking what the probe had dropped, reproduced `expand_massign` on the next try — drafted as issue 14, then fixed upstream before it could be filed. It also reduced `bypass_window_class_methods` on 2026-08-11, after ten failed attempts, once the question became "what does the *library* do that the probe doesn't" — the answer being an `extend` in a reopened class body, filed as [#3802](https://github.com/matz/spinel/issues/3802). The failing line is free information; guessing at shapes is not.

`expand_hash_delete` was the last holdout and fell on 2026-08-12, to the emitted C rather than to another probe. The one line worth reading was

```c
lv_pad = sp_str_delete(sp_poly_to_s(self->iv_gamepads_by_id), lv_id);
```

which says the whole thing: the ivar is poly, and the compiler coerced it to a String to call `String#delete`. Three lines reproduce it with no ivar and no class, filed as [#3806](https://github.com/matz/spinel/issues/3806). **Two earlier mirrors had held the ivar typed** — the shape they were built to test — and a typed receiver is exactly the case that works.

That is the same lesson as `issues/17-…` on the same day: both were reduced by reading the generated C for the *actual* lowering rather than by guessing which Ruby shape might trigger it. Two of this branch's four hardest reductions came from one `-c` and a `grep`.

`tools/reduce_oracle_build.sh` remains the oracle for compile failures of this kind. Pin `EXPECT` to the exact diagnostic so the reducer cannot wander onto a different error.

Found while probing, and **not** tied to any workaround: reading an ivar from an extended module's method emits invalid C (`((sp_Class){1})->iv_shown`, *"member reference type 'sp_Class' is not a pointer"*). Real, reproducible, and useful to upstream, but it blocks nothing here.

**Filed and closed the same day.** #3782-#3784 were filed on 2026-08-10 against `c70ed332`, re-verified against that commit first — including each draft's "Additional Findings" contrasts, which `verify_issues.rb` does not cover because it only runs the main reproducer. All three closed within hours. #3783's fix does **not** cover the shape Ruby 2D uses; see [root cause and patch](#3783-is-closed-and-still-broken-for-us--root-cause-and-patch-2026-08-10).

| Issue | Draft | Bug |
|---|---|---|
| [#3782](https://github.com/matz/spinel/issues/3782) | `issues/08-next-in-hash-each-hangs.md` | `next` inside `Hash#each` never advances the iterator — **hangs**, and a regression (first bad `ffb0587c`) |
| [#3783](https://github.com/matz/spinel/issues/3783) | `issues/09-forwarded-block-stored-in-ivar.md` | A forwarded block stored in an ivar loses its captured locals — **silent**, and an incomplete fix of #3772 |
| [#3784](https://github.com/matz/spinel/issues/3784) | `issues/10-yield-result-type-unified-across-call-sites.md` | A block's result type is unified across `yield` call sites, dispatching to the wrong class — **silent** |

**Filed and fixed.** #3771-#3777 were filed on 2026-08-10 against `1c3d99897ef3` and all seven were closed the same day; `verify_issues.rb` confirms each independently against `c70ed332`. The drafts stay here as the local record:

| Issue | Draft | Bug |
|---|---|---|
| [#3771](https://github.com/matz/spinel/issues/3771) | `issues/01-safe-navigation-nan.md` | Safe navigation on the right of `\|\|` returns `NaN` instead of `nil` — **silent** |
| [#3772](https://github.com/matz/spinel/issues/3772) | `issues/02-forwarded-stored-block-loses-capture.md` | A block forwarded with `&b` and then stored loses its captured locals — **silent** |
| [#3773](https://github.com/matz/spinel/issues/3773) | `issues/03-self-escaping-superclass-method.md` | `self` escaping a superclass method is typed as the superclass — the bug that blocked the MVP |
| [#3774](https://github.com/matz/spinel/issues/3774) | `issues/04-module-body-declarations.md` | `attr_accessor` / `alias_method` in a module body do not reach the including class |
| [#3775](https://github.com/matz/spinel/issues/3775) | `issues/05-toplevel-include-arity.md` | Top-level `include` emits a call with the wrong arity, failing the C compile |
| [#3776](https://github.com/matz/spinel/issues/3776) | `issues/06-alias-method-in-singleton-class.md` | `alias_method` inside `class << self` produces no callable class method |
| [#3777](https://github.com/matz/spinel/issues/3777) | `issues/07-return-in-expression-position.md` | `return` in expression position rejected (`x = expr or return`) |

Filed in this order — suggested priority, not discovery (the filenames keep their original numbers). The ranking weighs three things:

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

Spinel moves fast, so every workaround here is provisional. **Last re-checked against `83d1315d` on 2026-08-12**, which dropped nothing — it fixed one of the two bugs behind `dsl_shims`, and the other still holds the row. The `b51c880d` pass before it dropped nothing either, the `9678c99b` one dropped `positional_callbacks`, the `489cbde7` one before that dropped `expand_massign`, and the one before that dropped three rows, which is the whole point of keeping this table. After a `git fetch` in the Spinel checkout, re-check and delete any row that passes. **Do not let these calcify into permanent Ruby 2D design.**

One caution learned the hard way, and confirmed again in this pass: a probe passing in isolation does **not** mean the workaround can be dropped. `dsl_shims` and `window_guards` both guard bugs that are fixed upstream and whose filed reproducers pass, and both are still needed. Re-check by removing the transform and rebuilding, never by running the probe alone.

Drop one by name and rebuild:

```sh
SPINEL_SKIP=expand_hash_delete ruby spinel/tools/build_subset.rb
SPINEL_SKIP=all ruby spinel/tools/build_subset.rb        # what is still needed at all
```

Names are the `spinel_*` functions in `cli/spinel.rb` minus the prefix. Compile the result and run it — a transform that is no longer needed compiles to zero errors *and* still matches CRuby line for line. Both halves matter twice over: dropping `disable_class_pattern` compiles clean and then fails at run time, and `positional_callbacks`, while it was still needed, compiled clean, ran, and still printed `SUBSET OK` — with one earlier line wrong.

`scratch/recheck_workarounds.rb` automates the sweep: it drops each transform in turn, rebuilds, compiles, runs, and diffs against CRuby. Recreate it from this description if it has been cleaned away; it takes a few minutes and answers the whole table at once.

**Still needed, re-checked against `83d1315d` (2026-08-12):**

| Workaround | Why it is still there |
|---|---|
| `bypass_window_class_methods` | `Window.viewport_width` — a class method reached through `extend ClassMethods` — is an unsupported call on a constant receiver. Root cause found 2026-08-11: the `extend` is written in a different `class Window` body from the module, same as `window_guards`. Filed as [#3802](https://github.com/matz/spinel/issues/3802) |
| `dsl_shims` | `extend Ruby2D::DSL` at top level: a method declaring `&block` is called with the block dropped. [#3787](https://github.com/matz/spinel/issues/3787) is closed and its reproducer passes; the residue is filed as [#3803](https://github.com/matz/spinel/issues/3803). The shadowing bug that shared this row was fixed on 2026-08-12 by `80a3beb2` and the row stayed, which is the point of sweeping rather than trusting a fix |
| `window_guards` | `shown?` with an implicit receiver does not resolve, because `extend ClassMethods` is written in a different `class Window` body from the module. [#3788](https://github.com/matz/spinel/issues/3788) is closed and its reproducer passes; the residue is filed as [#3802](https://github.com/matz/spinel/issues/3802) |
| `expand_hash_delete` | `@gamepads_by_id.delete(id)` is lowered to `String#delete` with the receiver stringified by `sp_poly_to_s`, passing `sp_RbVal` where a `const char *` is wanted. The receiver has to be genuinely poly — a typed one compiles and runs correctly, which is why two earlier mirrors passed. Filed as [#3806](https://github.com/matz/spinel/issues/3806) |
| `web_predicate` | `Ruby2D.web?` is registered from C, so it is absent under `RUBY2D_NO_RUBY` — not a compiler issue |
| `disable_class_pattern` | An AOT gap, not a bug — see [Deliberate feature gaps](#deliberate-feature-gaps-on-the-spinel-target) |
| `ffi_func` type arrays spelled out instead of `[:double]*6` | The computed form is dropped with no diagnostic — filed as [#3804](https://github.com/matz/spinel/issues/3804) |
| `emcc` shim rewriting `-Wl,-dead_strip` → `-Wl,--gc-sections` | `spinel hello.rb --cc=emcc` against a wasm-built runtime |

**Dropped on 2026-08-11**, once [#3786](https://github.com/matz/spinel/issues/3786) landed as `1c168009`: `positional_callbacks`. It was the longest-lived workaround on this branch and the only one whose bug we root-caused and patched ourselves.

**Dropped on 2026-08-10**, once #3771-#3777 landed: `expand_renderable` (`attr_*`/`alias` in a module body now reach the including class) and `expand_or_return` (`return` in expression position is accepted).

**Dropped 2026-08-11**, at `fa666718`: `expand_massign`, once [`ef8535c4`](https://github.com/matz/spinel/commit/ef8535c4) *"Unbox a poly multiple assignment into a scalar target"* landed. Found upstream independently — issue 14 was drafted but never filed. It had been 18 of the library's 20 remaining C errors.

**Dropped 2026-08-10**, once #3782-#3784 landed and the whole table was swept:

| Dropped | Was working around | Verified by |
|---|---|---|
| `expand_window_singleton` | `alias_method` in `class << self` producing no callable class method ([#3776](https://github.com/matz/spinel/issues/3776)) | subset compiles clean and matches CRuby |
| `hash_each_next` | `next` inside `Hash#each` hanging ([#3782](https://github.com/matz/spinel/issues/3782)) | subset, demo, and CLI all pass without it |
| `disable_object_interactivity` | A nested `include` not carrying `Interactive`'s methods across ([#3774](https://github.com/matz/spinel/issues/3774)) | the real library now registers per-object interactivity without error |

The last one is the notable one: the README carried it for weeks as the standing example of "fixed in a probe, still broken in the library". It is now genuinely fixed in the library — which is why the table is swept by removing transforms rather than by re-running probes. Note that dropping it does not make per-object `on` usable; preflight still rejects `on` outright, for the runtime-`send` reason below.

All functions are deleted, not disabled.

The `-dead_strip` host-vs-target flag bug is still worth upstreaming rather than carrying.

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

Progress is now visible directly: `gh issue list --repo matz/spinel --state all --search '"porting Ruby 2D" in:body'`, or `gh issue view <n> --repo matz/spinel`. A closed issue is the signal to re-check the matching workaround.

**Decision (2026-08-10): wait for upstream rather than work around this.** Moving registration out of `Quad#initialize` into each concrete shape class does fix it, but that is roughly 13 classes each repeating a line that exists only to dodge a compiler bug, in `lib/` where all three runtimes would carry it. The bug is filed, it is squarely Spinel's to fix, and the branch is cheap to resume — so the Spinel target stays blocked here on purpose. Re-check by restoring `self.add if add` to `Quad#initialize` and rebuilding the subset.

One behavioral difference survived: the per-frame `update` block ran but every counter it wrote to stayed at zero. That is a second silent bug — a block forwarded through the generated DSL shim and then stored loses its captured locals — filed as `issues/02-forwarded-stored-block-loses-capture.md`.

**How it was found matters more than the bug.** Eleven attempts to reduce *down* from the failing program all passed in isolation. Scaling *up* from a passing probe — adding one structural feature at a time until it broke — found it on the first try, then bisected to two required ingredients (an inheritance chain, and self-registration from inside the constructor) in one more pass. For whole-program-context failures, build up rather than cut down.


**Earlier, on compilation: 2 errors, both from the single `sp_Renderable__unrotate` call** — one undeclared-function, one cascade from it. Three hypotheses have been tested and killed: multiple assignment, `instance_variable_defined?`, and the module-typed receiver being unable to resolve `rx`/`ry`. It is the last thing between the subset and clean C.

Measure with `-ferror-limit=0`. Clang's default limit is 20, and it will silently cap the count — an early before/after comparison here read "20 → 20" while the real numbers were 60 → 42.

### Invalid generated C (2026-08-09, since resolved)

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

## MVP reached: a Ruby 2D script on screen (2026-08-10)

**A real Ruby 2D script, compiled by Spinel, opened a window and drew a square through Ruby 2D's own scene graph.** 5.2 MB binary, 31 frames, screenshot verified.

```ruby
set title: 'Ruby 2D on Spinel', width: 400, height: 300, background: 'navy'
Square.new(x: 160, y: 110, size: 80, color: 'red')
show
```

Build it with `./tools/link_square.sh`, then run `FRAMES=30 SHOT=out.png ./spinel/scratch/square.bin`. The frame cap and screenshot exist so the build checks itself without a human watching a window.

This is the milestone the earlier one was not: `bouncing_balls.rb` proved the C path with hand-written FFI, and the subset proved the `lib/` path with stubs. This is both at once — `lib/`'s `Window`, `Renderable`, `Quad` and `Square` driving the real `R2D_*` core, with a Ruby-owned frame loop.

`tools/build_square.rb` supplies the demo's main; the assembly and the adapter moved into `cli/spinel.rb` when the CLI landed (`spinel_assemble`, `SPINEL_EXT`). Three things the adapter had to get right, each of which failed silently or obscurely first:

- **Qualify every FFI call.** `R2D_DrawQuad(...)` inside the declaring module is an "unsupported call"; `Ext.R2D_DrawQuad(...)` works. This is what `bouncing_balls.rb` already did as `R2D.R2D_DrawCircle(...)`.
- **Spell out the type array.** `[:float] * 24` is rejected; the 24 entries have to be literal.
- **Coerce to `Float` at the boundary.** `Square.new(x: 160, size: 80)` hands **Integers** to `:float` parameters. The call succeeds, the draw counter increments, and the window renders blank — no error anywhere. `.to_f` on every coordinate fixes it. This is the one to remember: it looks exactly like "the scene graph is broken".

`R2D_ShowWindow` also learned that an empty icon string means "no icon" — a flattened caller has no NULL to pass, since Spinel's FFI has no nil for `:str`.

**Still stubbed:** 31 of the 41 `Ext` entry points are inert. They have to exist, because Spinel compiles the whole reachable graph, but a static square never reaches them. `drain_events` returns `nil` on purpose, which is what keeps input — and therefore issue 10 — out of the picture entirely.

## The CLI: `ruby2d build --spinel` (2026-08-10)

The demo above became a feature. `ruby2d setup --spinel` gets the compiler, `ruby2d build --spinel app.rb` produces a standalone executable, and `ruby2d launch --native` runs it — the same three commands the mruby path uses.

```sh
ruby2d setup --spinel
ruby2d build --spinel app.rb
```

### The flag

`--spinel` is a **modifier, not a target**. `--native` and `--web` say what to produce; `--spinel` says what to produce it with, so it reads the same wherever it appears (`build app.rb --spinel`) and implies `--native`. `--web --spinel` is an error rather than a silent half-build, and stays one until the wasm path exists. `--assets` is rejected too: nothing in the slice can read a file, so accepting it would bundle media the app has no way to open.

Everything else the flag touches is one branch in `build`, which hands the whole build to `build_spinel`. There is no Spinel case threaded through the mruby build steps — the two paths share helpers (`native_platform_flags`, `strip_require`, `create_macos_bundle`), not control flow.

### What the build does

1. **Preflight** the app source and stop if it uses something unsupported.
2. **Assemble** the `lib/` slice, the compatibility transforms, the FFI adapter, and the app into one Ruby file — `spinel_assemble`.
3. **Compile the core**: the five `ext/ruby2d` C files that make up the `R2D_*` renderer, with `-DRUBY2D_NO_RUBY`, archived as `libruby2d_core.a`.
4. **Run Spinel** over the assembled file, linking that archive and the SDL3 statics.

Step 2 is the same function `tools/build_subset.rb` and `tools/build_square.rb` call. That is deliberate: those checks used to assemble the program themselves, so a green check proved something about the harness. Now `rake demo` passing is evidence about `ruby2d build --spinel`.

### Preflight

Spinel compiles the whole reachable graph, so an unsupported class isn't a feature that quietly does nothing — it's a wall of generated-C errors naming Spinel internals. Preflight reads the app first and stops with the line the user wrote:

```
Error: bouncing_balls.rb uses features the Spinel target doesn't support yet.

    line  5  Circle  shapes and media beyond Square, Rectangle, and Quad
    line 12  on      input events — blocked on three upstream bugs, see spinel/README.md
```

The rejected class list is **derived** from `Ruby2D::CLI::LIB_FILES - SPINEL_LIB_FILES`, not written out, so widening the slice narrows the rejections automatically. A `lib/` file that appears in neither list raises `SpinelCompatDrift` — the same drift detection the transforms use, so a new subsystem can't be quietly forgotten on one side.

It matches on source text, and does not try to parse. A class name inside a string reads as a use, which errs toward a false rejection with a clear message — the safer way to be wrong here. `on` only counts at the start of a line or after a receiver, so the English word in a string doesn't trip it.

### Warnings

The generated C compiles with `-w` unless `--debug`. The warnings are about Spinel, not about anything the user wrote, and there are 17 of them on a hello-world; a wall of `incompatible pointer types` on an ordinary build is noise. Under `--debug` they are shown, and they are worth reading there — every silent mistyping bug filed so far announced itself as one of those warnings first, #3784 included. Errors are never capped: `-ferror-limit=0` where the compiler is clang.

### Where the compiler lives

`ruby2d setup --spinel` clones and builds into the cache's sources directory and **leaves the compiler in the checkout**. Copying `bin/spinel` out of it does not work: Spinel resolves `libspinel_rt.a` and its C sources relative to its own `bin/`, so a lone binary fails at link with a missing archive. This was found by doing exactly that.

The build prints the commit it used, read from the checkout's git rather than from a stamp written at install time — so it stays correct for a `RUBY2D_SPINEL` pointing at a tree someone rebuilds on their own.

## What the `Ext` adapter has to solve (2026-08-10)

Mapping `lib/`'s `Ext` calls onto the `R2D_*` core is mostly mechanical — of the 41 the square slice references, 12 are gamepad and the rest are largely one-line window setters. Two are not mechanical, and both were found by reading the call sites rather than by compiling:

**`Ext.window_show(self)` is a pass-self call.** The CRuby path hands the `Window` object to C, which reads its ivars. Spinel FFI cannot do that — there are no callbacks and no way to read a Ruby object from C. This is why `R2D_ShowWindow` takes twelve flattened parameters (title, size, flags, viewport and render mode, icon): the adapter reads the ivars **in Ruby** and passes them positionally. Any other pass-self call needs the same treatment, which is the pattern that will bite when images, text, and canvas are wired up.

**`RUBY_ENGINE` is `"spinel"`, so `Window#show` takes the wrong branch.** The condition is `RUBY_ENGINE == 'ruby'`, so Spinel falls through to the mruby/WASM path where *C owns the loop* — precisely what FFI cannot support. Spinel needs the CRuby-shaped branch, where Ruby runs `tick until @close`.

The honest fix is not a string comparison against a third engine name: the condition is really asking "does Ruby own the main loop?". Until the build path exists, `cli/spinel.rb` rewrites it; when the feature lands, `window.rb` should ask that question directly.

## `square.rb`: the goal, and the one line that was in the way (2026-08-11)

`spinel/square.rb` is USAGE.md's opening example copied verbatim. `ruby2d build --spinel spinel/square.rb` compiles it with no preflight complaint into a 4.9 MB binary whose only dynamic dependencies are system frameworks — and for most of a day that binary segfaulted before its first frame. [#3790](https://github.com/matz/spinel/issues/3790) landed as `fcaf3fcc` the same day; it now draws on a stock compiler, verified headless at two distinct colors.

```
stop reason = EXC_BAD_ACCESS (code=1, address=0xffffffffffffffff)
    frame #0: app`sp_StrStrHash_has_key + 132
->  0x1002f7bf0 <+132>: ldurb  w1, [x19, #-0x1]
```

**`set title: 'My App'` carries no `background:` key.** `Window.set` (`window.rb:672`) runs `@background = Color.new(opts[:background]) if Color.valid?(opts[:background])`, `Color.valid?` opens with `NAMED_COLORS.key?(color)`, and Spinel's `sp_str_hash` reads the tag byte at `s[-1]` before hashing. A nil key is a NULL `const char *`, so that read lands at `0xffffffffffffffff` — the fault address and the `[x19, #-0x1]` in the disassembly, exactly.

It was filed as [#3790](https://github.com/matz/spinel/issues/3790), drafted in `issues/16-…` with a one-line patch. The convincing part is that the convention already existed in the same file: `sp_str_eq`, just above it, handles NULL on either side and says why in its comment — *"nil-vs-string equality is false in Ruby"*. The polymorphic dispatch path guards it too. Only the direct typed call the codegen emits was missing it, so the fix goes where the convention already lives:

```c
if(!s)return 0;
```

The upstream fix is that line with a better constant — `return 14695981039346656037ULL`, the FNV offset basis, so a nil key lands where the empty string would rather than in bucket 0.

Nine variants pin the shape: `key?`, `has_key?`, `include?` and `[]` all crash on a String-keyed hash whatever the value type; an Integer-keyed hash is fine; and a **literal** `nil` at the call site is fine because it gets folded. That last one is why this survived — written directly it never reaches the runtime, and only a nil arriving through a variable faults. With the guard applied, all nine match Ruby, `square.rb` draws, and Spinel's own suite reports 2854 pass, 0 fail, 0 error.

**No check here would ever have caught this.** Every fixture on this branch sets a background in a single `set` call, so none of them ever passes a nil key. The script that found it is the most ordinary one imaginable, which is the argument for keeping `square.rb` in the repo and building it: the fixtures test the target, and only a script shaped like the documentation tests the *product*.

## Strokes drew nothing (2026-08-11)

`Square.new(size: 80, color: 'red', stroke_width: 8, stroke_color: 'lime')` built, ran, and drew a red square with no outline. `Ext.stroke_quad_uniform` and `Ext.stroke_quad` were among the inert stubs, so `Quad#render` called them every frame and they returned `nil`.

**Nothing here caught it, and the reason is worth keeping.** The `cli` check asked for *more than one distinct color*, which a fill alone satisfies, and the demo fixture had no stroke in it at all. The frame count was healthy, the window was not blank, the build was clean. Every check graded the Spinel target against itself, and none of them asked the only question that fails: does it draw what mruby draws?

**Why C had to change.** `R2D_StrokePath` takes `const float *` for both the vertices and the colors, and Spinel's FFI passes scalars only — there is no way to build the arrays. So `shapes.c` gained `R2D_StrokeQuad`, a flattened closed four-vertex path: the stroke width, then the same 24 floats `R2D_DrawQuad` already takes. `Quad`, `Rectangle` and `Square` are the whole of this slice's stroking and all three are four-vertex paths, so one entry point covers all of it. Adding `Triangle` later needs the same treatment at three vertices, not this function.

**Verified against mruby, not against itself.** `rake compare` builds its fixtures with both engines and diffs the screenshots. They are byte-identical — 640x480, three colors, matching pixel counts — and the geometry is right for the reason it should be: 10,240 lime pixels is exactly a 176² outer minus a 144² inner, an 8px stroke centered on the edge of a 160px square at 2× pixel scale.

Two guards came out of it:

- The `cli` fixture is now stroked and the check asserts **exactly three** colors, naming the stroke when it sees two. Verified by reverting the adapter to a stub: `the stroke drew nothing (2 colors, expected 3)`.
- `tools/link_square.sh` built `libruby2d_core.a` once and reused it forever. Adding a function surfaced as an undefined symbol, which is loud — but a changed function *body* would have silently linked the old code, and that is the same failure again one layer down. The archive now rebuilds when anything under `ext/ruby2d/` is newer.

**`compare` found a second bug on its first run.** The committed fixture strokes in one color, so `Ext.stroke_quad` — the per-vertex sibling — compiled but never executed, which is the same "present but unproven" state the stubs were in. Putting a `stroke_color: %w[red lime blue yellow]` square in the fixture and running `compare` produced `undefined method 'empty?' for an instance of Array` from the Spinel binary while mruby drew it. It is not about strokes: a per-vertex **fill** with no stroke anywhere fails the same way, so the fault is in the `Color::Set` path both share. Root-caused and fixed the same day, and it turned out to be two bugs rather than one — see [Per-vertex colors](#per-vertex-colors-a-compiler-bug-and-one-of-ours-2026-08-11).

## Per-vertex colors: a compiler bug and one of ours (2026-08-11)

`Square.new(color: %w[red lime blue yellow])` compiled and then died with `undefined method 'empty?' for an instance of Array`. Two independent bugs were stacked behind that one message, and fixing either alone still left a wrong picture.

**The compiler bug.** `empty?` on a polymorphic receiver normally lowers to the generic builtin form, `sp_poly_length(recv) == 0`. Spinel skips that lowering when any user class in the program defines **`length`** — and `Color::Set` does. Control then reaches the poly dispatch, which is keyed on the name actually called; nothing in Ruby 2D defined `empty?`, so no dispatch was emitted and `Color.set`'s `!colors.empty?` collapsed to an unconditional raise:

```c
sp_raise_cls("NoMethodError", sp_nomethod_msg_args("empty?", lv_colors, 0, ...))
```

The decisive test was appending a never-instantiated `class Probe; def empty?; end` to the assembled program — the gradient then ran. **Six hand-written probes all passed before that**, which is this branch's usual score against a whole-program bug; the generated C and the compiler source gave the answer in minutes once reading replaced guessing.

**The first root cause was backwards, and it took a reproducer to find that out.** Until 2026-08-12 this section said the dispatch is emitted *only when a user class owns the name called*, which fit every observation — the raise, the working `length` on the same receiver, the never-instantiated `Probe` fixing it. It was wrong: the trigger is a user class owning `length`, and eleven more probes passed while the draft carried the inverted explanation. What settled it was reading `codegen_call_recv.c`'s entry condition rather than `codegen_call.c`'s arm emitter — the bug is that the two disagree about which name to ask about. See `issues/17-…`, which reproduces it in eight lines.

**The fix in `lib/` is not a workaround.** `Color::Set` has `length`, `first`, `last`, `each` and includes `Enumerable`, so `empty?` belongs on it regardless — it just also happens to be the name Spinel needs to see. It is always false in practice, since a set cannot be built from an empty array.

**Our bug, hiding behind it.** With the crash gone the gradient drew — in the wrong place, a 398x159 smear across the top-left instead of 160x160 at (240,160). `Quad#render` passes `Ext.draw_quad` its 24 floats *interleaved*, one vertex at a time, while the Spinel adapter declared them with the coordinates grouped first and then re-interleaved already-interleaved data. `stroke_quad` next to it is grouped and its caller groups too, so only the fill was wrong.

This is the third time an `Ext` entry point compiled, ran, and drew nothing correct because no fixture exercised it — after `stroke_quad_uniform` and `stroke_quad`. The single-color path goes through `draw_quad_uniform`, a different function, so every existing check passed throughout. `rake compare` now builds `tools/gradient_app.rb` as a second fixture; four distinct corner hues mean a transposed vertex order shows up as colors in the wrong corners rather than as a plausible blend. Both fixtures are byte-identical to mruby.

## Fixed upstream, still worked around (2026-08-11)

All five issues filed that morning — [#3786-#3790](https://github.com/matz/spinel/issues?q=%22porting+Ruby+2D%22+in%3Abody) — were fixed the same day, each by a commit citing its number: `1c168009`, `e40fe331`, `329050a6`, `bebef965`, `fcaf3fcc`. `verify_issues.rb` now reports **16 fixed, 0 reproduce**, the first clean board this branch has had.

Two things came out of it, and the second matters more than the first.

**`square.rb` builds and draws on a stock compiler.** #3790's fix is the branch's goal reached: USAGE.md's opening example, unmodified, through `ruby2d build --spinel`, into a binary that opens a window with a red square on navy. Verified headless rather than by eye — the same script with a screenshot at frame 20 writes two distinct colors and exits 0.

**Five fixes bought one workaround.** `rake sweep` cleared `positional_callbacks` and nothing else:

| Fix | Workaround it was filed for | After |
|---|---|---|
| #3786 `1c168009` | `positional_callbacks` | **dropped** |
| #3787 `e40fe331` | `dsl_shims` | still needed — 4 C errors |
| #3788 `329050a6` | `window_guards` | still needed — `unsupported call: CallNode 'shown?'` |
| #3789 `bebef965` | none | — |
| #3790 `fcaf3fcc` | none | — |

So the reproducer-passes-library-fails split, which cost weeks on #3783, happened twice more in one afternoon. It is not an unlucky case; it is the normal outcome of reducing a whole-program failure to five lines. A minimal reproducer captures the construct, and these bugs are about *context* — which same-named method comes first, which module the receiver reached the class through — so the small case can be fixed completely while the library shape is untouched.

**Both residues were reduced the same day**, by writing a second reproducer from the library's failing line instead of from the original small case, and all three were drafted as `issues/19-…`, `issues/20-…` and `issues/21-…` — two filed as #3803 and #3802, the third fixed upstream first. The missing ingredient each time was something the first reproducer had no reason to include:

| Original | What its reproducer left out |
|---|---|
| #3787, top-level `extend` | a **block parameter** on the module method, and a **class with the same method name** |
| #3788, implicit call to a singleton | the `extend` written in a **reopened** class body, which is what splitting a class across files forces |

Neither omission is a mistake in the original — both reproducers are the smallest thing that showed the reported symptom. It is that "smallest thing that fails" and "the shape a library actually has" are different targets, and only the second one predicts whether a workaround can go.

One incidental result: `dsl_shims` had been reported `inconclusive` by every sweep, because `positional_callbacks` rewrote the shims it generates and the two could not be tested apart. Dropping one made the other measurable for the first time.

## A draft fixed by someone else's report (2026-08-12)

`b51c880d` → `01bc08c8`, 17 commits, one of which moved us: [`80a3beb2`](https://github.com/matz/spinel/commit/80a3beb2) *"Keep a module usable from a class and the top level at once"* fixed draft 20 — the silent shadowing bug — before it could be filed. Its parent is `b51c880d`, where the reproduction fails, so the attribution is exact.

It arrived from [#3795](https://github.com/matz/spinel/issues/3795), a different port hitting the **`include`** form of the same defect: a receiverless call inside the class reached the module's top-level copy rather than the class's transplanted one, which is exactly the `sp_DSL_update(NULL)` draft 20 recorded. Nobody filed the `extend` form. Had it gone out that morning it would have been a duplicate.

**Check `rake issues` before filing, not only `rake sweep`.** The standing advice is that the sweep is the check that matters after a pull, because a passing reproducer does not mean a droppable workaround. This pull ran the other way: the sweep did not move at all — six transforms, nothing droppable — while `issues` went 16 fixed to 17. `dsl_shims` guarded two bugs, and one of them being fixed is invisible to a check that only asks whether the transform can go. The two checks answer different questions in both directions, and filing a duplicate is the cost of only running one of them.

**The `extend` shape has no test upstream.** `test/module_included_class_and_toplevel.rb` came with #3795 and uses `include`; nothing exercises a class whose own method is shadowed. Draft 20 is kept as the local record and is worth offering as a test case rather than as a bug.

## What `bouncing_balls.rb` needs, measured (2026-08-12)

The next milestone is an existing example running **unmodified**. `examples/bouncing_balls.rb` was measured rather than estimated: build it with `Circle` swapped for `Square`, the `on` blocks removed, and `s.x += …` written longhand, and **the rest of the script compiles and runs**. So the gap is four items, not a vague "most of the library".

| Gap | Whose | Status |
|---|---|---|
| `Circle` is not in the target | ours | **done 2026-08-12** — see below |
| `s.x += b.vx * dt` — operator write on a `def` writer | upstream | [#3809](https://github.com/matz/spinel/issues/3809) |
| `color: [r, g, b, a]` numeric arrays **segfault** | upstream | [#3810](https://github.com/matz/spinel/issues/3810) — **worked around in `lib/` 2026-08-12**, see below |
| the four `on` handlers | upstream | [#3807](https://github.com/matz/spinel/issues/3807), [#3808](https://github.com/matz/spinel/issues/3808), and two unfiled — see [Events are unsupported](#events-are-unsupported--the-send-is-gone-three-compiler-bugs-remain-2026-08-12) |

Everything else already works: a user `Struct`, `rand`, `Array.new(n) { }`, `<<` / `shift` / `size` / `each`, `Math.exp`, `Float#abs`, and an `update` block mutating top-level locals captured from the script body.

**Two of those were invisible until an example was tried.** Nothing in the library's own subset writes `shape.x += v`, and no fixture used a numeric color, so #3809 and #3810 had never been exercised — #3810 crashes before the first frame for any app with an `[r, g, b, a]` color. `rake compare`'s fixtures use string and `%w[]` colors only; **a numeric-rgba fixture belongs there**, for the same reason the gradient fixture was added after three `Ext` entry points turned out to draw nothing correct.

**The crash was nearly missed twice over.** The build succeeded, and the first check of the binary read `$?` after a pipe — which reports the exit status of the last command in the pipeline, not the program. It printed 0 for a process that died on SIGSEGV. Run the binary without a pipe, or read `PIPESTATUS`, before believing an exit code.

## `Circle` lands, and finds a bug on the way in (2026-08-12)

The first of the four is done. `circle` joins `SPINEL_LIB_FILES`, and the adapter gains `draw_circle` and `stroke_circle` over two new `ffi_func` declarations — `R2D_DrawCircle`, and `R2D_StrokeEllipse` with the radius passed twice, which is exactly what `ext.c` does for the other engines since no `R2D_StrokeCircle` exists. **Pixel-identical to mruby on the new `circle` fixture**, which is the only evidence worth having here.

The fixture is a third one rather than a line added to `cli_app.rb`, for the reason the gradient fixture is separate: these two entry points are reached by nothing else. `draw_circle` takes a sector count where every quad entry point takes coordinates, so it uses a non-default `sectors` — a dropped argument would otherwise still produce the default and look right.

**It is not the numeric-rgba fixture the section above asks for.** That was tried first and segfaults: #3810 is reached through `Color` before the first frame, so the fixture would be permanently red and `rake` with it. The comment at the top of `circle_app.rb` marks where the numeric form belongs once #3810 lands; the case itself is already covered by that issue's reproducer in `rake issues`.

**Adding the class surfaced a new compiler bug** — draft 27, an override of an inherited `attr_reader` dispatching to the override while typed as the attr. `Circle` includes `Renderable`, which declares `attr_reader :width`, and defines its own `def width`; `Renderable`'s `@width` is never set on a circle, so the attr's type and the method's disagree and any user writing `circle.width` gets generated C that does not compile. `Quad#width` is the same shape and is fine, because `Rectangle` assigns `@width` an Integer and the two types agree — which is why this sat in the slice unnoticed since the first square. It is the residue of [#1702](https://github.com/matz/spinel/issues/1702) in the way [#3810](https://github.com/matz/spinel/issues/3810) is the residue of [#3790](https://github.com/matz/spinel/issues/3790): the dispatch half was fixed, the type half was not.

Nothing in `bouncing_balls.rb` calls `width`, so this does not move the milestone. It took five failed probes before the emitted C was read — the [reduction rule](#reducing-a-whole-program-failure) again, and it gave the answer immediately once followed.

## The numeric-color segfault was ours to fix (2026-08-12)

[#3810](https://github.com/matz/spinel/issues/3810) is a real compiler bug and is still open, but the library did not have to be the thing that trips it. `Color.valid?` asked `NAMED_COLORS.key?(color)` before checking that `color` is a String, and a per-vertex array asks `valid?` about each element — so every numeric `[r, g, b, a]` color reached a String-keyed Hash with a Float key and crashed before the first frame.

One `instance_of?(String)` guard in front of the lookup fixes it, and it is the guard `hex?` already makes for itself two lines below. **It lives in `lib/`, not the compatibility layer**, on the same grounds as `Color::Set#empty?`: it reads as ordinary Ruby that any reviewer would accept without knowing Spinel exists, and it is a little faster. The comment at the site names the issue so nobody simplifies it back.

`circle_app.rb` now uses a numeric color with an alpha, so `rake compare` covers the path that crashed — including the blend against the background, which makes the two engines agree on float color math and not just geometry.

**This is the shape to look for in the remaining gaps.** A compiler bug in a construct the library chooses to use is ours to route around; one in a construct the *user's script* uses is not.

## What `bouncing_balls.rb` still needs (2026-08-12)

Re-measured after `Circle` landed, and the earlier count was wrong in both directions. Building the example with only two changes — the two `s.x += …` lines written longhand and the four `on` blocks deleted — **the whole script compiles and runs**: the `Struct`, `rand`, the physics loop, `balls.shift.shape.remove`, all of it.

| Gap | Whose | Can we work around it? |
|---|---|---|
| `Hash#delete_if` on an ivar, reached through `shape.remove` | upstream, unfiled | **yes** — a compat transform of the same shape as `expand_hash_delete`. Needs a reduced reproducer first |
| `s.x += b.vx * dt` — [#3809](https://github.com/matz/spinel/issues/3809) | upstream | **no**, see below |
| the four `on` handlers | upstream + ours | not until four compiler bugs are fixed, and then only with a new FFI seam |

`delete_if` was missed the first time because nothing reaches it until an object is removed, and the earlier measurement never removed one. `Struct` member writes are fine — `b.vy += GRAVITY * dt` compiles — so #3809 costs exactly the two lines that write through `Circle`'s hand-written `x=` and `y=`.

**#3809 is the one that decides "unmodified", and there is no workaround worth taking.** The refused construct is in the user's file, so the compatibility layer cannot reach it — that layer rewrites `lib/`, and rewriting the user's script in the build path is a different thing entirely, one that changes evaluation order for any receiver with side effects. The library-side alternative is turning `x=` and `y=` into `attr_writer`s, which is precisely what deletes the symbol-alignment feature (`x: :center`) they exist for. Upstream has been closing these within hours; waiting is cheaper than either.

## `fountain.rb`: a scene that moves (2026-08-12)

`square.rb` shows the target compiles a Ruby 2D script. **`spinel/examples/fountain.rb` shows it runs one**: an emitter sweeps the top of the window on a sine and sprays balls that fall, bounce off the walls and floor, lose energy, and get recycled back to the emitter once the pool fills. Translucent numeric colors, `Struct`, `rand`, top-level methods, `Math.sin`/`cos`/`exp`, all from one standalone binary.

```sh
RUBY2D_SPINEL=../spinel/bin/spinel ruby2d build --spinel spinel/examples/fountain.rb
ruby2d launch --native
```

It has no input, which is not a stylistic choice — a demo needing input would be a demo of nothing until the four event bugs are fixed. The emitter's sweep replaces the mouse. It recycles balls rather than removing them, which sidesteps the `delete_if` above and is the better design regardless: the allocation count stops climbing the moment the pool fills.

Verified over 1601 frames at its original tunables: the pool caps, the recycle cursor wraps, and the process exits 0. The tunables at the top are meant to be played with — `rake fps[fountain]` has run it at ~2,700 balls.

### `dt` silently truncates to zero when a nested block reads it

The first build ran at full speed and **sat perfectly still** — 241 frames, zero balls, the emitter parked at window center. Nothing failed. `--emit-types` on the assembled source named it in one line: the `update` block's `dt` parameter had inferred as `Integer`, so every frame delta of ~0.004 truncated to 0.

The trigger is a nested block that reads the enclosing block's parameter, which `balls.each do |b| … b.vx * dt … end` does:

```ruby
update do |dt|
  total += dt
  values.each { |v| total = total + v * dt }   # `dt` becomes Integer
end
```

Removing the inner block's use of `dt` restores `poly` and the demo runs. So does reading it into a local first — `step = dt` — which is what `fountain.rb` does, with a comment, because it costs one line and keeps `balls.each`.

**It does not reduce to a standalone program yet.** Three shapes that ought to be equivalent — `yield`, a block stored in an ivar and called later, and that plus the library's two call sites of differing arity (`@update_proc.call(@delta_time)` and `@update_proc.call`) — all compile and run correctly. This is very likely the escaping-lambda-parameter bug already listed under [Events are unsupported](#events-are-unsupported--the-send-is-gone-three-compiler-bugs-remain-2026-08-12), now with a bisected trigger but still no minimal case.

**This is the worst failure mode on this target so far**, and worth remembering as a class: no compile error, no crash, no diagnostic, full frame rate, and a scene that does nothing. The check that found it was `--emit-types`, not the debugger — when arithmetic silently produces nothing, ask what the compiler thinks the types are before asking what the values are.

One smaller gap turned up alongside it: `Window#fps` read 0 on this target, because `_spinel_sync` carried mouse position and window size but not the frame counter or fps, though `R2D_Fps` and `R2D_FrameCount` were already declared in the adapter. Both are synced now — `window.c` writes them straight into the Ruby object from C on the other engines, which is the path that does not exist here.

## `mandelbrot.rb`, and what `Canvas` would take (2026-08-12)

The third example is a port of `examples/mandelbrot.rb`: it computes the set band by band behind a progress bar, then zooms itself into a boundary block every couple of seconds, and returns home when doubles run out of precision. **30,000 objects, and the heaviest thing this target has run** — heavy enough that Spinel holds 120fps on it while CRuby manages 76 and mruby 30.

**It does not use `Canvas`, and that was the interesting part.** The original renders into one, which is exactly the right primitive — rasterize once into a texture, draw one quad. But `Canvas` cannot be reached from this target at all, and not because of a missing binding: *every* entry point in `canvas.c` takes the Canvas Ruby object as `argv[0]`, reads its ivars, and stores the `R2D_Canvas *` back inside it with `obj_set_struct`. There is no `R2D_Canvas *` API underneath to call. Supporting it means splitting that layer the way `window.c` and `shapes.c` are already split — a Ruby-free core plus a thin binding — and then finding a way to hand it rectangles, since `fill_rectangles` takes an array and the FFI passes scalars only. `Text` is the same shape. Both are real work in `ext/`, on code all three engines share.

A `Square` per block needs none of it. The grid is built once and only recolored afterwards, so nothing is created or removed after startup — which also keeps it clear of the `Hash#delete_if` that `remove` reaches. It is blockier than a canvas and it re-renders every square every frame, and it works today.

**It cost one more compiler bug, drafted as 28.** The obvious structure — `blocks` and `counts` as top-level arrays, passed into `render_band` — is refused: `unsupported closure capturing a non-integer variable (later slice)`, from the `update` block capturing them. An array of `Integer` is fine, an array that stays empty is fine, a bare object is fine, and the identical block called immediately rather than stored is fine. Holding the two tables in constants and letting the methods read them directly avoids it, which is what the example does.

The diagnostic names no line — `node -1 (?)` — so the only way to find it in a 250-line file was to bisect by deletion. That is worth as much of the report as the bug.

### What the example is tuned for, and why it matters

Its first tuning showed 3.9× against CRuby, and that number was mostly measuring the wrong thing. Splitting the frame into the escape-time arithmetic and everything else says why:

| | CRuby | Spinel | speedup |
|---|---|---|---|
| escape-time math | 9.9 ms | 1.0 ms | **9.8×** |
| scene dispatch and the rest | 50.3 ms | 14.5 ms | 3.5× |
| blended | 60.2 ms | 15.5 ms | 3.9× |

**Two different speedups are being averaged, and the tunables decide the weights.** `PIXEL` buys sharpness with per-object dispatch, where Spinel is ~3.5× faster and that ratio does not move. `MAX_ITER` buys colour detail with pure Ruby float arithmetic in a tight loop, where it is far ahead — and *increasingly* so, because at shallow depths the per-block overhead around the loop still dominates it:

| Configuration | objects | math is | math speedup | blended |
|---|---|---|---|---|
| `PIXEL 2`, `MAX_ITER 80` | 120,000 | 16% of CRuby's frame | 9.8× | 3.9× |
| `PIXEL 2`, `MAX_ITER 800` | 120,000 | 60% | 29.7× | 7.5× |
| `PIXEL 4`, `MAX_ITER 800` | 30,000 | 64% | 44.9× | 8.3× |
| `PIXEL 4`, `MAX_ITER 2000` | 30,000 | 77% | 33.7× | **11.5×** |

The example ships at the last row. It is also the best-looking of the four — deep iteration is what gives the boundary its fine colour banding — so sharpening the picture and exposing the compiler's advantage turn out to be the same edit.

**Read that table's middle columns with suspicion — see the next section.** It was measured with the example's random zoom target still in place, so each row rendered a different region of the fractal. The blended column is directionally right and the shipped configuration is unchanged by the correction, but the math-speedup column is not comparable row to row, which is why it wanders up to 44.9× and back down.

**The general lesson is worth more than the number.** A benchmark that blends a 30× speedup with a 3.5× one reports neither. Before tuning anything for a ratio, measure which part of the frame the ratio is actually coming from.

## Tuning it properly, and the lever that was free (2026-08-12)

Going back to the sweep above with the intent of pushing the ratio further turned up a measurement bug first: the zoom target is picked at random, so no two runs render the same thing. Two runs of *identical* source came out 37% apart. Pinning the view — never zoom, re-render the home view every pass — made runs repeatable to within about 1%, and only then was anything else worth measuring.

**Micro-optimizing the escape loop does nothing.** Six variants, both engines, controlled workload:

| Variant | CRuby frame | Spinel frame | math speedup |
|---|---|---|---|
| baseline | 26.57 ms | 4.20 ms | 24.5× |
| `2.0 * zr * zi` instead of `2 *` | 26.76 ms | 4.22 ms | 24.1× |
| carry `zr²`/`zi²` across the guard | 26.56 ms | 4.20 ms | 24.6× |
| `MAX_ITER` hoisted into a local | 26.55 ms | 4.17 ms | 24.5× |
| palette of `Color`s, not arrays | 26.32 ms | 4.19 ms | 27.2× |
| all of the above | 26.21 ms | 4.15 ms | 27.4× |

The squares-hoist is the interesting null: it removes two of five multiplications per iteration and changes nothing, because `cc -O2` already eliminates the common subexpression on the Spinel side and CRuby's loop is bound by interpreter dispatch rather than by the multiplies. The `Color` palette is the only row that moves at all, and it moves the *math* component (which includes the per-block `color=`) without touching the blended figure. The loop in the example is written for clarity because clarity is free here.

**Scene dispatch is a flat 3.2×, everywhere in the path.** A static grid of 30,000 squares, measured visible and then hidden, so the difference is the render preamble and the native call:

| | CRuby | Spinel | speedup |
|---|---|---|---|
| visible (full render) | 12.62 ms | 3.95 ms | 3.19× |
| hidden (scene loop reaches each object and stops) | 3.35 ms | 1.07 ms | 3.12× |
| difference (the draw itself) | 9.27 ms | 2.88 ms | 3.22× |

That uniformity is the useful part: there is no stage of the object-render path where Spinel is disproportionately slow, so there is no Spinel-specific pathology to go fix. It is 3.2× the whole way down, and 27% of it — the same 27% on both engines — is just `@objects.each` reaching each object and asking `visible?`.

So the ratio is decided entirely by the mix of a ~25× component and a 3.2× one, and **`BAND_ROWS` turned out to be the mix lever that costs nothing.** `PIXEL` and `MAX_ITER` both trade against the picture; block-rows per frame trades only against how fast a view streams in:

| `BAND_ROWS` | CRuby frame | Spinel frame | math is | blended |
|---|---|---|---|---|
| 1 | 24.55 ms | 4.60 ms | 45% of CRuby's frame | 5.3× |
| 2 | 28.51 ms | 4.47 ms | 53% | 6.4× |
| 4 | 47.31 ms | 4.95 ms | 71% | 9.6× |
| 8 | 78.52 ms | 6.18 ms | 83% | 12.7× |
| 15 | 132.83 ms | 8.13 ms | 90% | 16.3× |

On the fixed view it climbs monotonically, but the example ships at 4 rather than 15 for two reasons the fixed view cannot show. A deep zoom costs roughly twice the home view, and past `BAND_ROWS = 8` that pushes Spinel off the display refresh rate on the deepest views — losing the thing the demo is for. And on the real zooming example the *measured* headline peaks at 4 and falls back at 8 (15.8× versus 13.4×), because once a view completes in nineteen frames the fixed pause covers a different fraction of each engine's frames.

`rake fps[mandelbrot,200]` at the shipped values:

```
engine         µs/frame      µs/object   relative
Spinel            4487           0.15     21.62x
CRuby            70832           2.36      1.37x
mruby            97019           3.23      1.00x

wall clock, all present-bound:
CRuby             14.5 fps
mruby              8.6 fps
Spinel           116.3 fps
```

**15.8× against CRuby, up from 4.9×, without touching a pixel of the output.** The wall clock is the part worth showing: Spinel holds the display's refresh rate while CRuby runs at 14.5fps on the same source.

## How fast is it, really (2026-08-12)

**Spinel runs the same scene's Ruby work about 4.5-5× faster than mruby and 2.5× faster than CRuby.** `rake fps[name]` builds any example from `examples/` on all three engines and reports it:

```
  balls: update and scene dispatch per frame
  180 objects at the end of the run

  engine         µs/frame      µs/object   relative
  Spinel             191           1.06      5.04x
  CRuby              514           2.86      1.87x
  mruby              964           5.35      1.00x
```

The absolute µs move with machine load; the ratios are the stable part, and across runs the Spinel-to-mruby figure sits between roughly 4.5× and 5×. On `fountain.rb` with ~2,700 balls it is 3.8×.

**`mandelbrot.rb` is the one to point at**, because it is heavy enough that the wall clock finally separates too — Spinel holds 120fps while CRuby manages 76 and mruby 30:

```
  mandelbrot: update and scene dispatch per frame
  30,003 objects at the end of the run

  engine         µs/frame      µs/object   relative
  Spinel            3926           0.13     11.44x
  CRuby            19251           0.64      2.33x
  mruby            44926           1.50      1.00x
```

**Wall-clock fps cannot answer this question, and finding that out is most of the work.** `SDL_RenderPresent` blocks at the display's refresh rate whatever the cap says: measured at ~120fps for 5 balls and for 3000, with vsync off *and* with a finite 10,000fps cap. All three engines tie at the refresh rate and the number says nothing. `benchmark/README.md` says as much for the native harness — "an empty window can measure *slower* than a populated one" — and solves it by subtracting present out with two harness-only method wrappers. That is runtime monkey-patching, so it cannot work on an AOT target.

What `tools/fps.rb` measures instead is the Ruby side directly: the example's `update` block plus the scene-graph dispatch that draws every object. Present and the GPU are identical across all three engines and sit outside the timed region.

**The example does not have to cooperate, and that is the whole design.** The harness is spliced in ahead of `show`, takes whatever procs the example already registered, and re-registers its own around them. The two clock reads bracket exactly the right work because of where the frame loop runs each hook: `update` is the first thing in `tick`, and the `render` block runs *after* every object's `_render_scene` inside `render_objects` (at the default `z: :foreground`). So one clock read at the top of `update` and one in `render` spans the frame's entire Ruby side, and no example needs editing.

A benchmark-grade example still has to hold its workload still — `balls.rb` creates everything at startup and steps a fixed timestep, because with a real `dt` a faster engine would simulate further per frame and measure itself slower. `fountain.rb` grows its scene, so the tool notices the engines finishing on different object counts and drops the per-object column rather than printing a figure that means nothing.

Caveats worth keeping attached to the number: one scene, one machine, fastest of three runs. It is a per-object dispatch benchmark, not a claim about whole programs.

### Calling the *default* `@render_proc` through reflection is a SIGBUS

Building the harness turned one up. Fetching `@render_proc` with `instance_variable_get` and calling it crashes the Spinel build with a SIGBUS about a dozen frames in — **but only when the example never registered a render block**, so what sits in that ivar is the `proc {}` that `Window#initialize` creates. The same empty block written literally in the example is fine. A user-registered proc fetched exactly the same way is fine. It is specific to the default one.

It does not reduce: a class whose `initialize` stores a `proc {}`, fetched by `instance_variable_get` and called, compiles and runs correctly. So the trigger needs something the small case does not have, and the reduction is still open.

The tool avoids it by reading the example's source and only fetching a proc the example actually registered — which it needs to do anyway, since an example with no `update` block would hit the identical shape.

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

**What shipped is narrower than this list.** `SPINEL_LIB_FILES` in `cli/spinel.rb` also leaves out `circle`, `ellipse`, `line`, `polygon`, `polyline`, and `triangle`: they compile, but each needs `Ext` entry points the adapter doesn't have yet, and a missing one is a compile error rather than a dormant feature. Circle, ellipse, triangle, and line are the cheap ones — `R2D_DrawCircle`, `R2D_DrawEllipse`, `R2D_DrawTriangle`, `R2D_DrawLine` are all scalar-only, so they are `ffi_func` declarations plus an adapter method each. Polygon and polyline are not: they take `const float *` vertex arrays, which Spinel's FFI has no way to build from a Ruby Array.

### Checklist

- [x] **Step 0 — compile the real `lib/`.** Done; see [Step 0 results](#step-0-results-the-real-lib-under-spinel). The MVP subset compiles clean.
- [ ] Land fixes 1–3 from the Step 0 table (expand `attr_*`/`alias` in `module Renderable`, `alias_method` in `class << self`). Safe under CRuby and mruby, so these can go to `main` on their own.
- [x] Unblock issue 6 for the MVP — rewrite the 4 internal call sites to `DSL.window.<m>(self)`. Verified: MVP subset compiles clean, nothing neutralized. Provisional; see [Workarounds to re-check](#workarounds-to-re-check).
- [ ] Reduce issue 6 with `bin/spinel-reduce` and report upstream. The public `Window.add(obj)` class method still fails, so the bug is worked around, not fixed.
- [ ] Redesign the `on event: { ... }` hash-filter path around a compile-time predicate table (issues 4 and 5), or gate it off on the Spinel target for the MVP.
- [x] `find_spinel` in `cli/spinel.rb`, mirroring `find_mrbc`: `RUBY2D_SPINEL` → cache build → `$PATH`. See [Getting Spinel](#getting-spinel).
- [x] `ruby2d setup --spinel` builds Spinel into the per-user cache. No stamp file in the end — the commit is read from the checkout, which can't go stale.
- [x] `--spinel` flag in `bin/ruby2d`, position-independent like `--native`/`--web`. The `# ruby2d:compiler spinel` source directive was **not** built: a compiler choice is a property of the build, not of the app, and one way in is enough until someone wants the other.
- [x] Thin C shim: the `RUBY2D_NO_RUBY` core, five `ext/ruby2d` files archived as `libruby2d_core.a` at build time.
- [x] `ffi_func` declarations for the slice — as `SPINEL_EXT` in `cli/spinel.rb` rather than a `lib/` file, since it is only ever read as text and would not load under CRuby. It still duplicates the binding list and will drift from `ext/`; a shared manifest generating both remains the eventual answer.
- [x] Replace the `include Ruby2D` / `extend Ruby2D::DSL` preamble with generated top-level DSL shims on the Spinel path only.
- [x] Link step: `--link <archive>` for the SDL3 statics and `--cc` to carry the macOS frameworks.
- [ ] Run an existing example unmodified — `bouncing_balls.rb` needs `Circle`, #3809, #3810 and input handling; see [What `bouncing_balls.rb` needs, measured](#what-bouncing_ballsrb-needs-measured-2026-08-12).
- [ ] Benchmark that example against the mruby build.

Reused without change: `ruby2d launch --native` and the macOS `.app` bundle step. Asset bundling is *not* reused — nothing in the slice can read a file, so `--assets` is rejected rather than accepted and ignored.

### Explicitly out of scope for the MVP

Image, text, canvas, font, and audio bindings; the WebAssembly target; Windows and Linux (Spinel supports Linux and macOS, but not native Windows — Windows needs WSL); and any generated-binding tooling.

## How the build path finds Spinel

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

## Building the demo

`bouncing_balls.rb` needs a Ruby-free `libruby2d_core.a`. Build it from the tree with `RUBY2D_NO_RUBY`, which compiles out the binding layer and leaves the SDL3-touching core (~70 `R2D_*` symbols):

```sh
R2D=/path/to/ruby2d
for f in ruby2d window shapes fps font; do
  cc -c -O2 -DRUBY2D_NO_RUBY \
     -I"$R2D/ext/ruby2d" -I"$R2D/assets/platform/include" \
     "$R2D/ext/ruby2d/$f.c" -o "$f.o"
done
ar rcs libruby2d_core.a ruby2d.o window.o shapes.o fps.o font.o
```

`font.c` is in the list only because `fps.c`'s overlay calls its bitmap-text functions; the other four are what a shapes-only app needs.

Then link, passing the macOS frameworks through `--cc` and the archives through `--link` — Spinel places `--link` inputs between the generated TU and its runtime, which is the order that resolves:

```sh
LIBS="$R2D/assets/platform/macos-arm64/lib"
FW="cc -framework AVFoundation -framework AudioToolbox -framework Carbon \
    -framework Cocoa -framework CoreAudio -framework CoreHaptics \
    -framework CoreMedia -framework ForceFeedback -framework GameController \
    -framework IOKit -framework Metal -framework QuartzCore \
    -framework UniformTypeIdentifiers"

spinel bouncing_balls.rb --cc="$FW" \
  --link "$PWD/libruby2d_core.a" \
  --link "$LIBS/libSDL3_ttf.a"   --link "$LIBS/libSDL3_image.a" \
  --link "$LIBS/libSDL3_mixer.a" --link "$LIBS/libSDL3.a" \
  -o bouncing_balls
```

Run it bare for an interactive window, or `./bouncing_balls 150 shot.png` to stop after 150 frames and write a screenshot — which is how the build gets checked without a human watching one.

## Reducing a whole-program failure

**Read before you reduce.** Three oracles sit in `tools/` and they make reduction look like the default move. On this branch it has not been. Every bug that was actually cracked came from *reading* something — the line the compiler names, Spinel's own commit log, its source — and usually in minutes:

| Bug | What worked | Cost |
|---|---|---|
| #11, the block-capture root cause | `git log --grep` over Matz's fixes for #3772 and #3783 named the mechanism, file, and line | ~5 min, after 21 hand-written probes all passed |
| issue 14, massign | opened the assembled subset at the line clang named and asked what the probe had dropped | ~2 min |
| issues 12 and 13 | mirrored the real construct out of `lib/` instead of inventing a shape | ~10 min |
| #3783 by reduction | killed after 12 hours, no result, and by then superseded | 12 h |
| massign by reduction | 3,980 → 208 lines, and it drifted onto a *different* bug | ~6 h, beaten by a 15-line hand-written case |

The two reduction runs cost about 18 hours and produced nothing that was used. So reach for `spinel-reduce` when reading has genuinely failed, not first — and always pin `EXPECT` to the specific diagnostic. The massign run drifted precisely because it was launched with `EXPECT='error:'`, which matches any clang error, so the reducer was free to wander to another one and did.

Two techniques earned their keep, both counter to the obvious approach.

**Scale up, don't cut down.** Eleven attempts to reduce the failing program all passed in isolation, because the trigger *was* the surrounding structure. Starting from a passing probe and adding one structural feature at a time found it immediately, then bisected to the two required ingredients in one more pass.

**Make the oracle two-sided.** `spinel-reduce` needs `SPINEL=/path/to/bin/spinel` exported and a custom `--oracle-cmd`; the built-in `unsupported` oracle reports "not interesting" and refuses to start. An oracle that only greps compiler output is worse than useless — the reducer deletes the program into something CRuby rejects too, producing a case no maintainer can act on. Require both sides:

```sh
#!/bin/sh
f=$(cd "$(dirname "$1")" && pwd)/$(basename "$1")
BIN="${f%.rb}.bin"
ruby "$f" >/dev/null 2>&1 || exit 1                    # 1. still valid Ruby
"$SPINEL" "$f" -o "$BIN" >/dev/null 2>&1 || exit 1     # 2. still compiles
out=$("$BIN" 2>&1); rc=$?; rm -f "$BIN"                # 3. still fails at run time
[ $rc -eq 0 ] && exit 1
echo "$out" | grep -q "NoMethodError" || exit 1
```

Note the absolute path for the binary. A bare relative name gets searched on `PATH`, silently reports "command not found", and the oracle reads that as "not interesting" — rejecting a perfectly good input.

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

## 24 of 28, and the first bug that fails silently (2026-08-13)

Upstream moved 29 commits overnight, most of them ours. Rebuilt at `84f5a236`, `verify_issues.rb` goes from 17 fixed to **24**, and from ten reproducing to three:

```
24 of 28 now behave correctly.
```

Nine of the ten that were open closed, including every one filed on 2026-08-12: `60ac6cfa` (#3805), `70c24900` (#3802), `3d56e53d` (#3806), `0c075869` (#3807), `9381d631` (#3809), `9d249a34`, `2bb6d7bf` and `092ebce5`. What is left is drafts 27, 28 and 29, none of them filed.

**Draft 24 came back `CHANGED` rather than fixed, and reading it by hand was worth the minute.** [#3808](https://github.com/matz/spinel/issues/3808)'s double binding is gone — an optional positional no longer receives the keyword hash — but a `nil` default leaves a residue:

| Expression | Spinel | Ruby |
|---|---|---|
| `event.nil?` | `true` | `true` |
| `event == nil` | `true` | `true` |
| truthiness | falsy | falsy |
| `event.class` | `Hash` | `NilClass` |
| `event.inspect` | `{}` | `nil` |

The value is nil; the slot is typed `Hash` from its `**kwrest` sibling, so identity and rendering disagree. Defaults of `:none` or `42` are unaffected. The `event.nil?` dispatch the issue was filed for now works, which is what `on` needs.

**The workarounds were re-tested against the real library rather than against their reproducers**, which is the only way the next paragraph could have been found:

| Accommodation | State at `84f5a236` |
|---|---|
| `obj.attr += v` refused | **gone** for ordinary receivers, including `s.x += b.vx` on a `Struct` field — still refused for an index receiver, `arr[0].x += 1` |
| `step = dt` before any nested block | **still needed** — `dt` inside `ARR.each { }` is still `0` and still `Integer` |
| no `remove` | **still broken**, now a run-time `undefined method 'delete_if' for an instance of Hash` rather than a compile error. `Renderable#z=` calls `remove`, so `obj.z = 5` crashes with it |
| collections in constants (draft 28) | **still needed** |

**And then draft 29, which is the first one on this branch that compiles clean, runs clean, draws a window, and is wrong.** A write to a run-time-typed receiver is emitted as a `switch` on class id built from the attribute table alone:

```c
{ sp_RbVal _t4 = lv_o; mrb_int _t5 = 42LL;
  switch (_t4.cls_id) { case 0: ((sp_Attr *)_t4.v.p)->iv_x = _t5; break; } }
```

`case 0` is the class declaring `x` as an `attr_accessor`. A class whose writer is a hand-written `def x=` gets no arm, there is no `default`, and the store falls through and vanishes. The read of the same attribute on the same receiver is emitted correctly, with an arm for the method and a `default` that raises. The trigger is that *some* class in the program declares the name as an attr — with no attr anywhere the write dispatches through the method table and every class is handled.

In this library that silently discards every `shape.x = …` and `shape.y = …` on a shape held in an array, while `shape.color = …` on the same object works, because `Renderable#color=` is the only definition of that name and `x=` collides with `MouseEvent`'s `attr_accessor :x`. No shipped example hits it: `balls.rb` and `fountain.rb` hold their shapes in `Struct` fields, and `mandelbrot.rb` only ever writes `color`. That is luck, not design — `examples/README.md` recommends holding a collection in a constant as the way around draft 28, which is exactly the shape that triggers this.

**What found it was reading the generated C, after five reduction attempts all compiled correctly.** The [reduction rule](#reducing-a-whole-program-failure) again: the emitted code named the mechanism in one line, and the 34-line reproducer followed from it in a minute. Scaling up from a passing probe found nothing here, because the missing ingredient was not structural — it was that another class in the program had to declare the same name as an attr.

**The lesson for the checks.** Draft 29 passed every one of the five: `subset` matched CRuby, `demo` drew its two colors, `cli` drew its three, `preflight` refused what it should, `issues` was green. All five ask whether something compiles, runs, or draws; none asks whether the library *behaves* the way it does on CRuby. `subset` is the only one that compares against a CRuby control at all, over four lines of output. A scene-level differential check — build a scene, drive it through the public API, dump the object state as text, diff the two engines — would have caught this on its first run, and is the obvious next piece of tooling.

## Input is one bug away (2026-08-13)

With [#3807](https://github.com/matz/spinel/issues/3807) fixed and [#3808](https://github.com/matz/spinel/issues/3808) workable, the four blockers in [Events are unsupported](#events-are-unsupported--the-send-is-gone-three-compiler-bugs-remain-2026-08-12) are down to one. Lifting the preflight's rejection of `on` and building a script that registers a key handler stops at a single site:

```
spinel: build/app.rb:2128: unsupported proc referencing an uncaptured outer variable `proc` (later slice): node 14120 (LambdaNode)
```

That is `interactive.rb:41` — `wrapped = ->(e) { proc.call(e) if values.any? { |v| e.matches?(field, v) } }`, the fourth blocker, the lambda in the *per-object* `on` that references the enclosing method's block parameter. The test script only used window-level `on`; whole-program compilation reaches `Interactive#on` regardless of whether the app calls it, so one method the user never touches refuses the build.

**Stubbing out that one branch and rebuilding, the same script compiles, links, runs and exits clean.** So nothing else in the event path blocks the target: what remains is that construct, plus `drain_events`, which is ours — it still returns `nil`, and giving it a real body means an FFI entry point that returns an array of event objects.

It did not reduce. A lambda referencing `&proc`, that lambda containing a nested block reading its own parameter, and the whole thing built inside an enclosing block all compile standalone at `84f5a236`. Something else in the real structure is required, so it stays a research note with the site named rather than a filed issue.

## Working artifacts

Everything from the research — the Spinel clone and build, the ~34 language probes, the Step 0 harness (concatenator, line-mapper, patch script), the SDL3 window test, the wasm build, and the benchmark — lives in a **session-scoped scratchpad and is disposable**. Nothing in this repo depends on it. The sections above are written so each result can be reproduced from a clean checkout; re-clone Spinel and rebuild rather than hunting for those files.

The one piece worth recreating early is the Step 0 harness, since the checklist leans on it: concatenate the `LIB_FILES` slice into one `.rb`, keep a line-map back to source files (offsets accumulate as `lines + 2` for the `"\n\n"` join), run `spinel -c`, and patch forward one error at a time.
