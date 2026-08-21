# Interactive tests

This directory contains the interactive visual tests for Ruby 2D — runnable demos that surface a feature with on-screen feedback for a human to verify. They are separate from the automated RSpec suite in `spec/`, which is what `rake` (no args) runs.

## Running

```
rake test:ruby <name>      # run with CRuby
rake test:native <name>    # run as a native mruby executable
rake test:spinel <name>    # run as a native executable compiled by Spinel (needs `ruby2d setup --spinel`)
rake test:web <name>       # run as a web app (mruby + WebAssembly)
rake test                  # alias for test:ruby
rake test:all [target]     # run all tests sequentially (target: native, web)
rake test:auto             # auto-run each test briefly to catch crashes
```

`<name>` is the test filename without the `.rb` extension — `rake test:ruby keyboard` runs `test/keyboard.rb`. Most tests print a one-line summary of what to look for at the top; the window stays open until you press <kbd>ESC</kbd>.

Note that `rake test:native`, `rake test:spinel` and `rake test:web` build from the **installed** gem's `lib/`, not the working tree — after editing `lib/`, run `rake` (which reinstalls the gem) first, or the build silently won't include your change.

## Tests

### Input

Each device test focuses on raw events and per-device feedback. Higher-level abstractions (per-shape `on()`, `Button`, cursor styling) live in `input.rb`.

- **`keyboard.rb`** — `:key_down` / `:key_held` / `:key_up`, last-key readout, held-key grid, modifier indicators.
- **`mouse.rb`** — buttons, motion + delta, scroll deltas with a draggable square inside a scroll-tracked area.
- **`gamepad.rb`** — single-pad connect/disconnect, button visualization in a controller layout, raw stick + trigger axes, drift-max readout, mouse-clickable rumble.
- **`input.rb`** — three panels of input abstractions: per-object events (click/hover/drag/scroll on shapes), `Button` showcase (default + wrapped + stroked, auto and explicit hover/pressed tints, visual-less hit area, filtered click), and cursor styling (visibility + system cursor grid).

### Visuals

- **`shapes.rb`** — every shape type × the universal modifiers (fill/stroke, opacity, rotation, z-index, contains?, gradients + dash) in a 3×2 grid, laid out in the technical style of the input tests.
- **`text.rb`** — Text (TTF), BitmapText, and Fonts: sizes, available system fonts, modifiers, and ASCII coverage.
- **`alignment.rb`** — symbolic `x:` / `y:` alignment + per-edge `padding:`, including a live frame readout that should stay centered as content changes.
- **`image.rb`** — Image: PNG / JPG / BMP / SVG formats, tint, opacity, rotation, vector scaling, and `scale_mode` (`:linear` / `:nearest` / `:pixel_art`) at integer and fractional magnification.
- **`sprite.rb`** — Sprite: clip-based animation, named animations from frame ranges, flip modes, atlas with explicit frames, Sparrow XML sprite sheets (shared texture, named frames, named animations), speed multiplier, one-shot callbacks, pause/resume.
- **`tileset.rb`** — Tileset: define + place, rotate / flip per definition, multiplicative tint, scene composition, interactive cycle ([] / []=), clear / delete / refill.
- **`canvas.rb`** — full Canvas drawing API: filled + stroked primitives, gradients, blending, joins, draw_image, draw_text.
- **`window.rb`** — live state readout (size / viewport / display / fps / frames / mouse) and `.new` vs `.render` parity. Viewport modes live in `viewport.rb`; DPI / pixel-scale lives in `pixel_scale.rb`.
- **`viewport.rb`** — viewport modes interactive switcher (letterbox / stretch / integer / overscan / expand / fixed).
- **`pixel_scale.rb`** — `pixel_scale: true` + `highdpi: true` mapping logical pixels to physical pixels.

### Audio

- **`audio.rb`** — sound and music playback in WAV/MP3/OGG/FLAC, with sliders for per-source volume and the global mixer, loop toggle, fade out, status display.

### DSL patterns

Different ways of structuring a Ruby 2D app, all rendering equivalent scenes for comparison.

- **`pattern_class.rb`** — subclassing `Ruby2D::Window`.
- **`pattern_dsl.rb`** — top-level DSL.
- **`pattern_instance.rb`** — explicit `Ruby2D::Window.new` instance.
- **`pattern_singleton.rb`** — using the DSL singleton.
- **`pattern_without_auto_mixin.rb`** — opting out of the automatic top-level mixin.

## Style

The input and shape tests use a consistent technical visual style: near-black background, hairline-gray chrome, mint accent for live signal. New tests should follow it so the suite reads coherently.

### Palette

| Role                                | Constant       | RGBA                     |
| ----------------------------------- | -------------- | ------------------------ |
| Window background                   | `BG`           | `[0.05, 0.06, 0.07, 1]`  |
| Default frame / divider             | `LINE`         | `[0.20, 0.22, 0.24, 1]`  |
| Emphasized frame (cells, buttons)   | `LINE_HI`      | `[0.35, 0.38, 0.42, 1]`  |
| Captions, inactive labels           | `DIM`          | `[0.40, 0.42, 0.44, 1]`  |
| Body text, static readouts          | `TEXT`         | `[0.75, 0.78, 0.80, 1]`  |
| Page title, headings                | `HEAD`         | `[0.92, 0.94, 0.96, 1]`  |
| Live signal (mint)                  | `ACCENT`       | `[0.45, 0.95, 0.70, 1]`  |

`ACCENT` is reserved for things that respond to user input or change over time (live readouts, hit highlights, press tints). Demo shapes pick a panel-specific hue (e.g. `WARM`, `TEAL`, `AMBER`, `VIOLET`) so the accent stays meaningful.

### Layout

- **Window:** title via `set title: 'Ruby 2D — <Feature>'` (use an em-dash). `set close_on_esc: true`.
- **Header:** page title at `(16, 12)` in `HEAD` at size 16, hairline divider at `y = 38`.
- **Panels:** rectangular frames with `[ NAME ]` label inset at `(+10, +8)` in `DIM`. Frames built from four `hairline` lines, not filled rectangles — keeps chrome readable at any size.
- **Cells:** small interactive faces (button cells, event cells, dpad squares) follow the same pattern: `BG` fill, `LINE_HI` frame, centered label in `DIM`.

### Helpers

Each test inlines its own small helpers — typically `hairline`, `frame`, `label`, and a centered-text helper — following the palette and layout above. There's no shared style library; keep every test fully self-contained so it runs and reads on its own.

### File header

Every test starts with a one-line title and 2–4 lines of prose describing what is being tested. List the panels if there's more than one; mention any non-obvious key bindings.

```ruby
# Mouse
#
# Sister to test/keyboard.rb in the same technical style. Exercises
# mouse_down, mouse_up, mouse_held, mouse_move, and mouse_scroll with
# compact numeric readouts and a scrolling event log.
```

### Interaction conventions

- Pair every state change with two channels: a color shift and a text readout. Don't rely on color alone.
- Use `Button` (with `pressed_color:` for held-down feedback) over hand-rolled hit-rect + window-level handlers. The visual-less form (`Button.new(x:, y:, width:, height:)`) is the right tool for a clickable region without its own visual.
- Use per-shape `on(:click)` / `on(:hover)` / `on(:drag)` / `on(:mouse_scroll)` instead of window-level handlers + manual `contains?` filtering.
- For dynamic-content text, anchor it left-aligned or re-center on each content change — `text_in_rect` only centers at construction time.
