# Architecture

Ruby 2D is a 2D graphics, audio, and game library for Ruby. It provides a simple, expressive DSL for creating windows, drawing shapes, rendering images and text, playing audio, and handling input — all backed by a native C extension that talks to SDL3.

## Design Principles

**Simplicity first.** A beginner can draw a red square in 3 lines of code. The DSL layer makes the common case trivial, while the class-based API gives power users full control over the same window and objects.

**Two usage patterns, one engine.** Users can write top-level DSL scripts (`set title: 'Hello'` / `show`) or instantiate `Ruby2D::Window` directly and subclass it. Both patterns route through the same C extension and rendering pipeline. The DSL works because the entry point (`ruby2d.rb`) does `include Ruby2D` and `extend Ruby2D::DSL` into `main`, which is why methods like `set` and `show` are available at the top level. Users who want only the class-based API can `require 'ruby2d/core'` to skip the DSL mixin.

**Ruby on top, C underneath.** Unlike typical C extensions where a C struct is the source of truth and Ruby accessors read from it, Ruby 2D inverts this: all user-facing state (position, color, z-order) lives in Ruby instance variables, and the C extension reads those variables at render time. There is no duplicated state to keep in sync. Ruby owns the data; C owns the pixels.

**Multi-runtime portability.** The C extension compiles against both CRuby and mruby. A macro abstraction layer in `ruby2d.h` maps a single API onto both runtimes. If you open any `.c` file and see unfamiliar `r_*` / `R_*` calls instead of the usual `rb_*` or `mrb_*` functions, that's this layer; check `ruby2d.h` for definitions.

**Linear scene graph.** The window maintains a flat, z-sorted array of renderable objects. There are no scene trees, parent-child transforms, or layers. Objects are inserted in z-order and iterated back-to-front each frame (painter's algorithm): the lowest `z` is drawn first, the highest `z` last and on top.

## Design Decisions

Settled decisions whose rationale isn't visible from the code. Each can look like a bug or an accident from the outside; none is.

**One window, one lifetime.** Ruby 2D supports exactly one window per process, opened once, with no close-and-reopen (`Window#show` raises if called twice). Consequently there is no SDL teardown path — no `SDL_Quit`, no mixer destroy — because the process is expected to exit when the window closes and the OS reclaims everything. The absence of teardown is not a resource leak. Leaks that grow *during* a run (say, allocating a new cursor on every call) are still bugs worth fixing.

**Explicit arguments raise; animated values degrade.** Clearly-invalid input supplied at construction or via a setter (embedded NUL in `Text` content, `Tileset scale: 0`, a `Color::Set` where a single color is required) raises a clear error; silently coercing or truncating would hide the caller's bug. But per-frame values that legitimately pass through out-of-range while animating — a non-finite coordinate arriving from animation math, which the canvas drawing paths test and skip — degrade to a no-op for that frame instead of raising in the hot path. When adding validation, ask which case the value is: an explicit user argument raises, a runtime-animated value clamps or skips.

**A missing audio device is a hard error.** `Audio` operations raise `Ruby2D::Error` when SDL can't open a device — `ext/ruby2d/audio.c` checks `R2D_InitAudio()` at each entry point that needs one — rather than degrading to a silent no-op. This deliberately resolves the opposite way from the missing-SDL3 install path under Platform and Build below, and the asymmetry is the point: a toolchain without SDL3 still needs a working `ruby2d` command to recover with, whereas a machine that can't play sound can't run a Ruby 2D app as intended, and a game that quietly loses its audio hides a real environment problem instead of reporting it. Environments with no sound hardware should supply SDL's dummy driver (`SDL_AUDIO_DRIVER=dummy`), which is what this project's CI does on Windows.

**One clock.** All timing derives from the engine's monotonic clock: per-frame motion uses the shared frame delta (the `dt` passed to `update`, a.k.a. `Window#delta_time`) and absolute time uses `Window#elapsed`. No engine timing derives from `Time.now` or `Process.clock_gettime` (the sole wall-clock use is naming a screenshot file): they don't port to mruby (missing entirely, or overflowing the web build's 32-bit `mrb_int`), and one shared delta keeps all animation in lockstep, gets stalls clamped once centrally, and stays unit-testable (pass an explicit `dt`). New time-based behavior should consume `dt` (defaulting to `Window.delta_time`), never derive its own time.

**Color channels are floats, 0.0 to 1.0.** Numeric color arrays are on the graphics scale for Integers and Floats alike — `[1, 0, 0]` is red — and an out-of-range value warns once and clamps. Byte (0-255) input is served through input *formats* (hex strings, named colors), never by inferring the scale from a value's type or magnitude. Type inference was tried and rejected: `1` vs `1.0` becomes an invisible cliff, and integer arithmetic silently promotes to Float mid-animation, flipping the interpretation. One number, one meaning.

## Layered Architecture

```
User Code
  Ruby DSL or Window subclass
    |
Ruby Classes  (lib/ruby2d/)
  Window, shapes, Image, Text, Canvas, Audio, Color, ...
    |
C Extension  (ext/ruby2d/)
  Bindings read Ruby ivars, call into SDL3
    |
SDL3
  SDL3, SDL3_image, SDL3_mixer, SDL3_ttf
```

Data flows **down** through `Ruby2D::Ext` class method calls. The C layer never mutates Ruby-side state except during initialization (e.g., setting native image dimensions after loading a texture) and per-frame ivar syncs: `poll_events` syncs mouse position, window dimensions, and the close flag, while `begin_frame` syncs the frame count and fps (only on frames actually rendered).

Events flow **up** through a pull model: C queues raw events into a buffer during `poll_events`, Ruby reads them via `drain_events`, and Ruby's `dispatch_events` maps integer codes to symbols and fires user-registered handlers. There are no C-to-Ruby callbacks in the event path.

## Key Directories

- **`lib/ruby2d/`** — Ruby classes. Entry point is `ruby2d.rb` which loads `core.rb` (all classes + native extension) then mixes the DSL into `main`. Each drawable type, the window, audio, color parsing, and the CLI live here.
- **`ext/ruby2d/`** — Native C extension. Roughly one `.c` file per subsystem — `window`, `shapes`, `canvas`, `image`, `text`, `font` (the internal bitmap font for diagnostic overlays, and the native backing for the user-facing `BitmapText` class), `audio` — plus `ext.c` (the `Ruby2D::Ext` method bindings), `ruby2d.c` (initialization, logging, and the mruby entry point), and `fps.c` (the FPS overlay). `ruby2d.h` contains the multi-runtime abstraction macros, structs, and prototypes. `extconf.rb` handles platform-specific build configuration.
- **`assets/`** — Pre-built headers and static libraries for SDL3 and mruby (macOS, Windows), bundled fonts, and test media.
- **`spec/`** — RSpec automated tests (`*_spec.rb`), the machine-verifiable suite that `rake` runs.
- **`test/`** — Interactive visual/audio tests (plain `.rb` files run manually for a human to verify).

## Ruby-to-C Bridge

All C bindings are class methods on a single `Ruby2D::Ext` module. Ruby calls `Ext.method_name(...)`, which maps to a C function named `ruby2d_ext_method_name()` (subsystem bindings carry their subsystem as an infix, e.g. `Ext.poll_events` → `ruby2d_ext_window_poll_events`). Three data-passing patterns are used:

- **Shapes** use a **full-flatten** pattern: Ruby computes vertices, rotation, and colors and passes them as flat numeric data; nothing is stored on the C side. Fixed-arity shapes (Triangle, Quad, Line, Circle, Ellipse) pass them as positional float args; variadic shapes (Polygon, Polyline), whose vertex count isn't known at bind time, pass Ruby arrays instead (which C marshals into temporary buffers: stack-allocated up to a threshold, heap-allocated beyond it, and freed before the call returns).
- **Textured objects** (Image, Text, Canvas, BitmapText) and Window use a **pass-self** pattern: Ruby passes `self` as the first argument, and C reads instance variables via `obj_*` macros. GPU-side resources are wrapped in an opaque handle stored as a Ruby ivar.
- **Audio** uses an **opaque handle** pattern: `Ext.audio_load` returns a wrapped C pointer, and subsequent calls (`audio_play`, `audio_stop`, ...) receive it as the first argument.

Each C subsystem file registers its Ext bindings in an init function (e.g., `R2D_Image_Init()`). `R2D_Ext_Init()` creates the module and registers shape bindings; it must run first so subsystem inits can add methods to it.

## Rendering Pipeline

Ruby's `Window#tick` method orchestrates each frame by calling Ext primitives:

1. **`Ext.poll_events`** — C polls the SDL event queue, detects held keys/buttons, updates timing, and syncs state (mouse position, window dimensions, close flag) to Ruby ivars. Raw events are queued into a C-side buffer.
2. **`Ext.drain_events`** — Returns the queued events to Ruby as a flat integer/float array. Ruby's `dispatch_events` maps the raw codes to symbols and fires user-registered handlers.
3. **`update_callback`** — Ruby calls the user's update block, then clears per-frame input stores.
4. **`Ext.begin_frame`** — C syncs the background color from Ruby, decides whether to render (always in continuous mode, conditionally in on-demand mode), clears the renderer, and on frames actually rendered syncs the frame count and fps to Ruby ivars. Returns true/false.
5. **Render** — If `begin_frame` returned true, Ruby iterates the window's objects in z-order (each calls into C, which issues SDL render calls), then runs the user's render block.
6. **`Ext.end_frame`** — C draws the FPS overlay, takes any deferred screenshot, presents the frame, and applies the frame cap.

On CRuby, `Window#show` runs `tick until @close`. On mruby (native and WASM), a C-side loop calls Ruby's `tick` method each frame.

## Event System

Two input patterns are supported simultaneously:

- **Callback pattern** (DSL-style): register blocks with `on(:key_down) { |e| ... }`. Events are dispatched from Ruby's `dispatch_events` after the C poll returns.
- **Polling pattern** (class-style): query `key_pressed?('space')` or `mouse_pressed?(:left)` inside `update`. Event stores are populated during dispatch and cleared each frame.

## Viewport Modes

The viewport mode controls how the logical coordinate space maps to the physical window size whenever the two differ: on resize, on a HiDPI display, or with `pixel_scale`. Modes are letterbox (default), stretch, integer, overscan, expand, and fixed.

## Platform and Build

The gem ships with pre-built static SDL3 libraries for macOS (arm64) and Windows (UCRT) under `assets/`. `extconf.rb` detects the platform and sets the appropriate compiler and linker flags. Unbundled platforms — Linux, BSD, Intel macOS — supply SDL3 another way, covered below.

### Unbundled platforms and `ruby2d setup`

**The install never fails for a missing SDL3.** When none is found, `extconf.rb` deliberately installs *without* the extension — it writes a stub Makefile, surfaces recovery guidance (`Ruby2D::DepsHelp`), and exits 0 — because aborting would leave no `ruby2d` command to fix things with. At runtime, `ruby2d/core` rescues the native `LoadError` and aborts with that same notice.

Dependency resolution order is bundled libs -> version-stamped per-user cache -> system SDL3, implemented in both `lib/ruby2d/cli/build.rb` (`deps_platform_dir`) and `ext/ruby2d/extconf.rb`.

A local `rake` build opts out of the fallbacks. `rake install` passes `--with-bundled-libs`, and `extconf.rb` then links `assets/platform/` or aborts telling the developer to run `rake deps:build`. Without that flag the script has no way to tell a contributor's `rake` from a user's `gem install` — both extract to the same gem directory and run the same code — and silently dropping to a stale cache or a system SDL3 would mean testing against libraries the gem doesn't ship. `CONFIGURE_ARGS=--with-system-libs` overrides both, which is how CI's Linux lane builds against distro packages.

Recovery is two paths, both ending at RubyGems' standard extension build:

- Install SDL3 from a package manager, then run `gem pristine ruby2d`.
- Run `ruby2d setup`, which builds SDL3 + mruby into a per-user cache (`~/.cache/ruby2d` and platform equivalents, stamped with the gem version so an upgraded gem never links stale libs) and then runs `gem pristine ruby2d` itself.

Never hand-roll the extension build outside `gem pristine`; keep it on RubyGems' rails.

### Web (WebAssembly) constraints

The web build runs mruby compiled to 32-bit wasm with `MRB_NO_BOXING` (floats live inline in the `mrb_value`). The boxing flag is ABI: the vendored `libmruby.a` and every consumer compile must agree on `-DMRB_NO_BOXING`, or values silently corrupt at runtime. Practical consequences for code that runs on the web target:

- `mrb_int` is 32 bits, so milliseconds-since-epoch values overflow (one reason for the "one clock" rule above).
- Memory is a bounded wasm heap: cap peak allocation. Stream large workloads in bands or tiles and reuse (`clear`) accumulator arrays instead of building a whole frame's worth of objects at once (which aborts the tab), and keep any single array well under ~100k elements.
- Method dispatch is costly enough to dominate per-frame hot paths, so they use `while` loops with inline checks rather than per-element blocks and enumerator chains; `benchmark/README.md` carries the measured costs and the reasoning.

To run pure-compute snippets against the wasm mruby directly, use `assets/build/wasm/mruby/bin/mruby -e '...'`, a Node-hosted wasm binary that can't read host files, and that exists only once the wasm dependency build has run.
