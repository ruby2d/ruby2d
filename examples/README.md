# Examples

Each file in this directory demonstrates Ruby 2D features or techniques. Examples run standalone (`ruby examples/foo.rb`), stay short enough to read in one sitting, and double as Ruby 2D's visible portfolio (make them look good, not just correct). They also serve as the canonical reference for idiomatic Ruby 2D — examples teach by showing, so always reach for the most idiomatic form the API offers (predicate methods with `?`, symbol matchers, the kwarg form of `on`, etc.). `USAGE.md` is the source of truth for current style; when it changes, the examples should follow.

## File layout

Examples read top to bottom in a predictable order so a reader can skim straight through: header comment, `require 'ruby2d'`, tunable constants, `set` calls, any structs and helper `def`s, mutable state, persistent renderables, a `reset` lambda and its initial call when the demo is replayable, input handlers, `update`, `render`, `show`. Existing examples that drift from it are fair to clean up.

## Header comment

Every example opens with a four-block header: title, short description, blank separator, longer narrative.

```ruby
# Title in sentence case
# One short tagline saying what the demo is, in one or two lines.
#
# Longer narrative — what's happening on screen, controls (which keys
# do what, how to restart), and any algorithm or context worth noting.
```

The short description is whatever appears between the title and the first blank `#` line. `ruby2d examples` parses it and shows it in the interactive picker's preview pane, which is capped at three lines on an 80-column terminal — keep it to one or two source lines (≲150 chars) so it never overflows. Move controls and any extra detail into the longer narrative below the blank line; the narrative is printed when the example launches but does not appear in the picker preview.

If a demo really has nothing more to say than the tagline, the longer narrative may be omitted — leave just the title and the short description. The window title uses the form `'Ruby 2D ▸ Examples ▸ Title'` so listings stay consistent.

## Tunables

Lift magic numbers to `SCREAMING_SNAKE_CASE` constants at the top and add a short trailing comment for each. A reader should be able to skim the constants and know what's tweakable without reading the body. Anything that controls feel — speeds, accelerations, sizes, score values, particle counts — belongs up there.

```ruby
WIDTH = 800        # window width in pixels
HEIGHT = 600       # window height in pixels
THRUST = 0.12      # acceleration while thrusting (per 60Hz frame)
HIT_PENALTY = 200  # score deducted when the ship is destroyed
```

Derived values (e.g. `COLS = WIDTH / GRID`) live next to the constants they're derived from.

## Conventions

- `set close_on_esc: true` always.
- `r` restarts the demo when there's anything to reset; capture the reset routine as a `lambda` so input handlers and the initial setup share one path.
- Centered overlay text creates the `Text` with content first, reads its `width` attribute, then assigns `x = (WIDTH - text.width) / 2`.
- Toggle visibility with `text.hide` / `text.show` (or `text.visible = false`/`true`). Initialize hidden with `Text.new(..., visible: false)`. Don't blank `content` to hide — that rebuilds the texture (`Ext.text_create`) on every toggle.
- Per-frame draws with no persistent state use the immediate-mode form `Foo.render(...)`. Persistent HUD elements use `Foo.new(...)`.
- Gameplay and other logic stays inside `update`; drawing stays inside `render`. Don't mutate state from `render`.
- Use the `dt` argument from `update do |dt| ... end` for motion and timers. Store all rates in per-second units — velocities in px/sec, accelerations in px/sec², drag as a per-second decay rate (`vx *= Math.exp(-drag * dt)`, or its linear approximation `vx *= 1 - drag * dt` for small dt). Don't tie speed to frame count — refresh rates vary across machines, and the demo should feel the same on 60Hz, 120Hz, and 240Hz displays.
- Pick colors that feel like they belong with the rest of the gallery. Hex (`'#fde047'`) or [`clrs.cc`](https://clrs.cc) named colors generally read better than the raw `'red'`/`'blue'` defaults. Each example doesn't need to match every other one, but they should feel like they're part of the same set.
- The default font (Outfit) covers only ~360 codepoints, and SDL_ttf renders a missing glyph as *nothing* — no error, just a blank. Available: `×` (the only X-shaped glyph), `✓`, the arrows `←↑→↓`, `•`, `·`, `–`, `—`. Not available: the dingbat X's (`✕✖✗✘`), geometric shapes (`○●◆★☆`), and all emoji.
- Mixing gamepad polling with keyboard latches: derive an *effective* input each frame into a local both `update` and `render` can see. Never `||=` a poll result onto the keyboard's latched boolean — only `key_up` clears it, so a released pad control sticks on forever.

## Comments

The repo's default is "write no comments" — these examples are the exception, because their job includes teaching. Even so, only add a comment when it earns its line:

- `# === Section ===` banners separating major chunks (state, input, update, render).
- Non-obvious math: rotation into world space, toroidal shortest distance, easing curves, the wrap trick `((d + size/2) % size) - size/2`.
- A constant or line that encodes a deliberate choice a reader might otherwise want to "fix" (e.g. why velocity decays at exactly 0.992).
- A short comment trailing each tunable constant.

Skip comments that restate the code. `# update bullets` above `bullets.each { ... }` is noise.

## Polish

A demo's job is to be fun to look at, not just functionally correct. When finishing or cleaning up an example, look for cheap wins that show off the library:

- Background flavor — starfield, gradient, faint grid
- Particles for impacts, thrust, deaths, victory bursts
- Easing on transitions instead of hard cuts
- Per-vertex gradients on `Triangle`/`Quad`/`Line`
- Subtle opacity changes to communicate state (invulnerability, fading, hover)
- Tasteful palette (a few hex colors that go together, not random named primaries)

Polish is not feature creep. Don't bolt on gameplay mechanics, levels, sound, or AI that isn't part of the intent of the example. The bar is "does this make the existing demo more pleasant to watch?" — if not, leave it out.

## Before declaring done

- Play it (`rake examples <name>`) through the golden path plus one edge (hit/restart, edge wrap, empty state). Playing it is the real test — nothing else judges whether it looks and feels right.
- `rake examples:auto` spawns every example briefly and reports crashes — a cheap check that nothing else in the gallery broke.
- Read the file top to bottom — does it follow the layout, tunables, and conventions above?
- If user-facing behavior changed, does `USAGE.md` still match?

For a logic bug that only surfaces after many frames, stub `Window#show`, `load` the file, and call the window's `@update_proc` in a loop — then assert something real (positions NaN-free, a score that changed) rather than just "didn't raise". A bare `require 'ruby2d'` loads the installed gem, so run `rake` first if `lib/` changed.
