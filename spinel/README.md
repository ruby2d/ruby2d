# Spinel build path

Research notes and working checklist for compiling Ruby 2D apps with [Spinel](https://github.com/matz/spinel), Matz's Ruby AOT compiler, as an opt-in alternative to the mruby default. Findings are from 2026-08-07 onward on macOS arm64; mruby stays the default for `ruby2d build`. Spinel moves fast, so the commit matters: the initial research ran against `8b029022e663`, the MVP work against `f0f7dc0d7131`, and **everything was last re-verified against `f13e0ada` (2026-08-20)** — see [Upstream pull to `f13e0ada`](#upstream-pull-to-f13e0ada-2026-08-20): two drafts fixed, and `subset`/`demo` red behind a new `-Werror` gate.

## Start here

The rest of this document is a research log in discovery order. This section is the orientation; read it first.

### The goal

**Every program in `examples/` and `test/` builds, runs, and behaves the way it does on mruby.** 55 programs; that is the finish line, and `rake coverage` is the scoreboard.

It is four gates, and a program can pass three of them and still be broken — which is why the count that matters is the last one, not the first:

| Gate | Checked by | Passing |
|---|---|---|
| 1. the preflight accepts it | `rake coverage` | 42 of 55 |
| 2. it builds | `rake cli`, and a real `ruby2d build` | 17 of the first 20 — see [Line and Text](#line-and-text-2026-08-20); the 22 added by [Canvas, Polyline, Triangle and Button](#canvas-polyline-triangle-and-button-2026-08-20) are unswept |
| 3. it draws the right pixels | `rake compare` | nine fixtures byte-identical to mruby; not measured per program |
| 4. it behaves | `rake motion` for animation, `rake input` for input | input reaches every handler kind; of the 8 programs that animate on mruby and build on Spinel, 5 animate on Spinel — `bouncing_balls` is frozen (issue 33), two more do not build |

Read gate 1 as "not refused outright". `nbody.rb` animates, and `bouncing_balls.rb` and `fireworks.rb` render a correct opening frame and then never move ([issue 33](issues/33-float-argument-to-a-stored-proc-truncated-to-integer-zero.md)). **Input works as of 2026-08-20**: keys, mouse, scroll, close, window-level and per-object, filtered or not — `rake input` injects all of them into a built app and checks every handler fires in order. See [Input reaches the app](#input-reaches-the-app-2026-08-20). 49 of the 55 programs register an `on` handler, so this was the widest gap; what remains on gate 4 is the animation freeze.

`rake coverage` also ranks what to add next by how many programs each feature unblocks, greedily rather than by raw appearances: from 42 today, `Image` first at +3, then `Ellipse` +2, `Audio`, `Sprite`, `SpriteSheet`, `Polygon`, `Tileset`, `BitmapText`, and the `Window` subclass pattern last. That ranking is about breadth only. It says nothing about cost — `Ellipse` and `Polygon` are geometry on proven patterns, `Image` and `Sprite` are textures behind a handle like `Text` and `Canvas` — and nothing about gates 3 and 4.

### Status

**The feature is wired: `ruby2d build --spinel app.rb` compiles an ordinary Ruby 2D script to a standalone 5.2 MB binary.** No hand-run scripts, no paths to set — get the compiler with `ruby2d setup --spinel`, then build. The app goes through `lib/`'s own scene graph into the real `R2D_*` core, with Ruby owning the frame loop. See [The CLI](#the-cli-ruby2d-build---spinel-2026-08-10).

What's left is coverage, not plumbing: the target draws `Square`, `Rectangle`, `Quad`, `Triangle`, `Circle`, `Line`, `Polyline`, `Text`, `Canvas` and `Button`. The shapes draw **filled and stroked**, single-color or per-vertex, lines solid, dashed and gradient, text in any bundled or system font with styles, and every canvas operation — each of which needed its own fixture before it could be trusted — see [Lessons](#lessons). An app using anything more stops before compiling with a message naming it — see [Preflight](#preflight).

**Real example programs build and run, unmodified**, on a stock compiler:

```sh
ruby2d build --spinel examples/nbody.rb && ruby2d launch --native
```

`spinel/square.rb` — USAGE.md's opening example, verbatim — was the target this branch aimed at and was deleted on 2026-08-13, once `examples/` cleared the same bar. Getting it to build needed a patched Spinel for one day: any `set` call omitting `background:` passed a nil key to a String-keyed hash and segfaulted before the first frame. [#3790](https://github.com/matz/spinel/issues/3790) fixed that in `fcaf3fcc`.

**`spinel/examples/` holds three scripts that run on all three engines unmodified** — `fountain.rb`, a sweeping emitter spraying bouncing, recycling balls; `balls.rb`, the fixed-workload benchmark scene; and `mandelbrot.rb`, 30,000 squares computed band by band and zooming itself. See [The three examples](#the-three-examples-and-what-porting-them-cost-2026-08-12).

**And it is fast: 3.5× mruby and 2.3× CRuby** on the same scene's Ruby work, via `rake fps`. Wall-clock fps cannot show this — every engine ties at the display's refresh rate — see [How fast is it, really](#how-fast-is-it-really-2026-08-12).

**Per-vertex colors work, and took two fixes to get there**. `rake compare` now builds a gradient fixture on both engines and gets byte-identical output.

**The `lib/` blocker is gone.** All seven of [#3771-#3777](https://github.com/matz/spinel/issues?q=%22porting+Ruby+2D%22+in%3Abody) are fixed upstream, including #3773, and `verify_issues.rb` confirms all seven independently. The square-only slice now compiles to zero C errors and runs end to end: it constructs a `Square`, registers it, dispatches through the scene graph, and prints `SUBSET OK`. Two workarounds were deleted as a result.

**Thirty issues are filed and every one of them is closed** ([#3771-#3912](https://github.com/matz/spinel/issues?q=%22porting+Ruby+2D%22+in%3Abody)). At `f13e0ada` `verify_issues.rb` reports 32 fixed, 20 reproduce, 3 parked: the twenty reproducing are drafts 33, 34 and 35, 36-42 and 44 from the differential survey, 46 and 47 from the 2026-08-20 upstream pull, 48 and 49 from wiring input the same day, 51 and 52 from the first motion sweep over 20 programs, and 53, 54 and 55 from `Canvas` and `Button`; the third parked is draft 50, which reproduces only in the assembled library. None is filed; the two parked are draft 18, filed as #3804 but not machine-checkable, and draft 30, which has no single reproducer. Draft 24's residue — the one that needed reading by hand — was reduced, filed as [#3911](https://github.com/matz/spinel/issues/3911), and is fixed.

**Three workarounds were dropped on 2026-08-13 and a fourth was dropped and put straight back** — see [Three workarounds dropped](#three-workarounds-dropped-and-one-that-could-not-be-2026-08-13). Two compiler bugs still hold a transform each: `dsl_shims` ([#3803](https://github.com/matz/spinel/issues/3803), fixed upstream with an unreduced residue) and `block_param_capture` (drafted as issue 34, unfiled). `rake sweep` answers whether a transform can go — but only for the code its fixture reaches, which is how `block_param_capture` was wrongly dropped and broke every app using `on`. See [Lessons](#lessons).

**What stands between here and zero workarounds is a finite, known list.** [`spinel-doctor`](#what-blocks-a-clean-build-of-the-whole-library) on the full 37-file library reported exactly one unsupported construct, the event filter's runtime-name `send`, until `lib/` removed it on 2026-08-12; the rest is FFI adapter work. On the compiler side there are now exactly two: `dsl_shims`, filed as [#3803](https://github.com/matz/spinel/issues/3803) and fixed upstream with a residue that has not been reduced, and `block_param_capture`, reduced and drafted as issue 34 but not yet filed. A third, `vocabulary_string_hint`, lived for one day: drafted as issue 45 on 2026-08-20 and found fixed by `f13e0ada` the same afternoon. **Every compiler-bug workaround on this branch has a minimal reproducer.**

Two things remain gaps rather than bugs, both inherent to AOT: the class pattern needs `Module#ancestors` reflection, and `button.rb` needs `define_singleton_method`. Input events are no longer among them: the `send` that made them inherently incompatible is gone, the compiler blockers are cleared, and **a script registering `on` handlers compiles, runs, and receives its events** — `drain_events` is wired over FFI as of 2026-08-20. See [Input reaches the app](#input-reaches-the-app-2026-08-20).

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
cd spinel && rake     # all six checks; or `rake subset`, `rake cli`, …
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
- **input** builds `tools/input_app.rb`, which injects a keypress, a mouse move, a click, a wheel tick and a quit into SDL from inside itself, and checks that all 21 handler lines — window-level, filtered, and per-object — come out in dispatch order. Real input cannot be driven headlessly; injected SDL events travel the identical path.
- **preflight** builds an app using `Circle` and `on` and checks the build refuses it *by name*.
- **issues** re-runs every filed reproducer. A `FIXED` row is the cue to drop the matching workaround with `SPINEL_SKIP=` and rebuild.

Six more sit outside the default set, because they answer roadmap questions rather than regression ones and each takes minutes — except `coverage`, which is a source scan and needs no compiler:

```sh
cd spinel && rake coverage   # how much of examples/ and test/ we accept, and what to add next
cd spinel && rake sweep      # drop each workaround in turn; the one to run after a pull
cd spinel && rake survey     # what blocks a clean build of all 37 files
cd spinel && rake compare    # build all three fixtures on both engines and diff the pixels
cd spinel && rake motion     # build each example on both engines and check the scene still moves
cd spinel && rake fps[name]  # one examples/ scene on CRuby, mruby and Spinel, Ruby-side cost
cd spinel && rake upstream   # pull, rebuild, then re-run issues and sweep
```

**`rake sweep` grades the slice, not the library.** It drops each transform against `build_subset.rb`'s fixture, so it can only see a transform whose code that fixture reaches — which is how `block_param_capture` was cleared as droppable, deleted, and broke every app using `on` while all five checks stayed green. When `sweep` and `survey` disagree, `survey` is grading more code and is the one to believe.

**`rake compare` is the one that answers "does it draw the same thing mruby does".** Every other check grades the Spinel target against itself, and a whole feature can be missing without any of them noticing — which is exactly how strokes stayed inert.

**`cli`, `input` and `preflight` go through the installed gem**, not the working tree — so run `rake` in the repo root first or they test your last install. Everything else reads `lib/` directly.

`spinel/tools/check.rb` is what these run, and it encodes the things that wasted the most time when they were manual:

- **Delete the binary before compiling.** A failed compile leaves the previous one in place, so the old result reads as a fresh success. This produced a wrong conclusion once already.
- **Always `-ferror-limit=0`.** clang stops at 20, so 23 errors reads as 20 and real progress looks like a plateau.
- **Always run the CRuby control.** A Spinel result is only attributable against it.
- **Cap every run.** Two open bugs are infinite loops, and macOS has no `timeout(1)` — `run_capped` in `tools/spinel_env.rb` is what every tool uses.
- **Check pixels, not exit codes.** A window that draws nothing exits cleanly, reports a healthy per-frame draw count, and looks identical to a correct one from every angle except its pixels. Verified by reintroducing the Integer-to-`:float` bug: the check reports `rendered a blank window (1 distinct color)`.

### Resuming

```sh
(cd spinel && rake issues)
gh issue list --repo matz/spinel --state all --search '"porting Ruby 2D" in:body'
```

A `FIXED` row is the cue to re-check the matching workaround with `SPINEL_SKIP=` and rebuild the subset — not to run a standalone probe. Those diverge in both directions: a nested-`include` bug was fixed in isolation while the real library still failed, and #3772's own reproducer passes today while the library shape it was filed for still breaks.

Spinel ships many commits a day, so pull before trusting any measurement here.

### What breaks in ordinary Ruby (2026-08-13)

Everything above is about what `lib/` hits. This is about what an **app** hits: nine bugs found by running plain Ruby programs against both runtimes and diffing, filed as drafts 36-44 and all reproducing at `42649df7`. None came from Ruby 2D's own code, and all of them are reachable from a script a user would write.

Three patterns cover all nine. Worth reading before writing anything for the `--spinel` target, because two of the three are silent.

**Removing from a collection while iterating it backwards.** `reverse_each` reads the array's length once, before the loop, then indexes the live array — so a block that shrinks the receiver is yielded the freed slots as `nil`, or for an array of objects simply runs too many times ([36](issues/36-reverse-each-reads-past-the-live-length-after-the-block-shrinks-the-array.md)). `rfind` has the same contract wrong from the other side, iterating a snapshot ([37](issues/37-rfind-iterates-a-snapshot-so-the-block-cannot-see-the-receiver-shrink.md)). Forward `each` and `find` are correct, and so is `a.reverse.each`. Since walking backwards is *the* reason to reach for `reverse_each` when deleting, this fires on exactly the loop it exists to serve — use `reject!`, or iterate a copy.

**Empty collection literals.** `[].map { |unused| 1 }` does not compile: the block parameter's declaration is pruned while its binding is still emitted, so the generated C assigns to an identifier that was never declared ([43](issues/43-an-unused-block-parameter-over-an-empty-array-literal-emits-invalid-c.md)). It needs both halves — an empty **literal** receiver and a parameter the body never reads — so `[1].map { |unused| }` and `a = []; a.map { |unused| }` are both fine. `map`, `select` and `flat_map` fail; `each` does not. The idiomatic `{ |_| ... }` is the spelling that breaks. This one is loud, but the error names a C identifier rather than the block.

**Argument binding.** A positional Hash silently satisfies a single required keyword and binds it to `{}` ([40](issues/40-a-positional-hash-satisfies-a-single-required-keyword-instead-of-raising.md)) — which matters here because keyword-shaped constructors are most of Ruby 2D's surface. `&value` gets both ends of the coercion backwards: a runtime `nil` raises where Ruby passes no block, and a non-proc is accepted where Ruby raises ([41](issues/41-block-pass-of-a-runtime-nil-raises-and-a-non-proc-is-accepted.md)). `*nil` expands to one `nil` argument instead of none, changing the call's arity ([42](issues/42-splatting-nil-passes-one-nil-argument-instead-of-none.md)).

Two more sit outside the three patterns and are worth knowing on their own: a `fetch`/`delete` fallback block is reduced to its tail expression and hoisted out of its branch, so `h.fetch(k) { |key| [key] }` returns `[nil]` and a side effect in the block runs even when the key *was* found ([39](issues/39-a-conditional-fallback-block-is-reduced-to-its-tail-expression-and-hoisted-out-of-its-branch.md)); and `p` on any object graph with a back-reference **segfaults**, because `inspect` has no cycle detection ([44](issues/44-inspecting-a-self-referential-container-segfaults.md)). The last one has no safe spelling — `to_s` crashes too — and it is the one most likely to be met while debugging something else.

`patches/` holds a suggested fix for three of them. They apply cleanly at `42649df7`; only the fallback-block one has been built and run.

### Where to read next

| If you want | Read |
|---|---|
| What we are aiming at, and how far off it is | [The goal](#the-goal), then `rake coverage` |
| Why this is viable at all | [Why Spinel fits](#why-spinel-fits) |
| What breaks and how it is worked around | [Workarounds to re-check](#workarounds-to-re-check), then `lib/ruby2d/cli/spinel.rb` |
| Why "it runs and draws" is not enough | [Lessons](#lessons) |
| What is filed upstream | [To report upstream](#to-report-upstream) and `issues/` |
| What breaks in an app, not just in `lib/` | [What breaks in ordinary Ruby](#what-breaks-in-ordinary-ruby-2026-08-13) |
| How the CLI is wired | [The CLI](#the-cli-ruby2d-build---spinel-2026-08-10) |
| Why the link order matters, and how the core is built Ruby-free | [Building by hand](#building-by-hand) |
| How to chase a new whole-program bug | [Reducing a whole-program failure](#reducing-a-whole-program-failure) |
| When each piece first worked | [Milestones](#milestones) |

Sections below are dated where it matters. Anything describing a "current" state is current **as of its date**, not necessarily now — the Status section above is the only place kept up to date.

## What's in this directory

Everything worth keeping from the Spinel spike. Nothing here is a final home — it is a holding area for this branch.

| File | What it is |
|---|---|
| `Rakefile` | The checks, kept here rather than in the root Rakefile so this branch merges or disappears as one piece |
| `README.md` | This document: findings, checklist, workarounds, and what to report upstream |
| `issues/` | The upstream bug reports, one file per issue |
| `patches/` | Suggested fixes for three of the drafts, named by issue number. Evidence for a reviewer, not intended commits: each applies cleanly at `42649df7`, and only `39-fallback-block.patch` has been built and run |
| `tools/` | **Checks:** `check.rb` runs the five behind `rake`; `build_subset.rb` assembles the slice with `Ext` stubbed (`SPINEL_SKIP=` drops workarounds); `cli_app.rb`, `gradient_app.rb` and `circle_app.rb` are the fixtures `compare.rb` diffs between mruby and Spinel. **Roadmap:** `coverage.rb` scores the corpus against [the goal](#the-goal); `survey.rb` reports what blocks a clean build of all 37 files; `motion.rb` asks whether a built example still *moves*; `fps.rb` compares Ruby-side frame cost across the three engines. **Upstream:** `upstream.rb` pulls and rebuilds the compiler; `verify_issues.rb` re-runs every reproducer; `sweep.rb` drops each workaround in turn. **Plumbing:** `spinel_env.rb` resolves the compiler and caps runs, `spinel_path.sh` does the same for shell; `build_square.rb` + `link_square.sh` build the `demo` check's binary; `reduce_oracle*.sh` are the oracles for `spinel-reduce` — crashes, silent wrong answers, and compile failures — kept for the contract they encode, though [reading has beaten reducing every time](#reducing-a-whole-program-failure) |
| `scratch/` | Working area for experiments — gitignored, safe to delete |

Experiments go in `scratch/`, which is gitignored: generated sources, object files, built binaries, probe scripts. It survives across sessions, unlike a system temp directory, but nothing there is precious — delete it freely. Anything worth keeping is promoted up a level and committed.

**The Spinel compiler itself stays outside the repo.** It is a large separate git repository that gets rebuilt on every upstream pull, so nesting it here would be awkward and would confuse tooling. Clone it beside this repo as `../spinel`, or point `RUBY2D_SPINEL` at `bin/spinel` — the same resolution order `find_spinel` implements. The recipes below need no path set.

## Why Spinel fits

Spinel parses Ruby with libprism, infers types across the whole program, emits one C file, and invokes the system `cc`. The result is a standalone binary needing only libc and libm. Two pieces of Ruby 2D's existing design carry most of the integration:

**The main loop is already Ruby-owned on CRuby.** Spinel's FFI has no callbacks — C can never call back into Ruby — which would normally rule out an engine whose C layer drives the frame loop. But `Window#show` (`lib/ruby2d/window.rb:442`) already branches: CRuby runs `tick until @close` in Ruby, while mruby and WASM hand the loop to C. Spinel takes the CRuby-shaped path that already exists.

**`ext.c` already separates C primitives from Ruby bindings.** Its header describes "Ruby-callable bindings exposing libruby2d C primitives", and the shape "full-flatten" pattern passes vertices and colors as flat numeric args with nothing stored C-side. That maps onto Spinel FFI directly; the mruby binding layer drops out.

## Milestones

The sections below are a research log in discovery order. The narrative for
these first steps was cut on 2026-08-13, once each had been superseded by
something that shipped; the dates are kept because they are the answer to "how
long did this take" and "when did that stop being true".

| Date | First worked |
|---|---|
| 2026-08-07 | Spinel builds from source; FFI covers all three patterns Ruby 2D needs; a compiled Ruby program opens a real SDL3 window and renders 30 frames from a Ruby-owned loop |
| 2026-08-08 | The real `lib/` compiles — the 25-file subset, 5,439 lines, exit 0 — and a separate hand-written-FFI binary drives the `R2D_*` core at 60fps |
| 2026-08-09 | `lib/` *runs* under Spinel with every `Ext` entry point stubbed: objects construct, register, z-order, mutate, tick and remove |
| 2026-08-10 | `ruby2d build --spinel app.rb` lands — one command, a standalone binary, `lib/`'s own scene graph into the real core |
| 2026-08-11 | `square.rb` — USAGE.md's opening example, verbatim — builds and draws on a stock compiler; strokes and per-vertex colors work |
| 2026-08-12 | `Circle` lands; three scenes run on all three engines; measured at 3.5× mruby and 2.3× CRuby on Ruby-side frame cost |
| 2026-08-13 | Input compiles; `bouncing_balls.rb`, `fireworks.rb` and `nbody.rb` build unmodified; every filed issue closed upstream |

## Lessons

A week of findings comes down to five rules. Each was learned expensively, each
is stated here once, and the rest of this document links here instead of
restating it.

**A closed issue is not a dropped workaround.** `rake issues` asks whether a
small reproducer passes. `rake sweep` asks whether the library still needs the
transform. They have disagreed in both directions five times: #3783 closed with
its reproducer passing while the library still failed, #3787 and #3788 did the
same, `window_guards` became droppable a day late on a pull that named nothing,
and the sweep cleared `block_param_capture` while its reproducer still failed.
Run both. When they disagree, believe the one grading more code — which is
`rake survey`, the only check that compiles all 37 files.

**A check only sees what its fixture reaches.** Three `Ext` entry points
compiled, ran, and drew nothing correct because no fixture exercised them:
`stroke_quad_uniform`, `stroke_quad`, and `draw_quad`, whose adapter took its 24
floats grouped while `Quad#render` passed them interleaved. Then
`block_param_capture` was deleted because the subset's main registered no `on`
handler, and every input-using app stopped building with all five checks green.
Before trusting a green check, ask which lines it actually ran.

**Check pixels, not exit codes.** A window that draws nothing exits cleanly,
reports a healthy per-frame draw count, and is indistinguishable from a correct
one from every angle except its pixels — and a scene whose motion is gone looks
perfect in any single screenshot. `rake compare` diffs pixels against mruby;
`rake motion` diffs frame 5 against frame 60. Both exist because a whole feature
went missing with every other check green.

**Read the failing line; don't guess at shapes.** Every hard reduction here fell
to reading — the line the compiler names, the emitted C (`spinel app.rb -c`), or
Spinel's own commit log — usually in minutes. The guessing that preceded them
cost twenty-one probes on #3786, eleven on #3805, ten on #3802 and five on
#3808, and three times produced the conclusion "this cannot be reduced", which
was wrong every time.

**Absence of a signal is not a good signal.** Three checks written to catch
silent failures each had the bug they were built to catch: `survey.rb` printed
an empty error list when Spinel refused before clang ran, `motion.rb` counted a
failed build as "animates", and `sweep.rb` cleared a transform whose code it
never compiled. All three read as passes.

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

**Input handling still does not work**, because three ordinary compiler bugs sit behind the one that was ours. (All four were fixed upstream on 2026-08-13 — see [Input compiles, and the first example programs build](#input-compiles-and-the-first-example-programs-build-2026-08-13).)

| Bug | Filed | Effect on `on` |
|---|---|---|
| A keywords-only call binds the keyword hash to an optional positional too | [#3808](https://github.com/matz/spinel/issues/3808) | `on(key_down: :escape)` raises "requires either an event symbol or event filters" — `def on(event = nil, **filters, &proc)` is the shape |
| `equal?` between a typed receiver and a poly argument folds to `false` | [#3807](https://github.com/matz/spinel/issues/3807) | gamepad identity filters never match, silently |
| An escaping lambda's parameter inferred as `Integer` | not reduced | `e.matches?` raises `NoMethodError` at the handler |
| A lambda capturing the enclosing block parameter (`Interactive#on`) | not filed | per-object `on` refuses to compile at all |

The refactor was verified rather than assumed: with only the last of those neutralized, `Window#on` compiles and runs, so it is these bugs and not the design that stop it. The preflight therefore still rejects `on`, with its reason updated — the feature is genuinely unavailable, and a silent half-working event system would be worse than a clear refusal.

**Related, and a clean negative result:** the library's three other `equal?` sites are *not* affected by #3807 — `sprite.rb`'s frozen-sentinel default, and the poly-vs-poly comparisons in `quad.rb` and `triangle.rb`. The fold needs a user-class-typed receiver against a poly argument specifically; both operands poly, or a sentinel default, compile and answer correctly. Checked because a silent identity failure in shipped code would be worse than the bug that prompted the look.

## What blocks a clean build of the whole library

```sh
cd spinel && rake survey
```

`tools/survey.rb` assembles all 37 `LIB_FILES` with the compatibility layer off
and reports the complete gap. **A plain build cannot answer this**: Spinel stops
at the first construct it refuses and never reaches the next, so it names one
blocker however many there are — which is why they surfaced one per session for
a week. The survey edits out each known blocker so the one behind it becomes
visible, and its `NEUTRALIZE` table is the catalogue. Add to it when a new
blocker appears; delete an entry when the issue is fixed, and a missing site
raises rather than passing quietly.

Two cautions it taught. **Neutralize an expression, not a line** — blanking whole
lines left `if/elsif/else` unbalanced and produced four parse errors that read as
findings. And **keep the surrounding variables used**: replacing a call with a
bare `true` left a block parameter unused, which changes the capture analysis and
invented a blocker that vanished when both variables were kept.

`spinel-doctor`, in the Spinel checkout's `bin/`, analyses without stopping and
is the other way to ask. Its legs are worth knowing individually:

| Leg | Answers |
|---|---|
| `unsupported` | constructs Spinel refuses outright — the real blockers |
| `unresolved` | calls it cannot resolve, each marked whether CRuby agrees |
| `inference` | every method widened to untyped. **Informational** — widening is not a bug signal, and treating it as one cost an hour on #3786 |
| `requires` | files it could not load |
| `build` | does the C compile |
| `behavior` | runs it and diffs against CRuby. Opt in with `--only behavior`; reports *that* output differs, not where |

`behavior` is a ready-made differential tester. Pointed at a corpus rather than
one program — every `USAGE.md` snippet, say, which the project already
guarantees runs as written — it would find runtime divergences in bulk the way
the static legs find compile ones. That is how drafts 36-44 were found.

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
| [#3805](https://github.com/matz/spinel/issues/3805) | `issues/17-…` | A user class defining `length` diverts `empty?` on a poly receiver away from the builtin lowering into a dispatch keyed on `empty?`, which nothing owns, so the call becomes an unconditional raise | `Color::Set#empty?` in `lib/`, which is a real method rather than a workaround |
| [#3806](https://github.com/matz/spinel/issues/3806) | `issues/22-…` | `delete` on a poly receiver is lowered to `String#delete`, stringifying the receiver — silently wrong with a String argument, a C compile error otherwise | `expand_hash_delete`, the last workaround to get a reproducer |
| [#3807](https://github.com/matz/spinel/issues/3807) | `issues/23-…` | `equal?` between a typed receiver and a poly argument is folded to the constant `false`, both operands discarded | none — found while removing the event-filter `send` |
| [#3808](https://github.com/matz/spinel/issues/3808) | `issues/24-…` | A keywords-only call binds the keyword hash to an optional positional parameter as well as to `**kwargs` | none — same |
| [#3809](https://github.com/matz/spinel/issues/3809) | `issues/25-…` | `obj.attr += value` is refused when the writer is a hand-written `def` rather than an `attr_writer`; longhand works | none — blocks `s.x += b.vx * dt`, the shape any physics loop has |
| [#3810](https://github.com/matz/spinel/issues/3810) | `issues/26-…` | A String-keyed Hash looked up with a poly key reads `.v.s` with no tag check and **segfaults** — the residue of #3790's `nil` key | none — crashes any app using a numeric `[r, g, b, a]` color |

The duplicate search before filing turned up one close relative worth citing rather than a duplicate: [#2856](https://github.com/matz/spinel/issues/2856), a class method added by *reopening* a class not being registered. Its reproduction passes at `83d1315d`, so a `def` in a reopened body registers while an `extend` does not — that contrast is in #3802 because it bounds the search.

**Not filed** — five, for different reasons:

| Draft | Bug | Status |
|---|---|---|
| `issues/20-…` | A top-level `extend` shadows a class's own same-named method, **silently** — `Window#update` never runs | **Fixed upstream 2026-08-12 before it could be filed**, by `80a3beb2`. Do not file; kept as the record, and kept in `verify_issues.rb` because upstream has no test for this shape |
| `issues/30-…` | **Design, not a bug.** Method resolution is re-derived at each emission site, and the boxed write path never consults the method table — the mechanism behind #3805, #3806 and drafts 27 and 29 | **Drafted 2026-08-13, awaiting review.** Written after reading `src/codegen_stmt.c` and `src/codegen_call.c`; parked in `verify_issues.rb` as research notes, since a design issue has no single reproducer |
| `issues/33-…` | A `Float` argument to a stored proc arrives as Integer `0` when the parameter is read inside a nested block and the program contains a `Struct` — **silently**, so `dt`-driven motion stops | **Drafted 2026-08-13, awaiting review.** Found by frame-capped screenshots of two frozen example programs; verified reproducing at `e05feeb9` |
| `issues/34-…` | A proc capturing a method's `&blk` is refused when the method comes from an **included** module; the same method in a class, or via `extend`, compiles | **Drafted 2026-08-13, awaiting review.** Reduced from the `Interactive#on` blocker to twelve lines. [#3912](https://github.com/matz/spinel/issues/3912) cleared the shape the compiled *slice* has, so `spinel_block_param_capture` was dropped — but the reproducer still fails and **the full 37-file library still refuses `interactive.rb:41`**, so this one blocks the road to a complete build |
| `issues/35-…` | `yield` inside a lambda raises `LocalJumpError` instead of calling the method's block | **Drafted 2026-08-13, awaiting review.** Found mapping 34's boundary; independent of where the method lives |

**Nine more from a differential survey** — drafts 36-44, all reproducing at `42649df7`, none filed. These did not come from `lib/`: they came from running plain Ruby programs against both runtimes and diffing, so each is reachable from app code rather than from this port. See [What breaks in ordinary Ruby](#what-breaks-in-ordinary-ruby-2026-08-13) for the three patterns they fall into.

| Draft | Bug | Status |
|---|---|---|
| `issues/36-…` | `reverse_each` hoists the receiver's length before the loop, so a block that shrinks the array is yielded the freed slots as `nil` — or, for an array of objects, just runs too many times | **Drafted 2026-08-13.** Cause confirmed at `src/codegen_iter.c:2871`: the forward arm re-reads the length each iteration, the reverse arm does not. Patch in `patches/`, not yet built |
| `issues/37-…` | `rfind` desugars to `reverse.find`, iterating a snapshot, so a block that empties the receiver still finds a match | **Drafted 2026-08-13.** The mirror of 36 — `src/analyze.c:5033`. Worth filing alongside it, since a fix for one leaves the two reverse iterators disagreeing |
| `issues/38-…` | A key added during `Hash#each` is inserted before the guard raises, so a rescued hash keeps the key CRuby refused | **Drafted 2026-08-13.** The guard sits in the loop's advance clause (`src/codegen_iter.c:2161`), where #3782 put it — a detector, not a guard |
| `issues/39-…` | A `fetch`/`delete` fallback block is reduced to its tail expression and hoisted out of its branch: the parameter reads unbound, leading statements vanish, and the block runs on the success path | **Drafted 2026-08-13.** One mechanism across four methods, shown in the emitted C. Patch in `patches/`, built and run — but written for `delete` only, so it may not reach the `fetch` half |
| `issues/40-…` | A positional Hash silently satisfies a *single* required keyword, binding it to `{}` | **Drafted 2026-08-13.** Adjacent to #3808 and #3911 but not covered by either; two required keywords raise correctly, which bounds it |
| `issues/41-…` | `&value` gets both ends of the coercion wrong: a runtime `nil` raises, a non-proc is accepted as no block | **Drafted 2026-08-13.** The literal `&nil` is correct, so it is the runtime path that inverts |
| `issues/42-…` | `*nil` expands to one `nil` argument instead of none, changing the call's arity | **Drafted 2026-08-13.** `*[]` is correct, so it is `nil` specifically that is passed through as a value |
| `issues/43-…` | An unused block parameter over an **empty array literal** emits invalid C — the declaration is pruned, the binding is not | **Drafted 2026-08-13.** Needs both halves; `map`/`select`/`flat_map` fail and `each` does not. Patch in `patches/`, not yet built |
| `issues/44-…` | `inspect` has no cycle detection, so printing any object graph with a back-reference **segfaults** | **Drafted 2026-08-13.** `EXC_BAD_ACCESS (code=2)` — stack exhaustion, not a bad pointer. No safe spelling: `to_s` crashes too |

**Thirty of the forty-four drafts are filed** — every one except 20, which upstream fixed first, 30, 33, 34 and 35, which are waiting on review, and 36-44, which came later from the differential survey. At `e05feeb9` `verify_issues.rb` reports 24 fixed, 8 reproduce, 2 parked, 1 to read by hand: the eight reproducing are drafts 27, 28, 29, 31 and 32 — all filed, none fixed yet — plus the three new ones; the two parked are draft 18, filed as #3804 but not machine-checkable, and draft 30, which has no single reproducer; the one to read by hand is draft 24, whose double binding is fixed with a residue. The earlier five were filed on 2026-08-11 against `489cbde7` and fixed the same day, each closed by a commit citing its number:

| Issue | Draft | Bug | Fixed by | Workaround |
|---|---|---|---|---|
| [#3786](https://github.com/matz/spinel/issues/3786) | `issues/11-…` | A forwarded block's callee resolves to the first same-named method — the #3783 follow-up, root-caused and patched here | `1c168009` | `positional_callbacks` **dropped** |
| [#3787](https://github.com/matz/spinel/issues/3787) | `issues/12-…` | Top-level `extend` of a module does not make its methods callable (top-level `include` works — the sibling of #3775) | `e40fe331` | `dsl_shims` still needed |
| [#3788](https://github.com/matz/spinel/issues/3788) | `issues/13-…` | An implicit-receiver call to an `alias_method` singleton is unsupported from an extended module (the explicit-receiver form works, so #3776's fix holds) | `329050a6` | `window_guards` still needed |
| [#3789](https://github.com/matz/spinel/issues/3789) | `issues/15-…` | Reading an ivar from an `extend`-provided method emits invalid C — found while probing 13 | `bebef965` | none — the library's extended class methods hold no state |
| [#3790](https://github.com/matz/spinel/issues/3790) | `issues/16-…` | A nil key looked up in a String-keyed `Hash` segfaults — `sp_str_hash` reads the tag byte at `s[-1]` with no NULL check | `fcaf3fcc` | none — it blocked `square.rb`, which built unpatched from that day on |

The upstream fix for #3790 is our patch with a better constant: the guard returns the FNV offset basis rather than 0, so a nil key lands where the empty-string hash would rather than in bucket 0. **Two of the five cleared their reproducer without clearing the library**, which is the #3783 pattern for the third and fourth time.

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

**Filed and closed the same day.** #3782-#3784 were filed on 2026-08-10 against `c70ed332`, re-verified against that commit first — including each draft's "Additional Findings" contrasts, which `verify_issues.rb` does not cover because it only runs the main reproducer. All three closed within hours. #3783's fix does **not** cover the shape Ruby 2D uses; it was root-caused and patched here, and the residue is the first entry in [Lessons](#lessons).

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

- **`lib/`** — when the change is defensible Ruby on its own merits, it goes in the library, the way mruby accommodations already do. `@key_names = {}` instead of `[]` was the model (the cache itself is gone now that key events carry name symbols): scancodes are sparse, so a Hash was the better structure anyway, and an empty Array literal gives an AOT compiler no element type to infer from. These changes stay correct under CRuby and mruby and need no build-time machinery.
- **`cli/spinel.rb`** — only when the change would make `lib/` worse to read, or is pure build-time synthesis (the DSL top-level shims, `Ruby2D.web?`). Each transform asserts it still matches, so drift fails the build.

Prefer `lib/`. The transforms are string matching against library source and are the fragile half.

**Stopping rule:** grind through codegen failures, flagging each as an upstream candidate — but if one turns out to be a user-facing feature or a DSL form Ruby 2D cannot express under Spinel, stop and file upstream rather than degrade the public API.

## Workarounds to re-check

Spinel moves fast, so every workaround here is provisional. **Last re-checked against `42649df7` on 2026-08-13, which dropped three of seven** — `bypass_window_class_methods`, `window_guards` and `expand_hash_delete`, leaving four of which two are compiler bugs. A fourth, `block_param_capture`, swept as droppable and was not: see [Three workarounds dropped](#three-workarounds-dropped-and-one-that-could-not-be-2026-08-13). The `83d1315d` pass before it dropped nothing, the `b51c880d` one dropped nothing either, the `9678c99b` one dropped `positional_callbacks`, the `489cbde7` one before that dropped `expand_massign`, and the one before that dropped three rows, which is the whole point of keeping this table. After a `git fetch` in the Spinel checkout, re-check and delete any row that passes. **Do not let these calcify into permanent Ruby 2D design.**

One caution learned the hard way: a probe passing in isolation does **not** mean the workaround can be dropped. `dsl_shims` guards a bug that is fixed upstream and whose filed reproducer passes, and it is still needed — as `window_guards` was for a day after #3802 closed, before a later pull cleared it without naming it. Re-check by removing the transform and rebuilding, never by running the probe alone.

Drop one by name and rebuild:

```sh
SPINEL_SKIP=dsl_shims ruby spinel/tools/build_subset.rb
SPINEL_SKIP=all ruby spinel/tools/build_subset.rb        # what is still needed at all
```

Names are the `spinel_*` functions in `cli/spinel.rb` minus the prefix. Compile the result and run it — a transform that is no longer needed compiles to zero errors *and* still matches CRuby line for line. Both halves matter twice over: dropping `disable_class_pattern` compiles clean and then fails at run time, and `positional_callbacks`, while it was still needed, compiled clean, ran, and still printed `SUBSET OK` — with one earlier line wrong.

`scratch/recheck_workarounds.rb` automates the sweep: it drops each transform in turn, rebuilds, compiles, runs, and diffs against CRuby. Recreate it from this description if it has been cleaned away; it takes a few minutes and answers the whole table at once.

**Still needed, re-checked against `42649df7` (2026-08-13):**

| Workaround | Why it is still there |
|---|---|
| `block_param_capture` | The lambda in `Interactive#on`'s filtered form captures the method's block parameter, and the method arrives through an `include`. Refused with `uncaptured outer variable 'proc' (later slice)`. Reduced as issue 34, **not yet filed**. Dropped on a sweep result on 2026-08-13 and restored the same day — it is the reason `build_subset.rb`'s fixture now registers an `on` handler |
| `canvas_undef_color` | `Canvas` removes `Renderable`'s `color` accessors with `undef_method`; whole-program AOT has no method table to undefine from and refuses the call. Dropping the line loses nothing on this target. An AOT gap, not a bug — see [Deliberate feature gaps](#deliberate-feature-gaps-on-the-spinel-target) |
| `button_visual_hooks` | `Button` wraps a visual's alignment resolver with `define_singleton_method` and reads its anchor offset with `send`; both are reflection. On this target a Button wrapping a visual keeps its label on the visual's top-left anchor and ignores a later symbolic `align:`. No program passes a visual or `align:` to a Button. An AOT gap, not a bug |
| `hash_delete_if` | `@pressed_objects.delete_if` in `ObjectEventDispatch#cleanup_interaction_state` raises `undefined method 'delete_if' for an instance of Hash` in the assembled library and nowhere smaller; the transform iterates a snapshot of the keys and deletes by key. Draft 50, research notes. Added 2026-08-20 when `snake.rb` first ran. **`rake sweep` cannot grade it** until the `-Werror` gate clears; re-check with `scratch/input/state_harness.rb` |
| `dsl_shims` | `extend Ruby2D::DSL` at top level: a method declaring `&block` is called with the block dropped. [#3787](https://github.com/matz/spinel/issues/3787) is closed and its reproducer passes; the residue is filed as [#3803](https://github.com/matz/spinel/issues/3803), which is *also* closed with its reproducer passing, and the transform is still load-bearing. It is the only compiler bug left in this table, and the only row whose residue has never been reduced |
| `web_predicate` | `Ruby2D.web?` is registered from C, so it is absent under `RUBY2D_NO_RUBY` — not a compiler issue |
| `disable_class_pattern` | An AOT gap, not a bug — see [Deliberate feature gaps](#deliberate-feature-gaps-on-the-spinel-target) |
| `ffi_func` type arrays spelled out instead of `[:double]*6` | The computed form is dropped with no diagnostic — filed as [#3804](https://github.com/matz/spinel/issues/3804), now closed. **Not covered by `rake sweep`**, which only sees the `spinel_*` transforms, so this row is unverified since it was written |
| `emcc` shim rewriting `-Wl,-dead_strip` → `-Wl,--gc-sections` | `spinel hello.rb --cc=emcc` against a wasm-built runtime |

**Dropped on 2026-08-20**, at `f13e0ada`: `vocabulary_string_hint`, added that morning for draft 45 (`Vocabulary#validate!`'s String-spelling hint made every Symbol lookup miss) and fixed upstream before the day was out. Verified by building the slice past the `-Werror` gate with `--cc='cc -w'` and matching CRuby with the fixture's `on(click: :left)` exercising the lookup.

**Dropped on 2026-08-13**, at `42649df7`, after the pull that closed the last six filed issues:

| Dropped | Was working around | Filed as |
|---|---|---|
| `bypass_window_class_methods` | `Window.viewport_width` — a class method reached through `extend ClassMethods` — unresolvable on a constant receiver, because the `extend` sits in a different `class Window` body from the module | [#3802](https://github.com/matz/spinel/issues/3802) |
| `window_guards` | the same bug reaching `shown?` and `render_ready_check`, which the bypass could not cover because neither is a `DSL.window` delegation | [#3802](https://github.com/matz/spinel/issues/3802) |
| `expand_hash_delete` | `@gamepads_by_id.delete(id)` lowered to `String#delete` with the receiver stringified by `sp_poly_to_s` | [#3806](https://github.com/matz/spinel/issues/3806) |

Verified four ways before deleting: `rake sweep` cleared each one individually, then the 867-example suite, the five checks, and `rake compare` — all three fixtures byte-identical to mruby, gradient included. **All four of those passed for `block_param_capture` too, and it was still wrong.**

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

## WebAssembly

Spinel documents no wasm support; the only "wasm" mention in the repo is a note about a CLI name collision with Fermyon's `spin`. It nonetheless works, and the blockers are small:

1. Its runtime ships as a native archive. **All 25 runtime modules recompiled with `emcc` with zero source changes and zero failures.**
2. It emits `-Wl,-dead_strip` based on *host* OS (`src/main.c:585`), which `wasm-ld` rejects. Swapping to `--gc-sections` fixes it (`RT_MEMBERS` in Spinel's `Makefile` is the authoritative runtime module list if the rebuild drifts) — a genuine host-vs-target bug worth reporting upstream.

With those two, `hello.rb` built to a 132 KB wasm module running Ruby classes and loops under node. Wiring this to SDL3 and Emscripten is a separate lift and is explicitly out of MVP scope, but the path is real.

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

**`Ext.window_show(self)` is a pass-self call.** The CRuby path hands the `Window` object to C, which reads its ivars. Spinel FFI cannot do that — there are no callbacks and no way to read a Ruby object from C. This is why `R2D_ShowWindow` takes thirteen flattened parameters (title, size, flags, viewport, render and scale mode, icon): the adapter reads the ivars **in Ruby** and passes them positionally. Any other pass-self call needs the same treatment, which is the pattern that will bite when images, text, and canvas are wired up.

**`RUBY_ENGINE` is `"spinel"`, so `Window#show` takes the wrong branch.** The condition is `RUBY_ENGINE == 'ruby'`, so Spinel falls through to the mruby/WASM path where *C owns the loop* — precisely what FFI cannot support. Spinel needs the CRuby-shaped branch, where Ruby runs `tick until @close`.

The honest fix is not a string comparison against a third engine name: the condition is really asking "does Ruby own the main loop?". Until the build path exists, `cli/spinel.rb` rewrites it; when the feature lands, `window.rb` should ask that question directly.

## The three examples, and what porting them cost (2026-08-12)

`spinel/examples/` holds `fountain.rb` (a sweeping emitter spraying bouncing,
recycling balls), `balls.rb` (the fixed-workload benchmark scene) and
`mandelbrot.rb` (30,000 squares computed band by band, zooming itself). All
three run on CRuby, mruby and Spinel unmodified. None takes input, which is not
a stylistic choice — a demo needing input would demo nothing until event
delivery exists.

**`Canvas` cannot be reached from this target at all, and that is the most
useful thing porting them turned up.** Not a missing binding: *every* entry
point in `canvas.c` takes the Canvas Ruby object as `argv[0]`, reads its ivars,
and stores the `R2D_Canvas *` back inside it with `obj_set_struct`. There is no
`R2D_Canvas *` API underneath to call. Supporting it means splitting that layer
the way `window.c` and `shapes.c` already are — a Ruby-free core plus a thin
binding — and then finding a way to hand it rectangles, since `fill_rectangles`
takes an array and the FFI passes scalars only. **`Text` is the same shape.**
Both are real work in `ext/`, on code all three engines share, and both sit
near the top of what [the goal](#the-goal) needs next.

`mandelbrot.rb` uses a `Square` per block instead, which needs none of that:
the grid is built once and only recolored, so nothing is created or removed
after startup.

Two bugs came out of the porting: the `update` block's `dt` arriving as Integer
`0` when a nested block reads it, which froze `fountain.rb` at full frame rate
with no diagnostic ([issue 33](issues/33-float-argument-to-a-stored-proc-truncated-to-integer-zero.md)),
and a stored block capturing an array of objects being refused, which shaped
`mandelbrot.rb`'s use of constants over top-level arrays ([#3908](https://github.com/matz/spinel/issues/3908)).

**One measurement lesson worth keeping.** A benchmark that blends a 30×
component with a 3.5× one reports neither: `mandelbrot.rb` first measured 3.9×
against CRuby, and splitting the frame showed escape-time arithmetic at 9.8×
and scene dispatch at a flat 3.5×. Scene dispatch is 3.2-3.5× at every stage of
the object-render path, so there is no Spinel-specific pathology to go fix, and
the ratio a scene reports is decided entirely by its mix. Tuning the example's
band rows — which trades only against how fast a view streams in, not against
the picture — took the headline from 4.9× to 15.8× without changing a pixel.
Before tuning for a ratio, measure which part of the frame it comes from, and
pin the workload first: with the example's random zoom target still in place,
two runs of identical source came out 37% apart.

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

## Building by hand

**`ruby2d build --spinel` does all of this now** — `spinel_build_core` and `spinel_link_libs` in `cli/spinel.rb` are this recipe in code. It is kept because the two things it had to get right are not obvious from the code, and someone debugging a link failure will want them: which translation units make a Ruby-free core, and the `--link` ordering that resolves. The program it was written for, `spinel/bouncing_balls.rb`, was deleted on 2026-08-13 once `examples/bouncing_balls.rb` built through `lib/` on the real path.

A Ruby-free `libruby2d_core.a` is built from the tree with `RUBY2D_NO_RUBY`, which compiles out the binding layer and leaves the SDL3-touching core (~70 `R2D_*` symbols):

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

spinel app.rb --cc="$FW" \
  --link "$PWD/libruby2d_core.a" \
  --link "$LIBS/libSDL3_ttf.a"   --link "$LIBS/libSDL3_image.a" \
  --link "$LIBS/libSDL3_mixer.a" --link "$LIBS/libSDL3.a" \
  -o app
```

Give the program a frame cap and a screenshot argument — `./app 150 shot.png` to stop after 150 frames and write one — which is how a build gets checked without a human watching a window.

### Compiler flags

`-c` emits C without linking, `-S` prints it to stdout, `-E` compiles and runs,
`--link` adds an archive, `--cc` overrides the compiler, `-I` adds a feature root
for `require`. `--cc` is used verbatim as the command prefix, so extra flags ride
along: `--cc="cc -L/path -framework Cocoa"`.

**`spinel app.rb -c` is the debugging tool that matters** — reading the emitted C
is what cracked the hardest bugs here. Driving the linker yourself then means
supplying Spinel's runtime too, or the link fails on undefined `sp_*` symbols:
add `-I<spinel>/lib` and `<spinel>/lib/libspinel_rt.a`. Prefer `--link` and let
Spinel drive `cc`.

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

## Input compiles, and the first example programs build (2026-08-13)

**It reduced, to twelve lines.** The missing ingredient was none of the ones tried: it is `include`. A method that takes `&blk` and captures it in a proc compiles in a class and compiles in a module used with `extend`, and is refused in a module mixed in with `include` — no intervening block, no other capture, nothing else required. `Interactive` is included into `Renderable`, which is why the library hit it and every standalone attempt missed it. Drafted as [issue 34](issues/34-proc-capturing-a-block-parameter-refused-in-an-included-module.md).

Reading the refusal's own source is what turned it: `src/analyze.c:743` skips any name the *immediately* enclosing scope doesn't hold, and `src/codegen.c:3335` then refuses what was never celled. That pointed at scope resolution rather than at proc shape, and `include`-versus-`extend` fell out of it in one step. The five earlier reduction attempts were all guesses at the shape of the proc.

Aliasing the block parameter to a plain local first is enough to sidestep it, so `spinel_block_param_capture` does that in the compat layer and **the preflight no longer rejects `on`**. Of the 55 programs in `examples/` and `test/`, 49 were rejected for that word alone. It was briefly deleted the next morning on a sweep result and restored within the hour — see [Three workarounds dropped](#three-workarounds-dropped-and-one-that-could-not-be-2026-08-13).

**`examples/nbody.rb`, `examples/fireworks.rb` and `examples/bouncing_balls.rb` — real example programs, unmodified — now build and run.** They are the three the survey named as needing nothing else; the next tranche needs `Line` and `Text`, and 14 of the 55 come down to `on` plus the remaining pure-geometry shapes. Event *delivery* is still ours: handlers register and never fire, because `drain_events` still returns `nil`.

## Two of the three froze, and a check that would have caught it (2026-08-13)

Building is not behaving, and the three examples proved it immediately. A frame-capped screenshot at frame 5 and frame 60 shows `nbody` animating on both engines and **`fireworks` and `bouncing_balls` frozen on Spinel** — correct opening frame, correct colors, full frame rate, nothing moving. Beside mruby's run of the same program the divergence is unmissable; from Spinel's alone it looks like a working app.

The cause is not the dropped-write bug that was the obvious suspect ([#3907](https://github.com/matz/spinel/issues/3907)). It is `dt`: **the update block's `Float` argument arrives as Integer `0`**, so every `velocity * dt` is zero. Drafted as [issue 33](issues/33-float-argument-to-a-stored-proc-truncated-to-integer-zero.md), and it needs an unlikely pair — the parameter read inside a nested block, and a `Struct` somewhere in the program. Neither alone does it, and the `Struct` need not be touched by the proc.

Bisecting the example beat guessing at it: stripping the `update` body restored `dt` to `Float`, one section of it broke it again, and the emitted C then named the mechanism outright — `mrb_int lv_…_dt = (argc > 0) ? args[0] : SP_INT_NIL`, the truncating integer slot that `src/codegen.c:3310` already warns about for exactly this ABI.

Two adjacent findings came out of the same session: [issue 35](issues/35-yield-inside-a-lambda-raises-instead-of-calling-the-block.md), `yield` inside a lambda raising `LocalJumpError` rather than calling the block, and the confirmation that a homogeneous array element's `x +=` is dropped where the same write through a `Struct` member lands — the latter still unreduced.

**The lesson the port keeps re-learning is that every check here asks whether something compiles, runs or draws, and none asked whether it moves.** The motion check is four lines of injected source and caught two of three programs on first use. `rake compare` does the pixel half for fixtures; this is the same idea aimed at the example corpus, and it belongs in `tools/` rather than in a scratchpad.

## Three workarounds dropped, and one that could not be (2026-08-13)

The overnight pull closed the last six filed issues and took the compatibility layer from seven transforms to four: `bypass_window_class_methods`, `window_guards` and `expand_hash_delete` all went. What is left is two decisions and two bugs.

**A fourth was dropped and had to be put straight back, and that is the part worth reading.** `rake sweep` reported `block_param_capture` droppable. It was deleted. The 867-example suite passed, all five checks passed, `rake sweep` passed, and `rake compare` reported all three fixtures byte-identical to mruby. Then a real build of `examples/bouncing_balls.rb` failed:

```
spinel: build/app.rb:2127: unsupported proc referencing an uncaptured outer
variable `proc` (later slice): node 14428 (LambdaNode)
```

**Every app using `on` had stopped building, and not one check noticed**, because the subset's `MAIN` never registered an `on` handler. The filtered branch of `Interactive#on` was unreachable, so the lambda the transform rewrites was never compiled, so dropping the transform changed nothing the subset could observe. `build_subset.rb`'s fixture now registers `sq.on(click: :left)`, and with that one line sweep reports the transform still needed. **A transform can only be swept if the fixture reaches the code it rewrites** — the same lesson `rake compare` taught when three stroke entry points drew nothing because no fixture exercised them.

The evidence was already in hand and went unused, which is the more uncomfortable half. `rake survey` had reported the full library still refusing that exact line, *after* the transform was deleted, and it was written into this document as a finding about draft 34 without anyone connecting it to the transform. Sweep and survey disagreed and sweep was believed because it is the documented one. **When two checks disagree, the one grading more code is right.**

**Droppable in the slice is not fixed in the library.** Draft 34 still reproduces, and #3912 — which looked like its fix — cleared a neighboring shape: a lambda in an iteration block capturing both a block local and the block parameter. Draft 34's is `&blk` captured in a proc in a module reached by `include`. The branch has spent a week learning that a passing reproducer does not mean a fixed library; this is the same lesson one level up. **A passing `rake sweep` does not mean a fixed library either.** Sweep grades the 25-file slice; `survey` is the only check that grades all 37, and it sits outside the default set.

The same question is now open about one of the three that did drop. The `const char *` C error survey still reports was attributed to `expand_hash_delete`, dropped today for a bug (#3806) that is fixed. Slice clean, library not — possibly the same pattern a second time. Nobody has checked whether that is a different `delete` site or the same one behaving differently once more code is reachable.

**`survey.rb` hid all of this for one run, and that is now fixed.** With the `interactive.rb` entry removed to test whether it was stale, the tool printed an empty "Remaining C errors" list — which reads as *nothing left to fix*. Spinel had refused the program before clang ever ran, and its diagnostics say `spinel: file:line: unsupported …`, never `error:`, so the census matched nothing. An empty list and a clean build were indistinguishable. It now prints the refusal and says plainly that it is the first blocker rather than the list.

## Canvas, Polyline, Triangle and Button (2026-08-20)

**Four more classes, 27 → 42 programs accepted (76%), nine `rake compare` fixtures byte-identical to mruby.** `Polyline` and `Triangle` were geometry: `R2D_DrawTriangle` takes 18 floats, and both strokes go through `R2D_StrokePath`, which grew a `double *` entry (`R2D_StrokePathD`) because Spinel's arrays cross as doubles. `Button` composes `Rectangle` and `Text`, so it needed no entry point — its fixture is the first whose hover state is painted by a per-object event, the yellow "Hover me" in `button_app.rb` coming from an injected mouse move.

**`Canvas` was the large one, and it set the pattern for `Image` and `Sprite`.** `canvas.c` is now Ruby-free cores with thin bindings: every `Ext.canvas_*` parses its Ruby arguments into doubles and calls a `R2D_Canvas*` function that takes the canvas handle, scalars, and packed arrays as `const double *` with a length — the same layouts the bindings always documented. The Spinel adapter floats each packed payload (`lib/` packs counts and coordinates as Integers) and hands it over as a `:float_array`. Scale modes cross by name through `*Named` variants, and `R2D_CanvasDrawText` takes the `Text` handle the adapter already holds. The refactor was a script over the file rather than a rewrite, and the 957-example suite passed on the first compile. `draw_image` raises on this target until `Image` lands.

Four things in `lib/` had to change, each one line-sized, three of them compiler bugs drafted:

| Draft | Shape | Change |
|---|---|---|
| [53](issues/53-multiple-assignment-from-ivars-emits-invalid-c-when-a-keyword-can-reassign-one.md) | `saved_w, saved_h = @width, @height` emits invalid C when a nil-defaulted keyword may reassign the ivar in the same method | `Canvas#render` saves and restores with plain assignments |
| [54](issues/54-an-implicit-self-call-inside-a-class-resolves-to-a-top-level-def-over-an-included-module.md) | an implicit-self call inside a class resolves to a live top-level `def` of the same name over the included module's — `on(:hover)` in `Button` went to the window | `Button` writes `self.on` |
| [55](issues/55-a-poly-dispatched-call-emits-a-miscast-arm-for-a-method-with-ivar-defaulted-keywords.md) | a poly-dispatched `clear` emits a miscast arm for `Canvas#clear`, whose keywords default to ivars — every app stopped compiling at `@events[:close].clear` once `Canvas` was reachable | `Window#register_event_handler` assigns a fresh Hash |
| — | `Triangle.render` ended in an `elsif` returning an Array beside branches ending in void `Ext` calls, and Spinel cannot type a method whose value is Array-or-nothing | the method returns `nil` on every path, which is what a render method means |

Two AOT gaps got transforms rather than `lib/` changes — `canvas_undef_color` and `button_visual_hooks`, both in [Workarounds to re-check](#workarounds-to-re-check) — because the code they neutralize is right on the other engines and there is nothing to reduce.

The `preflight` fixture moved again, to `Image` and `Sprite`. The 22 programs this round accepted have not been through `rake motion` yet; the previous round's three non-building programs stand.

## Line and Text (2026-08-20)

**The target now draws `Line` and `Text`, and the preflight accepts 20 of the 55 programs — up from 3 this morning.** Both are byte-identical to mruby under `rake compare`, which now has five fixtures: `line_app.rb` (solid, dashed, rotated, gradient) and `text_app.rb` (regular, bold with alpha, rotated, and a size change on a later frame so the re-rasterize path runs).

**`Line` was the easy one**, as predicted: two entry points of 21 and 23 floats through the `Circle` pattern, an afternoon's worth of `.to_f`.

**`Text` was the first pass-self seam with a native object behind it**, and it set the pattern for `Canvas` and `Image`. `text.c` now has Ruby-free cores — `R2D_TextRasterizeWith` and `R2D_TextDrawWith` — that both the Ruby bindings and a small FFI surface call: `R2D_TextNew` returns an opaque handle, `R2D_TextUpdate` rasterizes it from the font path, content, size and style flags, `R2D_TextWidth` / `R2D_TextHeight` read the measured size back, `R2D_TextStale` says the asset scale moved (a Text built before a HiDPI window opened), `R2D_TextDraw` takes position, pivot, color and the scale mode by name, and `R2D_TextFree` releases it. The measured size moved onto the `R2D_Text` struct, where the Ruby bridge mirrors it to `@width`/`@height` and the adapter reads it. On the Ruby side the adapter reopens `Text` with a `:ptr`-typed ivar for the handle — Spinel allows a pointer in a typed ivar but not in a Hash or Array — plus a `_spinel_measure` writer, the way `Window#_spinel_sync` was done. **Handles are never freed**: Spinel has no finalizers, so a program that churns `Text` objects leaks a surface per object; `content=` reuses one.

Two things outside the adapter had to move for the default font to resolve. `ruby2d build --spinel` now bundles `ruby2d/fonts/` next to the binary, through a `bundle_default_font` helper the mruby native build shares. And `Font.default` no longer asks `RUBY_ENGINE == 'mruby'`: the question was really "does this run from the gem or from a bundle", so it asks `RUBY_ENGINE == 'ruby'` and every built binary takes the bundled path — the same reasoning as `Ruby2D.ruby_owned_loop?`.

The contract that a built app runs from its `build/native` — where `ruby2d launch --native` puts it, and where the fonts are — was not something the tools honored: `check.rb`, `compare.rb`, `motion.rb` and `fps.rb` all launched the binary from the fixture directory, which no shape fixture ever noticed. `run_capped` grew a `chdir:` and all four run from the bundle now. The `preflight` fixture had used `Text` as its unsupported feature; it uses `Canvas` and `Image` now, with a note to swap again when one of those lands.

**The first `rake motion` over the wider set found five of the 20 that did not run.** Two were library-side and are fixed the same evening; three are app-side compiler bugs, one drafted:

| Program | What stopped it | Now |
|---|---|---|
| `outrun.rb` | `Rectangle.render` in `update` raised "draw before the window is ready": `Window.render_ready_check` calls `shown?` implicitly from `ClassMethods`, and an `alias_method` of a singleton `attr_reader` answers stale state there — [draft 52](issues/52-an-alias-of-an-attr-reader-in-the-singleton-class-reads-stale-state-from-an-extended-module.md), 12 lines | runs; `shown?` is a plain `def` in `lib/` |
| `snake.rb` | removing a segment after a click: `undefined method 'delete_if' for an instance of Hash` on `@pressed_objects`. Reproduces only in the assembled library — every standalone replica is correct — so it is [draft 50](issues/50-hash-delete-if-missing-on-the-pressed-object-map-in-the-assembled-library.md) as research notes, with `scratch/input/state_harness.rb` as the reproducer | animates; the `hash_delete_if` transform iterates the keys instead |
| `swarm.rb` | `d.vx, d.vy = random_velocity`: multiple assignment to attribute writers is refused on a user class, and **silently truncates Floats** on a `Struct` — [draft 51](issues/51-multiple-assignment-to-attribute-writers-truncates-floats-or-is-refused.md) | does not build |
| `marching_squares.rb` | `b[:x] += b[:vx] * dt` on a Symbol-keyed Hash: `invalid operands to binary expression ('sp_int' and 'sp_RbVal')` in the generated C | does not build; not reduced |
| `maze.rb` | `unsupported proc referencing an uncaptured outer variable 'phase' (later slice)` — a lambda capturing a local, the shape of [issue 34](issues/34-proc-capturing-a-block-parameter-refused-in-an-included-module.md) outside an `include` | does not build; not reduced |

`rake motion` itself says FROZEN for `outrun`, `breakout`, `gamepads`, `fireworks` and `ray_casting_maze` **on mruby too** — scenes that wait for input or an event before moving — so those rows are about the check, not the target. `bouncing_balls.rb` remains the one frozen-on-Spinel-only program ([issue 33](issues/33-float-argument-to-a-stored-proc-truncated-to-integer-zero.md)).

The ranking for what to add next is in [The goal](#the-goal): `Canvas` first at +7.

## Input reaches the app (2026-08-20)

**Every kind of input now arrives on the Spinel target**: key down/up, mouse move, buttons, scroll and close, window-level and per-object, through `on(:event)` and the filtered `on(event: value)` form alike. `rake input` proves it on a built app, 21 handler lines in dispatch order.

The adapter work was the shape the README predicted. FFI cannot return an array, and `drain_events` is one flat array of `R2D_EVT_STRIDE` values per event. So `window.c` grew six Ruby-free accessors — `R2D_EventCount`, `R2D_EventInt(i, field)`, `R2D_EventDelta(i, which)`, `R2D_EventStr(i)`, `R2D_EventKeyName(i)` and `R2D_EventsClear` — and the adapter's `drain_events` rebuilds the same array from scalar reads, interning a key event's name with `to_sym`, so `Window#dispatch_events` runs unchanged. The Ruby bridge's own drain now releases the queue through the same `R2D_EventsClear`, so there is one ownership path for the gamepad-name strings poll allocates. `keyboard.c` joined the Ruby-free core for `R2D_KeyName`, with its Ruby binding behind `RUBY2D_NO_RUBY` like the rest, and the adapter's `key_names` walks the scancode table so `Keyboard.keys` is the real vocabulary rather than a stub.

Two compiler bugs stood between "events arrive" and "handlers run", and both got a `lib/` change that reads at least as well as what it replaced:

| Draft | Shape | In `lib/` | Change |
|---|---|---|---|
| [48](issues/48-a-hash-mixing-a-module-and-an-instance-dispatches-to-class.md) | a Hash whose values mix a Module with singleton methods and an ordinary instance cannot dispatch through a value — `for an instance of Class` | `EVENT_FILTER_VOCABULARIES` mapped to `Keyboard`/`Mouse` (modules) and `Gamepad::BUTTONS` (a `Vocabulary`) | a `filter_vocabulary(type)` method answering a `Vocabulary` every time, which also lets the key set stay lazy |
| [49](issues/49-a-lambda-that-is-the-value-of-a-conditional-has-its-parameter-typed-integer.md) | a lambda that is the value of a conditional — `?:` or `if`/`else` with a lambda in each arm — has its parameter typed Integer | `build_filter_wrapper` chose `args` with a ternary and returned its lambda from an `if`/`else` | assign in each arm; return the Hash-matcher lambda early |

49 is the one the 2026-08-12 table called "an escaping lambda's parameter inferred as Integer — not reduced". It reduces to twelve lines.

**How it was tested, since no keyboard can be driven headlessly.** `tools/input_app.rb` carries a few lines of C through Spinel's `ffi_source` that push SDL events — `SDL_PushEvent` with a scancode, a motion, a button, a wheel tick, `SDL_EVENT_QUIT` — one per frame with a frame between, so each is drained and dispatched alone and the output order is the dispatch order. The quit is the last injection, and the check requires it to close the window through the event path rather than a frame cap. Two harnesses in `scratch/input/` compile the real `lib/` slice with stubs and call `key_callback` / `mouse_callback` directly; they reproduce a dispatch bug in seconds where an app build takes a minute, and are how 48 and 49 were found.

**One false alarm worth recording:** per-object events appeared not to fire for an hour, and the bisect ran to nine app builds before a `diff` of the working and failing fixtures showed the failing one had no `sq.on` lines at all — a `String#replace` keyed on whitespace a `sed` had already collapsed, matching nothing and saying so to no one. Diff the fixtures before bisecting the compiler.

The three accepted examples all register `on` handlers (`mouse_down`, `mouse_move`, `key_down: :r`) and now receive them; whether each *reacts* correctly is still gated by the animation freeze in [issue 33](issues/33-float-argument-to-a-stored-proc-truncated-to-integer-zero.md) for two of them.

## Upstream pull to `f13e0ada` (2026-08-20)

220 commits since `42649df7`. Two drafts fixed — **43** (empty-literal block parameter) and **45** (the `Vocabulary` lookup, fixed within days of being drafted) — and its transform dropped. `rake issues`: 32 fixed, 13 reproduce, 2 parked.

**`subset` and `demo` are red, and `rake sweep` is blind, until two new drafts are fixed.** [`77cc33c9`](https://github.com/matz/spinel/commit/77cc33c9) adds `-Werror=incompatible-pointer-types -Werror=int-conversion` to Spinel's C compile, after the `--cc` string. Five pointer mismatches that had been warnings in the slice's build log since at least `42649df7` — the binary built and `rake compare` was byte-identical — are now fatal. They reduce to two bugs, both ordinary code:

| Draft | Shape | In `lib/` |
|---|---|---|
| [46](issues/46-a-string-method-that-interpolates-self-is-called-with-the-wrong-receiver-type.md) | a `String` method interpolating `self`, called from another `String` method | `cli/colorize.rb` |
| [47](issues/47-a-float-destructured-from-an-array-element-is-stored-as-its-bit-pattern.md) | `x1, _ = points[0]` into an Integer-defaulted keyword, then `[@x1, …].max` | `Quad#initialize` / `#width` |

47 is the one to read: standalone it **compiles and answers a Float's bit pattern** (`4602678819172646912` for `0.5`), which is the miscompile upstream's new gate exists to catch. The gate is right; it has only made a latent bug loud.

Three things follow from the gate sitting after `--cc`:

- `-Wno-error=…` on `--cc` does nothing — the later `-Werror=` wins. `-w` does win, from the front, which is why **`rake cli` still passes**: `build_spinel` passes `-w` unless `--debug`, so a real `ruby2d build --spinel` builds the same mis-typed C silently, exactly as before the pull. Do not read `cli` green as "the gate is satisfied".
- `rake sweep` reports every transform as "still needed — 5 C errors". Those are the same five errors regardless of which transform is dropped; the sweep cannot grade anything until 46 and 47 are fixed. To re-check a transform meanwhile, build `scratch/subset.rb` by hand with `--cc='cc -w -ferror-limit=0'` and diff against CRuby, which is how `vocabulary_string_hint` was cleared.
- Whether the check tools should pass `-w` to get the five checks green again is an open call. Against: it hides the exact class of bug 47 demonstrates. For: it is what the shipped build path already does. Left red for now.

## Working artifacts

Everything from the early research — the ~34 language probes, the SDL3 window test, the wasm build, and the benchmark — lived in a **session-scoped scratchpad and is gone**. Nothing here depends on it, and nothing needs recreating: the one piece that mattered, the harness that assembles the `LIB_FILES` slice into a single file and compiles it, is committed as `tools/build_subset.rb`. Re-clone Spinel and rebuild rather than hunting for the rest.
