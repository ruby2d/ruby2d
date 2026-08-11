# Spinel build path

Research notes and working checklist for compiling Ruby 2D apps with [Spinel](https://github.com/matz/spinel), Matz's Ruby AOT compiler, as an opt-in alternative to the mruby default. Findings are from 2026-08-07 to 2026-08-10 on macOS arm64; mruby stays the default for `ruby2d build`. Spinel moves fast, so the commit matters: the initial research ran against `8b029022e663`, the MVP work against `f0f7dc0d7131`, and **everything was last re-verified against `c70ed332` (2026-08-10)** — `cd spinel && rake` green on all five checks at `20a06d01`.

## Start here

The rest of this document is a research log in discovery order. This section is the orientation; read it first.

### Status

**The feature is wired: `ruby2d build --spinel app.rb` compiles an ordinary Ruby 2D script to a standalone 5.2 MB binary.** No hand-run scripts, no paths to set — get the compiler with `ruby2d setup --spinel`, then build. The app goes through `lib/`'s own scene graph into the real `R2D_*` core, with Ruby owning the frame loop. See [The CLI](#the-cli-ruby2d-build---spinel-2026-08-10).

What's left is coverage, not plumbing: the target draws `Square`, `Rectangle`, and `Quad`, and nothing else yet. An app using anything more stops before compiling with a message naming it — see [Preflight](#preflight).

`bouncing_balls.rb` separately drives the same core at 60fps from hand-written FFI, and is the reference for the FFI patterns.

**The `lib/` blocker is gone.** All seven of [#3771-#3777](https://github.com/matz/spinel/issues?q=%22porting+Ruby+2D%22+in%3Abody) are fixed upstream, including #3773, and `verify_issues.rb` confirms all seven independently. The square-only slice now compiles to zero C errors and runs end to end: it constructs a `Square`, registers it, dispatches through the scene graph, and prints `SUBSET OK`. Two workarounds were deleted as a result.

**All ten filed bugs are closed upstream** ([#3771-#3784](https://github.com/matz/spinel/issues?q=%22porting+Ruby+2D%22+in%3Abody)), and `verify_issues.rb` reports 10 fixed, 0 reproduce.

**One of them is not actually fixed for us** — and it is now root-caused, with a patch. #3783's reproducer passes at `20a06d01` while the library shape still fails, because escape analysis resolves a forwarded block's callee by taking the first same-named method it finds, and Ruby 2D has four methods named `update` of which the first is a forwarder and only `Window#update` stores the block. Drafted as `issues/11-…`, diff in `issues/11-ambiguous-forward-callee.patch`, verified against Spinel's own suite (2823 pass, 0 fail). See [root cause and patch](#3783-is-closed-and-still-broken-for-us--root-cause-and-patch-2026-08-10).

**What stands between here and zero workarounds is a finite, known list.** [`spinel-doctor`](#the-whole-library-at-once-spinel-doctor-2026-08-10) on the full 37-file library reports exactly **one** unsupported construct — the `e.send(:"#{k}?", v)` event filter — so the rest is FFI adapter work. On the compiler side, five workarounds cover unfiled compiler bugs. Three now have minimal reproducers and are drafted (`dsl_shims` → issue 12, `window_guards` → issue 13, `expand_massign` → issue 14). Two do not: `bypass_window_class_methods` and `expand_hash_delete` are still needed while their minimal shapes pass standalone — see [Two workarounds with no reproducer yet](#two-workarounds-with-no-reproducer-yet). Reproduce, read the source, propose a fix — the route that worked for #11.

Three things remain gaps rather than bugs, all inherent to AOT: the class pattern needs `Module#ancestors` reflection, and both window-level and per-object `on` dispatch a filter predicate through a runtime `send` — which means **no script using input events compiles today**. See [Deliberate feature gaps](#deliberate-feature-gaps-on-the-spinel-target).

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
  cli        pass     built an app that drew 2 colors over 31 frames
  preflight  pass     rejected unsupported features by name
  issues     pass     7 fixed, 3 reproduce
```

- **subset** compiles the `lib/` slice and diffs it against the same program run under CRuby. Any divergence is a compiler difference, because the control has to pass first.
- **demo** builds the square and checks the **pixels**, not the exit status.
- **cli** builds `tools/cli_app.rb` with `ruby2d build --spinel` and checks its pixels and its frame count. The frame count is the point: a zero would mean #3783 is back, which no other check would notice.
- **preflight** builds an app using `Circle` and `on` and checks the build refuses it *by name*.
- **issues** re-runs every filed reproducer. A `FIXED` row is the cue to drop the matching workaround with `SPINEL_SKIP=` and rebuild.

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
| `issues/` | The upstream bug reports, one file per issue |
| `tools/` | `check.rb` runs the checks behind `rake`; `spinel_path.sh`/`spinel_env.rb` resolve the compiler so no recipe hardcodes a path; `build_square.rb` + `link_square.sh` build the square demo; `build_subset.rb` assembles the slice with `Ext` stubbed (`SPINEL_SKIP=` drops workarounds); `cli_app.rb` is the fixture the `cli` check builds; `verify_issues.rb` re-runs every filed reproducer; `run_capped.sh` runs a binary under a time cap; `reduce_oracle.sh` and `reduce_oracle_diff.sh` are the two-sided oracles for `spinel-reduce` — the first for crashes, the second for silent wrong answers |
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

### Events are unsupported, per-object and window-level alike

**Window-level `on` does not compile at all** (2026-08-10), and not only in its filtered form. `Window#on`'s two branches share a method body, so `build_filter_wrapper`'s `e.send(:"#{k}?", v)` is compiled whichever form is called — even `on(:mouse_down) { }` fails with *"unsupported send with a runtime method name"*. Verified on the subset, not inferred.

That rules out any script with input handling until it is addressed, which is most of `examples/`. The fix is the same shape as the per-object one below and equally a `lib/` design decision: `EVENT_FILTER_PREDICATES` is a small closed map, so the dispatch could be a `case` instead of a `send`. The interpolated `:"#{k}?"` form in the hash-filter branch needs the same treatment.

### Per-object events are unsupported

The original reason — a nested include not carrying `Interactive`'s methods across — was fixed by #3774. The feature is still off, for a different and more durable reason found on 2026-08-10.

`Interactive#on`'s filtered form dispatches the matcher predicate by name:

```ruby
wrapped = ->(e) { proc.call(e) if values.any? { |v| e.send(predicate, v) } }
```

Spinel rejects that outright — *"unsupported send with a runtime method name (AOT needs a compile-time-known name)"* — and it is a compile error for the whole program, not a run-time failure of that path, so merely not calling `on` is no defense. The smoke test only compiles because it never calls `on` at all, which leaves the method unreachable and uncompiled.

This one is fixable on the Ruby side whenever the feature is wanted: every value in `OBJECT_EVENT_FILTER_PREDICATES` is `:button?` today, so the `send` could become a direct call. That trades away the indirection the map exists to provide, so it is a design decision for `interactive.rb` rather than a workaround to bury in `cli/spinel.rb`.

## #3783 is closed and still broken for us — root cause and patch (2026-08-10)

All ten filed bugs closed. Sweeping the workaround table found nine of the ten genuinely fixed in the real library, and one not. Chasing that one produced a root cause, a twenty-line reproducer, and a patch that passes Spinel's own suite — drafted as `issues/11-…` with the diff in `issues/11-ambiguous-forward-callee.patch`.

**The cause.** Escape analysis decides whether a forwarded block's captures need heap cells by resolving which method the block is forwarded into. When the receiver cannot be resolved it falls back to matching by name and takes the **first** scope it finds (`src/analyze.c`, from [`0780e65a`](https://github.com/matz/spinel/commit/0780e65a)). Ruby 2D has four methods named `update` that take a block — `ClassMethods#update`, `Window#update`, `DSL#update`, and the generated top-level shim, in assembled order — and only `Window#update` stores it. `window/class_methods.rb` comes first and forwards, so the forward is judged harmless and the block is inlined with its captures uncelled.

**What made it findable** was reading Matz's own fix commits rather than guessing at shapes. Twenty-one hand-built probes all passed; the commit message for `0780e65a` named the mechanism in one sentence, and the code showed the `break`. The prediction that followed — that the bug depends on *definition order* — reproduced immediately:

```
storer defined first       ok    n=3
forwarder defined first    FAIL  n=0
```

**The fix** treats an ambiguous forward as an escape instead of betting on one candidate, which costs no more than the single-match case already accepts. Verified three ways: the reproducer, Ruby 2D's callbacks with `positional_callbacks` removed, and `make test` in the Spinel checkout at 2823 pass / 0 fail / 0 error.

Keep `positional_callbacks` until the fix is upstream — the branch has to build with a released compiler, not a locally patched one.

### How the evidence was gathered

Remove `positional_callbacks` and the subset still compiles, still runs, and still prints `SUBSET OK` — with one earlier line wrong:

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
 18  assigning to 'mrb_int' from incompatible type 'sp_RbVal'      → issue 14
  1  initializing 'sp_RbVal' with incompatible type 'const char *' → expand_hash_delete
  1  returning 'sp_RbVal' from a function returning 'sp_PolyArray *'  → unfiled
```

Every one is the same shape: a boxed `sp_RbVal` assigned to an unboxed slot, with no conversion emitted.

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

**Drafted, not yet filed:**

| Draft | Bug |
|---|---|
| `issues/11-…` | A forwarded block's callee resolves to the first same-named method — the #3783 follow-up, with a root cause and a patch in `issues/11-ambiguous-forward-callee.patch` |
| `issues/12-…` | Top-level `extend` of a module does not make its methods callable (top-level `include` works — the sibling of #3775) |
| `issues/14-…` | Destructuring into a method's own parameters from a polymorphic expression emits invalid C — 22 of the library's C errors |
| `issues/13-…` | An implicit-receiver call to an `alias_method` singleton is unsupported from an extended module (the explicit-receiver form works, so #3776's fix holds) |

### Two workarounds with no reproducer yet

**Read the failing line before writing a probe.** The first pass at these three wrote one plausible minimal shape each, all three passed, and the conclusion drawn — "these can't be reduced" — was wrong. Opening the assembled subset at the line the compiler names, and asking what the probe had dropped, reproduced `expand_massign` on the next try. It is now issue 14. The failing line is free information; guessing at shapes is not.

Two still resist, after two hypotheses each. Both are provably needed — remove the transform and the library breaks — and for both the exact construct and diagnostic are known, so what is missing is only the small form:

| Workaround | Failing line | Diagnostic | Shapes tried that pass |
|---|---|---|---|
| `bypass_window_class_methods` | `span = Window.viewport_width` | `unsupported call: (CallNode 'viewport_width') recv=ConstantReadNode/ty48` | the class method alone; plus an `attr_reader` of the same name on instances |
| `expand_hash_delete` | `pad = @gamepads_by_id.delete(id)` | `passing 'sp_RbVal' to parameter of incompatible type 'const char *'` — i.e. it bound to `String#delete` | the ivar assigned in `initialize`; the ivar assigned inside a module body |

Being unable to reduce one is not a reason to sit on it forever. Each has a runnable failing program (the assembled subset), an exact oracle, and a named construct, which is enough for a maintainer holding the compiler source. Reduce first, but file rather than let them block the port indefinitely.

`tools/reduce_oracle_build.sh` is the oracle for both — they are compile failures, so neither the crash oracle nor the diff one fits. Pin `EXPECT` to the diagnostic above so the reducer cannot wander onto a different error.

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

Spinel moves fast, so every workaround here is provisional. **Last re-checked against `20a06d01` on 2026-08-10.** That pass dropped three more rows, which is the whole point of keeping this table. After a `git fetch` in the Spinel checkout, re-check and delete any row that passes. **Do not let these calcify into permanent Ruby 2D design.**

One caution learned the hard way, and confirmed again in this pass: a probe passing in isolation does **not** mean the workaround can be dropped. `positional_callbacks` guards a bug whose own filed reproducer passes today while the library shape it was filed for still fails. Re-check by removing the transform and rebuilding, never by running the probe alone.

Drop one by name and rebuild:

```sh
SPINEL_SKIP=expand_hash_delete ruby spinel/tools/build_subset.rb
SPINEL_SKIP=all ruby spinel/tools/build_subset.rb        # what is still needed at all
```

Names are the `spinel_*` functions in `cli/spinel.rb` minus the prefix. Compile the result and run it — a transform that is no longer needed compiles to zero errors *and* still matches CRuby line for line. Both halves matter twice over: dropping `disable_class_pattern` compiles clean and then fails at run time, and dropping `positional_callbacks` compiles clean, runs, and still prints `SUBSET OK` — with one earlier line wrong.

`scratch/recheck_workarounds.rb` automates the sweep: it drops each transform in turn, rebuilds, compiles, runs, and diffs against CRuby. Recreate it from this description if it has been cleaned away; it takes a few minutes and answers the whole table at once.

**Still needed, re-checked against `20a06d01` (2026-08-10):**

| Workaround | Why it is still there |
|---|---|
| `bypass_window_class_methods` | `Window.viewport_width` — a class method reached through `extend ClassMethods` — is an unsupported call on a constant receiver |
| `dsl_shims` | `extend Ruby2D::DSL` at top level, then calling `update`, is an unsupported call |
| `window_guards` | `shown?` with an implicit receiver does not resolve |
| `expand_hash_delete` | `Hash#delete`'s result assigns `sp_RbVal` to an `mrb_int` |
| `expand_massign` | Multiple assignment emits the same `sp_RbVal`/`mrb_int` mismatch |
| `positional_callbacks` | A forwarded block stored in an ivar loses its captured locals — [#3783](https://github.com/matz/spinel/issues/3783) is **closed and its reproducer passes**, but the library shape still fails. See [#3783 is closed and still broken for us](#3783-is-closed-and-still-broken-for-us--root-cause-and-patch-2026-08-10) |
| `web_predicate` | `Ruby2D.web?` is registered from C, so it is absent under `RUBY2D_NO_RUBY` — not a compiler issue |
| `disable_class_pattern` | An AOT gap, not a bug — see [Deliberate feature gaps](#deliberate-feature-gaps-on-the-spinel-target) |
| `ffi_func` type arrays spelled out instead of `[:double]*6` | Declare an `ffi_func` with a computed type array |
| `emcc` shim rewriting `-Wl,-dead_strip` → `-Wl,--gc-sections` | `spinel hello.rb --cc=emcc` against a wasm-built runtime |

**Dropped on 2026-08-10**, once #3771-#3777 landed: `expand_renderable` (`attr_*`/`alias` in a module body now reach the including class) and `expand_or_return` (`return` in expression position is accepted).

**Dropped later the same day**, once #3782-#3784 landed and the whole table was swept:

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
    line 12  on      input events — event dispatch needs a runtime `send`
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
- [ ] Run an existing example unmodified — needs the four scalar shapes above, and input, which is blocked on the runtime `send` in `on`.
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

## Working artifacts

Everything from the research — the Spinel clone and build, the ~34 language probes, the Step 0 harness (concatenator, line-mapper, patch script), the SDL3 window test, the wasm build, and the benchmark — lives in a **session-scoped scratchpad and is disposable**. Nothing in this repo depends on it. The sections above are written so each result can be reproduced from a clean checkout; re-clone Spinel and rebuild rather than hunting for those files.

The one piece worth recreating early is the Step 0 harness, since the checklist leans on it: concatenate the `LIB_FILES` slice into one `.rb`, keep a line-map back to source files (offsets accumulate as `lines + 2` for the `"\n\n"` join), run `spinel -c`, and patch forward one error at a time.
