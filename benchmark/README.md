# Ruby 2D Benchmarks

Performance benchmarks for measuring rendering throughput, frame-time stability, and allocation pressure under representative and stress workloads.

## Running benchmarks

List the available benchmarks:

```bash
rake benchmark
```

Run a specific benchmark:

```bash
rake benchmark:retained
```

Run all benchmarks sequentially:

```bash
rake benchmark:all
```

### On the web (wasm build)

Ruby 2D's per-object cost is dominated by Ruby dispatch and FFI marshaling, and those are far more expensive on the mruby/wasm build than on native CRuby — so the web target is where most micro-optimizations actually pay off. Run any benchmark on the wasm build in headless Chrome:

```bash
rake benchmark:web[retained]          # defaults: 5s warmup, 3s measure
rake benchmark:web[canvas,10,5]       # name, warmup_s, duration_s
```

This inlines the harness and scene into one self-contained source, compiles it with `ruby2d build --web`, runs it in headless Chrome with software WebGL, and prints the same report captured from the page console (`benchmark/web/run.rb` + `drive.js`). Requires `emcc`, `node` (≥ 22), and Google Chrome. The web build compiles the *installed* gem's `lib/`, so run `rake` after editing `lib/` — and, to A/B a `lib/` change, `rake` between the two arms.

Reading web results differs from native in three ways:

- **Read the averages, not the percentiles.** The browser clamps `performance.now()` to ~1 ms (Spectre mitigation), so per-frame percentiles quantize to whole milliseconds. Averaging thousands of frames still recovers sub-millisecond precision, so `CPU build`'s `throughput`/`ms/frame` and the `render` average are the trustworthy numbers.
- **`present` is near zero, so CPU build ≈ wall clock.** The web loop presents through the browser compositor without the blocking swap that dominates native desktop, so on web the CPU-build number *is* the frame cost.
- **Software WebGL (SwiftShader) is slower than a real GPU but consistent.** Absolute web numbers are pessimistic, but relative A/B comparisons between two builds hold.

For budgeting wasm hot paths, the useful unit is the method dispatch: **~0.3 µs each** (the C-call floor is ~295 ns). Every per-element block (`each`/`all?`/`sort_by`) pays it per element per pass, `respond_to?` pays it per call, mruby materializes a block literal at every call site passing `{ }` (CRuby doesn't for `yield`), and enumerator chains (`each_with_index.sort_by`) are µs-scale even on empty arrays. Hot paths in this codebase use `while` loops with inline checks instead — see `dispatch_events` or the canvas batch methods.

To isolate a C-level cost outside the engine, build a from-source wasm mruby with a bench mrbgem: `MRuby::CrossBuild` + `conf.gem`, sources in `assets/sources/mruby`, ABI flags matching the vendored build (`-O3 -DMRB_NO_BOXING`). It's a ~2-minute build that emits a Node-hosted mruby binary.

## Available benchmarks

| Benchmark | Description |
|---|---|
| `baseline` | Empty window — anchors the frame-loop overhead ceiling |
| `retained` | Retained-mode rendering (objects added once) |
| `mutation` | Retained-mode with per-frame attribute mutation |
| `immediate` | Immediate-mode rendering (draw calls per frame) |
| `circles` | Circle rendering (high geometry count) |
| `images` | Image/texture rendering (single source texture) |
| `images_multi` | Image rendering across multiple source textures (rebind cost) |
| `sprites` | Animated sprite rendering (clip-rect updates per frame) |
| `text` | Text/font rendering (static content) |
| `text_dynamic` | Text/font rendering with per-frame content changes |
| `tiles` | Tileset rendering throughput (re-randomised per frame; stress) |
| `tiles_static` | Tileset rendering of a fixed map (common-case counterpart) |
| `canvas` | Canvas drawing throughput (full clear + repaint per frame; stress) |
| `canvas_incremental` | Canvas incremental stamps onto a persistent surface |
| `mixed` | Representative 2D game scene combining all primitives |

## Reading the output

Each benchmark prints something like:

```
Ruby 2D Benchmark — Retained (Squares)
------------------------------------------------------------
  Warmup:        10s (3039 frames)
  Measured:      5s (1523 frames)

  Throughput:    303.0 fps  (3.30 ms/frame)

  Frame time (wall clock, incl. present):
    p50:       3.11 ms
    p95:       5.36 ms
    p99:       5.71 ms
    p99.9:     7.42 ms
    max:       7.60 ms

  CPU build (frame minus present) — the per-object cost:
    throughput: 634.0 fps-equiv  (1.58 ms/frame)
    p50:       1.57 ms
    p95:       1.65 ms
    p99:       1.69 ms
    render:    1.56 ms  (p95 1.65 ms)
    present:   1.72 ms

  GC:
    Allocations: 3 objects (0 / frame)
    Minor GCs:   0
    Major GCs:   0
------------------------------------------------------------
```

- **Throughput** — average fps and ms/frame across the measurement window, wall clock. This includes `SDL_RenderPresent`, which on a desktop compositor is often a fixed per-frame floor (an empty window can measure *slower* than a populated one). Treat it as a stability/tail signal, not a measure of per-object cost.
- **Frame time (wall clock)** — percentiles of the full frame, present included. `p99`/`p99.9` surface tail-latency hitches that average fps hides.
- **CPU build (frame minus present)** — the frame time with the present wait subtracted out: the work a code change can actually move. Below a few thousand simple objects the wall-clock number is present-bound and blind to CPU regressions, so **this is the number to A/B against.** Its percentiles are far tighter than wall clock. `throughput` is the fps you'd see if present were free; `render` is the slice spent in `render_objects` (scene-graph dispatch + FFI marshaling, plus any `render do` block); `present` is the isolated `SDL_RenderPresent` cost. A scene that draws in an `update do` block (not the scene graph) shows its cost in CPU build but not in `render`.
- **GC** — allocations and collection counts during measurement. Allocation hotspots are usually the first thing to investigate when frame-time tail or steady-state throughput regresses.

The CPU/present split is measured by two harness-only wrappers (`Ext.end_frame` and `Window#render_objects`); they cost a couple of sub-microsecond clock reads per frame and apply to every benchmark equally, so A/B comparisons stay consistent.

## Methodology

- `fps_cap: :infinity` — vsync off, no frame cap, so each benchmark measures raw throughput rather than refresh rate.
- 10s warmup before measurement so JIT, shader compile, and texture upload have stabilized.
- 5s measurement window, recording per-frame deltas from a monotonic clock (`Process::CLOCK_MONOTONIC` on CRuby) — never smoothed `Window.fps`, which masks tail latency.
- Window size fixed at 1280×720 across benchmarks so results are comparable.

## Finding optimizations

These standing benchmarks are a coarse regression net and a starting signal — they tell you *which* path is slow or allocation-heavy. The actual wins, though, come from **throwaway A/B probes** tailored to one change, not from the benchmarks above. A workflow that has worked well:

1. **Measure where the cost actually is — don't guess.** The `GC` line flags allocation churn; to find its source, profile a representative scene. `GC.stat(:total_allocated_objects)` or `ObjectSpace.count_objects` deltas around a single frame give allocations *by type*; `ObjectSpace.trace_object_allocations` with `allocation_sourcefile`/`allocation_sourceline` pinpoints the exact line.
2. **Pre-register the decision rule before measuring** — e.g. "ship if ≥4% faster, drop if <3%". Let the number decide, not the ego.
3. **A/B in one build.** Add the new code path alongside the old and gate it behind an `ENV` var (or `git stash` the change between runs), then run the *same* custom scene both ways. Same binary, same scene, one variable — this isolates the change from build and scene variance.
4. **Run several times and read the stable metric.** Read the **CPU build** line, not wall-clock throughput. On desktop the wall-clock number is present-bound below a few thousand simple objects — its run-to-run variance (~±10%) swamps the per-object cost, and a populated scene routinely posts a *higher* wall-clock fps than the empty `baseline` even though its CPU work is strictly greater. CPU build subtracts the present wait, so its percentiles are tight enough to see a single-digit-percent change; `render` isolates the scene-graph draw further still.
5. **Test the realistic workload and watch for crossover.** A change can win on an extreme and regress the common case: a single-color `Polygon` fill fast path helped 30-gons but *regressed* the typical 8-gon, so it was dropped. Measure the case people actually run.

What this codebase taught us about *where* per-object render cost lives: it was dominated by **Ruby allocation and `Array#[]` churn** — per-vertex color-cache scans, splatting cached colors into wide FFI calls, throwaway payload arrays — not the GPU (SDL3 already batches same-state draws) and not even the FFI argument count. Suspect the Ruby marshaling first, and distrust magnitude intuition: measured results here ranged from "7× bigger than predicted" to "a confident prediction that turned out to be a regression". The A/B was the only reliable instrument.

## Tried and rejected

Optimizations that were measured and dropped. Re-attempting one without a fresh A/B just repeats the experiment:

- **Userland geometry batching** — collapsing per-shape `SDL_RenderGeometry` calls into one big call. SDL3's renderer already auto-batches consecutive same-state draw calls into a single GPU submission (see `SDL_FlushRenderer` docs), and an isolation probe measured N calls vs 1 call as identical to within noise at both 3,600 and 14,400 quads. The per-object cost that remains is Ruby dispatch + FFI marshaling, which a C-side batcher can't touch.
- **wasm SIMD** (`-msimd128`). No measurable FPS change on either an FFI-bound scene or a deliberately canvas-bound stress test — autovectorization barely touches the extension, and the canvas per-pixel blend has a branch + early return that defeats it — while any SIMD op in the module raises the browser version floor (Safari 16.4+). Real gains would need hand-written intrinsics; not worth it.
- **A persistent, `SDL_UpdateTexture`-updated text texture on native.** Measured **+75% frame cost** on `text_dynamic` — Metal's fast path is destroy + `SDL_CreateTextureFromSurface` per content change. The web build wants exactly the opposite (fresh per-frame texture objects stall the WebGL pipeline; the persistent texture cut its render slice −61%), so `text.c` platform-splits the strategy. Don't unify the paths without re-running `rake benchmark:text_dynamic` and `rake benchmark:web[text_dynamic]` back-to-back.
- **Indexed `while` loop over the retained object array** instead of `each` in the native frame traversal. 1.70 ms vs 1.69 ms CPU build on 3,600 retained squares — noise. Block dispatch isn't where the per-object cost lives on CRuby; wasm would need its own measurement.
- **Conditional Canvas surface locking.** A 3,443-sample profile of the full-repaint canvas benchmark put `SDL_UpdateTexture` at ~38% of main-thread time and lock/unlock at two samples total. Full repaint is software-raster and upload bound; there's nothing to save around the lock.

## Adding a new benchmark

1. Add a Ruby file to this directory that requires `ruby2d` and `ruby2d/benchmark`, then calls `Ruby2D::Benchmark.run('Name') do ... end` with the scene setup inside the block. Both `update do` and `render do` blocks inside setup are supported.
2. Open with a header comment in the same shape as the existing files: a short paragraph describing what the benchmark does, then a `Why it matters:` paragraph naming the real-world workload it represents, the specific code path it stresses, and the optimization lever the bench reveals. Add a `Note:` line if the workload is intentionally pathological (see `tiles.rb` and `canvas.rb` for examples).
3. Register the file name and a one-line description in the `BENCHMARKS` hash in the project [`Rakefile`](../Rakefile).
4. Add an entry to the table above.
