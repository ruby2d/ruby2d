# Ruby 2D Usage Guide

Ruby 2D is a 2D graphics library for creating applications, games, visualizations, and anything else you can imagine. This guide covers the complete public API.

## Table of Contents

- [Getting Started](#getting-started)
- [Window](#window)
- [Colors](#colors)
- [Shape Basics](#shape-basics)
- [Lines and Polygons](#lines-and-polygons)
- [Rectangles and Circles](#rectangles-and-circles)
- [Images](#images)
- [Text](#text)
- [Bitmap Text](#bitmap-text)
- [Sprites](#sprites)
- [Tilesets](#tilesets)
- [Canvas](#canvas)
- [Audio](#audio)
- [Button](#button)
- [Input Events](#input-events)
- [Gamepads](#gamepads)
- [Working with Objects](#working-with-objects)
- [Performance](#performance)
- [Building Native Applications](#building-native-applications)
- [Bundling Assets](#bundling-assets)
- [Building for the Web](#building-for-the-web)

## Getting Started

```ruby
require 'ruby2d'

set title: 'My App'
set background: 'navy'

Square.new(x: 50, y: 50, size: 100, color: 'red')

show
```

Ruby 2D provides two usage patterns:

- **DSL pattern** — Top-level methods (`set`, `on`, `update`, `show`, etc.) for quick scripts.
- **Class pattern** — Subclass `Ruby2D::Window` for structured applications with polling-based input.

### DSL Methods

When you `require 'ruby2d'`, these methods are available at the top level:

| Method | Description |
|---|---|
| `set(opts)` | Set window attributes |
| `get(sym)` | Get a window attribute by name (e.g. `:width`, `:mouse_x`, `:window`) |
| `on(event, &block)` | Register an event handler; returns an `EventDescriptor` |
| `off(descriptor)` | Remove a previously registered event handler |
| `update { }` | Set the update callback (called every frame) |
| `render { }` | Set the render callback (called every frame after update) |
| `elapsed` | Monotonic seconds since the engine started (timing, cooldowns, scheduling) |
| `clear` | Remove all objects from the window |
| `screenshot(path = nil)` | Save a screenshot to `path`, or a timestamped file if omitted |
| `show` | Open the window and start the main loop |
| `close` | Close the window immediately |
| `request_render` | Request a frame on the next tick (for `render_mode: :on_demand`) |

To use Ruby 2D classes without the DSL mixin, `require 'ruby2d/core'` instead.

### Window Class Pattern

For structured applications, subclass `Ruby2D::Window`:

```ruby
require 'ruby2d/core'

class Game < Ruby2D::Window
  include Ruby2D  # so shape names like Square resolve without the Ruby2D:: prefix

  def initialize
    super(title: 'My Game', width: 800, height: 600)
    @player = Square.new(x: 100, y: 100, size: 50, color: 'blue')
  end

  def update
    @player.x += 1 if key_held?('right')
    @player.x -= 1 if key_held?('left')
  end
end

Game.new.show
```

`require 'ruby2d/core'` loads the classes under the `Ruby2D` namespace without the top-level mixin that `require 'ruby2d'` adds, so reference shapes as `Ruby2D::Square`, or `include Ruby2D` in your class, as above, to drop the prefix. Override `update` (and/or `render`); each is called every frame independently, so overriding just one is fine.

The class pattern provides polling-based input methods (`key_pressed?`, `key_held?`, `key_released?`, `mouse_pressed?`, `mouse_held?`, `mouse_released?`, plus per-`Gamepad` polling; see [Gamepads](#gamepads)) for use inside `update`, in place of the DSL's `on` event handlers.

## Window

Ruby 2D is **single-window by design**. The window is created automatically the first time you use the DSL (`set`, `on`, a shape, `show`, …) or when you call `Window.new` (or `.new` on a `Window` subclass). Only one window can exist at a time; constructing a second one raises `Ruby2D::Error`. Both usage patterns share this single window, which is why the top-level DSL and the `Window.*` class methods always act on it.

### Setting Window Attributes

```ruby
set title: 'My App'
set width: 800, height: 600
set background: 'navy'
set fps_cap: 60
set icon: 'icon.png'
set resizable: true
set highdpi: true
set pixel_scale: true
set viewport_width: 320, viewport_height: 240
set viewport: :letterbox
set render_mode: :on_demand  # or :continuous (default)
set cursor: :hidden  # or :visible, :pointer, :crosshair, etc.
set show_fps: true
set diagnostics: true
set close_on_esc: true
```

| Option | Type | Default | Description |
|---|---|---|---|
| `title` | String | `'Ruby 2D'` | Window title bar text |
| `width` | Integer | `640` | Window width in pixels |
| `height` | Integer | `480` | Window height in pixels |
| `background` | Color | Black | Window background color |
| `icon` | String | `nil` | Path to a window icon image |
| `fps_cap` | Number/`:infinity`/nil | `nil` | Frame-rate limit: `nil` = no cap (vsync-driven), a positive number caps at that rate, `:infinity` (or `Float::INFINITY`) renders uncapped. `0`/negative is invalid — the constructor raises, `set` warns and falls back to `nil`. In the browser, a numeric cap snaps to the nearest achievable rate — the display refresh divided by a whole number (e.g. 120Hz → 60, 40, 30…) |
| `resizable` | Boolean | `false` | Whether the window can be resized |
| `highdpi` | Boolean | `true` | Enable high-DPI rendering (fixed at window creation; cannot change after `show`) |
| `pixel_scale` | Boolean | `false` | Scale rendering to match pixel density |
| `viewport_width` | Integer | Same as `width` | Drawable area width |
| `viewport_height` | Integer | Same as `height` | Drawable area height |
| `viewport` | Symbol | `:letterbox` | How the viewport scales when the displayed size differs from the logical size (see [Viewport](#viewport)) |
| `render_mode` | Symbol | `:continuous` | `:continuous` or `:on_demand` (see [Render Mode](#render-mode)) |
| `scale_mode` | Symbol | `:linear` | How textures are sampled when drawn at a size other than their own (see [Scale Mode](#scale-mode)) |
| `cursor` | Symbol | `:visible` | `:visible`, `:hidden`, or a system cursor name (see [Cursor Control](#cursor-control)) |
| `show_fps` | Boolean | `false` | Display an FPS counter |
| `diagnostics` | Boolean | `false` | Print diagnostic (`[INFO]`) messages; also displays the FPS counter (implies `show_fps`) |
| `close_on_esc` | Boolean | `false` | Close the window when Escape is pressed |

These can be set before `show` or changed live afterward — `set title:`, `set width:`/`height:`, `set resizable:`, `set viewport_width:`/`viewport_height:`, and the rest take effect immediately. The one exception is `highdpi`, fixed when the window is created; `pixel_scale` can be toggled live but only has an effect when `highdpi` is enabled.

### Pixel Scale

With `pixel_scale: true`, the drawable coordinate space maps 1:1 with physical pixels. On a 2× Retina display, a 640×480 window exposes a 1280×960 coordinate space.

```
Window.width / Window.height             →  logical window size  (e.g. 640×480)
Window.viewport_width / viewport_height  →  physical pixel space (e.g. 1280×960)
```

Key rules:

- **Pass logical pixels to `set`.**  `width` and `height` are always in logical pixels, regardless of `pixel_scale`.
- **Use `viewport_width`/`viewport_height` to size things that fill the window.**  These reflect the physical pixel drawable area when `pixel_scale: true`. They are only correct after `show` starts, so create full-viewport objects in the `update` loop on the first frame:

  ```ruby
  set width: 640, height: 480, pixel_scale: true

  canvas = nil

  update do
    next if canvas
    canvas = Canvas.new(width: Window.viewport_width, height: Window.viewport_height)
  end

  show
  ```

- **Use `display_width`/`display_height` to fill the display.**  These return the display size in logical pixels — the right unit to pass to `set`:

  ```ruby
  set width: Window.display_width, height: Window.display_height, pixel_scale: true
  ```

- **`display_pixel_width`/`display_pixel_height` are informational.**  They return the display size in physical pixels, useful for knowing raw pixel counts but not for passing to `set`.

> **Known limitation.** The content scale is fixed when the window opens. Dragging a running window to a monitor with a different pixel density (e.g. from a Retina display to a non-Retina one) does not re-scale the rendering; content keeps drawing at the original monitor's density until the window is reopened.

### Viewport

The `viewport:` mode controls how the fixed logical drawing area (`viewport_width` × `viewport_height`) is mapped onto the window whenever the two differ: on resize, on a HiDPI display, or with `pixel_scale`. Pass it to `set viewport: …`:

| Mode | Behavior |
|---|---|
| `:letterbox` | (default) Scale to fit, preserving aspect ratio; uncovered area shows as letterbox bars. |
| `:stretch` | Scale to fill the window, ignoring aspect ratio (content may distort). |
| `:integer` | Scale by whole-number multiples only, preserving aspect ratio (may leave a border). Constrains the frame, not how textures are sampled inside it, so pair it with `scale_mode:` for crisp pixel art. |
| `:overscan` | Scale to fill the window preserving aspect ratio, cropping whatever overflows. |
| `:expand` | Don't scale a fixed canvas — grow the logical drawing area to match the window, so more content becomes visible as it grows. `viewport_width`/`viewport_height` track the window size. |
| `:fixed` | No scaling; draw the viewport 1:1 and center it in the window. |

### Scale Mode

When an image is drawn at a size other than its own (scaled up, scaled down, or rotated), `scale_mode:` decides how its pixels are sampled. The default smooths, which is wrong for pixel art:

| Mode | Behavior |
|---|---|
| `:linear` | (default) Blend between neighboring pixels. Smooth, and blurry when magnified. |
| `:nearest` | Take the closest pixel. Hard edges at every scale: the classic pixel-art look. |
| `:pixel_art` | Nearest at whole-number scales, antialiased at fractional ones. Use when the scale isn't an integer, such as a letterboxed window. Needs a GPU renderer; on a software fallback it behaves as `:nearest`. |

Set it window-wide so an entire pixel-art game is covered by one line:

```ruby
set scale_mode: :nearest
```

Any object can override the window:

```ruby
set scale_mode: :nearest                              # crisp by default
Image.new('logo.png', scale_mode: :linear)            # …but smooth this one
```

Objects that don't set their own follow the window, and both ends are re-read every frame, so changing either takes effect on the next frame, including for objects that already exist.

`scale_mode:` is accepted by `Image`, `Sprite`, `SpriteSheet`, `Tileset`, `Canvas`, `Text`, and `BitmapText`, and each exposes a matching `scale_mode` accessor. Shapes draw as flat-colored geometry with no texture to sample, so they don't take it.

Per class:

- **`Tileset`** is the common case for `:nearest`. `scale:` multiplies tiles on the way to the screen, so a 16×16 tile at `scale: 3` is the GPU magnifying by 3.
- **`SpriteSheet`** passes its mode to every `Sprite` built from it; a `Sprite` can still override its own. The sheet's texture is shared, but each sprite is sampled with its own mode.
- **`Image#resize!`** and **`Canvas#draw_image`** resample on the CPU rather than the GPU. They follow the source image's mode, so a `:nearest` image stays crisp through either. `:pixel_art` has no CPU equivalent and behaves as `:nearest` on these two paths.
- **`BitmapText`** already renders its glyph grid at the target size, so its mode only matters when the window itself rescales the frame: a letterboxed `viewport:`, or `pixel_scale` on a HiDPI display.

#### Pixel art

Picking a scale mode is a separate decision from picking a coordinate system, and a pixel-art game makes both. Two common layouts:

**Draw in art pixels.** Fix the viewport to the art's resolution and let the renderer scale the whole frame to the window. Game logic is written in art pixels, so a 16×16 tile is 16 units wide however large the window gets:

```ruby
set width: 1280, height: 720, viewport_width: 320, viewport_height: 180,
    viewport: :integer, scale_mode: :nearest
```

**Draw in screen pixels.** Leave the viewport matching the window and size things up yourself, with `Tileset`'s `scale:` or an image's `width:`/`height:`:

```ruby
set width: 1280, height: 720, scale_mode: :nearest
Tileset.new('tiles.png', tile_width: 16, tile_height: 16, scale: 4)
```

Either way it's `scale_mode:` that keeps the pixels hard — the viewport decides the coordinate space, not how textures are sampled within it. Pair `viewport: :integer` with `:nearest` for uniform pixels, or reach for `:pixel_art` when the scale can't be a whole number, as in a resizable or letterboxed window.

### Reading Window Attributes

```ruby
get :title
get :width
get :height
get :fps
get :fps_cap
get :frames
get :mouse_x
get :mouse_y
get :display_width         # display size in logical pixels
get :display_height
get :display_pixel_width   # display size in physical pixels
get :display_pixel_height
get :window                # returns the Window instance itself
```

All readable attributes are also available as methods on the `Window` class:

```ruby
Window.width
Window.height
Window.fps
Window.mouse_x
Window.mouse_y
Window.display_width         # display size in logical pixels
Window.display_height
Window.display_pixel_width   # display size in physical pixels
Window.display_pixel_height
```

### Screenshots

```ruby
screenshot './my_screenshot.png'  # save to a specific path
screenshot                        # auto-generated timestamped filename

Window.screenshot './my_screenshot.png'  # also available on the Window class
```

The file is written at the end of the frame it was requested in, so `screenshot` returns the path before the file exists; it's on disk by the time the next `update` runs. Requesting one forces that frame to render, so a capture in `:on_demand` mode never grabs a parked frame, and this saves the image even though it closes the window in the same tick:

```ruby
update do
  screenshot './my_screenshot.png'
  close
end
```

Taking a screenshot after the window has closed raises, since no frame is left to write it.

On [the web](#building-for-the-web), `screenshot` does nothing and returns `nil`: the only filesystem there is Emscripten's in-memory one, so it could only write a file nobody can open.

### Cursor Control

```ruby
set cursor: :hidden
set cursor: :visible

# Or directly:
Window.cursor = :visible
Window.cursor = :hidden
Window.cursor  # => :default, :hidden, :pointer, etc.
```

`:visible` is a set-only convenience meaning "show the default arrow"; after setting it, the getter reports the active style (`:default` for a plain visible cursor, or a system-cursor name) or `:hidden`, never `:visible`.

#### System Cursors

Set the cursor to any system cursor style by passing its name to `set cursor:`:

```ruby
set cursor: :pointer      # pointing hand (links)
set cursor: :text         # I-beam (text fields)
set cursor: :crosshair    # crosshair
set cursor: :wait         # hourglass / spinner
set cursor: :progress     # busy with arrow
set cursor: :move         # four-way arrow
set cursor: :not_allowed  # slashed circle
set cursor: :default      # default arrow

# Resize cursors
set cursor: :ew_resize    # horizontal double arrow
set cursor: :ns_resize    # vertical double arrow
set cursor: :nwse_resize  # diagonal double arrow (NW–SE)
set cursor: :nesw_resize  # diagonal double arrow (NE–SW)
set cursor: :n_resize     # edge resize: north
set cursor: :ne_resize    # edge resize: north-east
set cursor: :e_resize     # edge resize: east
set cursor: :se_resize    # edge resize: south-east
set cursor: :s_resize     # edge resize: south
set cursor: :sw_resize    # edge resize: south-west
set cursor: :w_resize     # edge resize: west
set cursor: :nw_resize    # edge resize: north-west

# Also available as a direct setter:
Window.cursor = :pointer
```

### Update Loop

The `update` block runs every frame and is the place to put application logic — updating state, responding to input, animating objects:

```ruby
update do
  @box.x += 1
end

show
```

The loop runs at the display refresh rate, or up to `fps_cap` if one is set. To run uncapped — no frame limit, useful for benchmarking — set `fps_cap: :infinity`.

#### Frame-rate independence with `dt`

The block above moves the box by 1 pixel per frame, which means it travels at 60 px/s on a 60Hz display but 120 px/s on a 120Hz display. To make motion behave the same regardless of refresh rate, accept a `dt` argument — wall-clock seconds since the previous update — and scale by it:

```ruby
update do |dt|
  @box.x += 60 * dt   # always 60 px/s, on any display
end
```

`dt` is also available as `Window#delta_time` for the class pattern:

```ruby
class MyApp < Ruby2D::Window
  def update
    @box.x += 60 * delta_time
  end
end
```

`dt` is `0.0` on the first frame and is clamped to a maximum of `0.1` seconds, so a paused window or stalled frame won't cause the next update to leap forward dramatically.

> **Use `dt`/`elapsed` for timing, not the system clock.** The native and web builds run on mruby, where the usual Ruby clocks don't port: `Process.clock_gettime` doesn't exist, and `Time.now` is a coarse wall clock whose millisecond-since-epoch values overflow mruby's 32-bit integers in the browser. Scale per-frame motion by the `dt` arg (also `Window#delta_time`); for absolute time — cooldowns, scheduling, "time since" — read `elapsed` (monotonic seconds since the engine started). Both are cross-platform and overflow-safe. Save `Time.now` for wall-clock dates.

#### Absolute time with `elapsed`

`elapsed` returns monotonic seconds since the engine started. Reach for it when `dt` is awkward — most often a cooldown or "every N seconds" check inside an event handler, which gets no `dt`:

```ruby
# Fire at most once every 0.5s, even on rapid clicks:
on :mouse_down do
  next unless elapsed >= (@next_shot || 0)
  shoot
  @next_shot = elapsed + 0.5
end
```

It starts near `0` when the program launches, never ticks backward, and reads the same on CRuby and the mruby/web builds. For frame-to-frame motion, prefer `dt`.

### Render Block

The `render` block also runs every frame, immediately after `update`. Use it for one-off drawing with `.render` methods:

```ruby
render do
  Rectangle.render(x: 0, y: 0, width: 50, height: 50, color: 'red')
end
```

Objects created with `.new` are rendered automatically; the `render` block is only needed when you want per-frame custom drawing. For scenes that redraw many things every frame, persistent objects are cheaper; see [Performance](#performance).

By default the block draws **on top of every object**; it is the frontmost layer. Pass `z:` to place it elsewhere in the scene's [z-order](#managing-objects):

```ruby
render do … end                # :foreground (default), on top of all objects
render z: :background do … end # behind all objects
render z: 10 do … end          # interleaved at that depth (same scale as object z)
```

For a number, objects with `z` at or below it draw first, then the block, then the rest. This is how a persistent HUD sits above per-frame drawing: put backdrop objects at a low `z`, draw the world in a `render z: 10` block, and keep the HUD objects at a higher `z` (say `20`) so they stay on top.

> **Two `render`s, same word.** `render do … end` (a block) *registers* the callback shown above. `Shape.render(…)` (a method call) *draws* a single frame inside that callback. The first sets up the loop; the second runs inside it.

### Render Mode

Ruby 2D supports two rendering modes that control when the window presents frames:

- **`:continuous`** (default) — the window renders every tick up to `fps_cap`. Right for games and anything with continuous animation.
- **`:on_demand`** — the window only presents a frame when `request_render` is called or when the OS signals a redraw (resize, expose, display change). Input, `update`, and frame pacing still run every tick, so the app remains responsive.

On-demand mode lets the GPU reach its deepest sleep state when nothing is changing on screen, useful for charts, editors, dashboards, and other non-game GUIs where the contents only change in response to input.

```ruby
set render_mode: :on_demand

on :mouse_down do
  @clicked = true
  request_render  # explicitly ask for the next frame
end

show
```

Things to know:

- **The first frame is always rendered.** You don't need to call `request_render` for the window to appear.
- **Animations are opt-in.** A blinking caret, spinner, or fade-out needs to call `request_render` on whatever cadence you want; if nothing asks for frames, frames stop.
- **`request_render` is thread-safe** and idempotent within a tick. Calling it multiple times before the next frame has no extra cost.
- **`Canvas` mutations auto-request a render.** Every `Canvas#fill_*`, `Canvas#stroke_*`, `Canvas#draw_*`, and `Canvas#clear` call marks the next frame dirty for you, so you don't need `request_render` after canvas drawing. Mutating shape attributes (`rect.x = 100`, etc.) does *not*; call `request_render` yourself for those.
- **`show_fps` / `diagnostics` counters freeze in `:on_demand` mode** because the overlay is drawn as part of the frame. FPS is not meaningful when rendering is demand-driven.

### Closing the Window

Call `close` to shut down the window immediately:

```ruby
close
```

To run code just before the window closes — whether the user clicks the OS close button or `close` is called — register a handler with `on(:close)`:

```ruby
on :close do
  puts 'Goodbye!'
end
```

Unlike keyboard and mouse events, only one `:close` handler can be registered at a time. Registering a new one replaces the previous. You can also remove it explicitly:

```ruby
handler = on :close do
  puts 'Goodbye!'
end

off handler
```

`close` and `on(:close)` work together: calling `close` fires the handler before shutting down.

On [the web](#building-for-the-web), `close` does nothing: a page can't close itself, only the person viewing it can. The handler isn't run and the app keeps going, so anything you'd put after a `close` — a farewell screen, a final score — should be drawn instead of waited for. A quit the viewer initiates still fires `on(:close)`.

## Colors

Colors can be specified as:

- **Named color**: `'red'`, `'blue'`, `'green'`, etc.
- **Hex string**: `'#FF0000'`, `'#F00'`, `'#FF000080'` (with alpha)
- **Color array**: `[r, g, b]` or `[r, g, b, a]`, with each channel a number on the 0.0–1.0 scale (`[1.0, 0.5, 0.0]`). Alpha is optional and defaults to opaque. For 0–255 byte values, use a hex string instead.
- **`'random'`**: Generates a random color
- **Color object**: `Color.new('red')`

Channels are plain numbers on the 0.0–1.0 scale, the standard graphics convention, so `[1, 0, 0]` is full-intensity red and `[0, 0, 0]` is black; integer `0` and `1` work as the endpoints. Out-of-range channels emit a one-time warning and are clamped into range.

### Named Colors

Based on [clrs.cc](https://clrs.cc): `navy`, `blue`, `aqua`, `teal`, `olive`, `green`, `lime`, `yellow`, `orange`, `red`, `brown`, `fuchsia`, `purple`, `maroon`, `white`, `silver`, `gray`, `black`.

### Color Class

```ruby
c = Color.new('red')
c = Color.new('#FF0000')
c = Color.new([1.0, 0.0, 0.0])       # rgb (0.0–1.0)
c = Color.new([1.0, 0.0, 0.0, 1.0])  # rgba (0.0–1.0)

c.r        # => red component (always stored as 0.0..1.0)
c.g        # => green component
c.b        # => blue component
c.a        # => alpha component
c.opacity  # => alias for .a
c.opacity = 0.5
c.to_a     # => [r, g, b, a]

Color.valid?('red')    # => true
Color.hex?('#FF0000')  # => true
```

> **Note**: `colour` is accepted as a synonym for `color` everywhere, including compound kwargs (`stroke_colour`, `hover_colour`, `label_colour`).

> **Tip**: Color strings (names and hex) are parsed once and cached internally, so passing `color: 'red'` on a hot path is effectively as fast as passing a pre-built `Color`. You don't need to hoist `Color.new('red')` out of the loop to avoid parse overhead.

### Per-Vertex Colors

Shapes that support per-vertex coloring accept an array of colors, one per vertex:

```ruby
Triangle.new(
  color: ['red', 'green', 'blue']  # one per vertex
)
```

The array length must match the shape's vertex count: 3 for `Triangle`, 4 for `Quad` / `Rectangle` / `Square`, N for `Polygon` / `Polyline` (matching `points`). `Circle` and `Ellipse` are single-color only. `Line` is the special case: its array is 2 colors `[start, end]` for a gradient along the length.

Reading `color` back returns the same kind you set: a `Color` for a uniform fill, or a `Color::Set` for a per-vertex / gradient fill. Index a set's individual stops with `color.vertex(i)`, and `color.opacity` reports the first vertex's alpha (see [Opacity](#opacity)).

### Opacity

All renderable objects support opacity through the `opacity:` keyword:

```ruby
Square.new(x: 0, y: 0, size: 100, color: 'red', opacity: 0.5)
```

Read or change it after creation with the `opacity` accessor:

```ruby
shape.opacity  # => 0.5
shape.opacity = 0.25
```

For per-vertex fills, the getter returns the alpha of the first color, and the setter assigns the same alpha to every vertex. The underlying `shape.color.opacity = ...` form still works if you need it.

On stroked shapes (`Circle`, `Ellipse`, `Triangle`, `Quad`, `Polygon`), both `opacity:` at construction and the `opacity=` setter fade the fill **and** the stroke together. To fade them independently, set each color's opacity directly:

```ruby
shape.color.opacity = 0.25        # fill only
shape.stroke_color.opacity = 1.0  # stroke only
```

`Polyline` and `Canvas#draw_polyline` also accept a per-vertex `opacity:` array (one value per vertex), interpolated along the path the same way per-vertex `color:` is:

```ruby
Polyline.new(
  points: [[50, 200], [150, 150], [250, 200], [350, 120]],
  stroke_width: 3, color: 'orange',
  opacity: [1.0, 1.0, 1.0, 0.35]
)
```

When `opacity:` is a single value, all vertices share it. When it's an array, each entry overrides the alpha of the corresponding vertex. The array length must equal the vertex count.

Opacity is clamped to the `0.0..1.0` range. A fade animation that momentarily overshoots (e.g. `opacity = 1.2` or `-0.1`) is pinned to fully opaque or fully transparent for that frame rather than raising, consistent with how runtime size setters degrade gracefully (see [Dimensions](#dimensions)).

## Shape Basics

Common properties and patterns shared by every shape (`Line`, `Triangle`, `Quad`, `Rectangle`, `Square`, `Circle`, `Ellipse`, `Polygon`, `Polyline`). For each shape's full parameter list and examples, see [Lines and Polygons](#lines-and-polygons) and [Rectangles and Circles](#rectangles-and-circles).

All shapes are automatically added to the window when created. Every shape includes the `Renderable` module and shares these common features:

```ruby
shape.x        # x position
shape.y        # y position
shape.z        # depth (drawing order); higher z is drawn on top
shape.z = 10   # changing z re-inserts the object in the correct order
shape.width    # width  (bounding-box extent; e.g. a Circle's diameter)
shape.height   # height (bounding-box extent)
shape.color    # the color or color set
shape.color = 'blue'
shape.opacity  # alpha of the color (per-vertex fills return the first vertex's alpha)
shape.opacity = 0.5
shape.add      # add to the window (done automatically on creation)
shape.remove   # remove from the window
shape.contains?(x, y)  # hit-testing
```

### Dimensions

Size parameters — `width`, `height`, `radius`, `xradius`, `yradius`, `size` — must be **zero or positive**. A negative value at construction raises `ArgumentError`, because a negative extent still renders but disagrees with `contains?` hit-testing. Zero is allowed (the shape collapses to a point).

Runtime setters (`circle.radius = …`, `rect.width = …`) are deliberately **not** guarded, so an animation whose size momentarily dips below zero won't raise mid-run. The frame still renders: a negative extent draws a mirrored shape rather than nothing, and it won't agree with `contains?` hit-testing. Keep animated dimensions non-negative for predictable rendering.

### Anchor Point (`x`, `y`)

What `shape.x` / `shape.y` mean depends on how the shape is defined:

- **Vertex-defined shapes** — `Triangle`, `Quad`, `Polygon`, `Polyline` — `x`/`y` is the **centroid** (the average of the vertex coordinates). Setting `tri.x = 100` translates every vertex by the same offset to move the centroid to that x.
- **Bounding-box shapes** — `Rectangle`, `Square`, `Image`, `Text`, `BitmapText`, `Sprite`, `Canvas` — `x`/`y` is the **top-left corner**. Setting `rect.x = 100` moves the rectangle so its left edge is at 100.
- **Center-defined shapes** — `Circle`, `Ellipse` — `x`/`y` is the **center**. Setting `circle.x = 100` moves the center to 100.

Rotation defaults to the shape's natural center: the centroid for vertex-defined shapes, the bounding-box center for bounding-box shapes, and the anchor itself for center-defined shapes. Override with `rx:` / `ry:` at construction or via the accessors.

### Fill and Stroke

All closed shapes (`Triangle`, `Quad`, `Rectangle`, `Square`, `Circle`, `Ellipse`, `Polygon`) support both fill and stroke. By default shapes are filled; pass `stroke_width:` to add an outline.

```ruby
# Filled (default)
Rectangle.new(x: 10, y: 10, width: 100, height: 50, color: 'red')

# Filled + outlined
Rectangle.new(x: 10, y: 10, width: 100, height: 50,
              color: 'red', stroke_width: 3, stroke_color: 'white')

# Outline only
Rectangle.new(x: 10, y: 10, width: 100, height: 50,
              fill: false, stroke_width: 3, stroke_color: 'white')
```

| Parameter | Default | Description |
|---|---|---|
| `fill` | `true` | Whether to fill the shape |
| `stroke_width` | `0` | Outline thickness in pixels (0 = no outline) |
| `stroke_color` | Fill color | Outline color (single or per-vertex array matching the shape's vertex count) |

Notes:
- `stroke_color` defaults to the fill color. If the fill is per-vertex, the stroke gets the same per-vertex set so the outline traces the same gradient around the perimeter. Set it explicitly when you want a different outline color.
- `stroke_color:` accepts the same per-vertex vocabulary as `color:`; each vertex gets one color and pixels along each edge interpolate between the two endpoint colors. `Circle` and `Ellipse` strokes are single-color only.
- `opacity:` applies to both fill and stroke when both are drawn.
- Strokes rendered on persistent shapes use the same geometry as Canvas `stroke_*` methods, so a scene-graph outline and a Canvas outline of the same shape line up pixel-for-pixel (with minor anti-aliasing differences).
- Strokes are **centered on the shape boundary**: half the stroke width falls inside the shape, half outside. On a Canvas, any portion that falls outside the surface bounds is clipped; on persistent shapes, it renders freely to the window. Inset Canvas-drawn shapes by `stroke_width / 2` if you want the full stroke visible.
- `Line` and `Polyline` are always strokes; `fill:`, `stroke_color:`, and the fill-specific semantics do not apply to them.

### Rotation

Every shape supports rotation via the `rotate` attribute (in degrees), with one exception: a `Tileset` has no whole-object `rotate` — a grid of tiles has no single pivot, so its tiles rotate individually, per tile type, through `define(..., rotate:)`. The rotation center defaults to the shape's natural center but can be overridden with `rx` and `ry`:

```ruby
rect = Rectangle.new(x: 100, y: 100, width: 50, height: 50, rotate: 45)
rect.rotate = 90
rect.rx = 0  # rotate around the origin instead
rect.ry = 0
```

`contains?` (and the object events built on it: `:click`, `:hover`, `:drag`, …) respects rotation: the clickable region matches the rotated shape you see, not its unrotated footprint. It tests against the **rendered fill**: for `Triangle`, `Quad`, and `Polygon` that's the filled area. For `Line` and `Polyline` it matches the drawn stroke, within half the stroke width along each segment, mitered at the corners, and butt-capped at the open ends (so it doesn't extend past them). A `Triangle` is always convex and hit-tests exactly against what's drawn, as do convex and concave `Quad`s and `Polygon`s. Only self-intersecting `Quad`s and `Polygon`s are unreliable: the fill renderer doesn't fully support them (it may draw only part of the shape), so `contains?` may not match the drawn pixels there; use `Polyline.new(closed: true)` plus `Canvas#fill_polygon` for such shapes. Points exactly on an edge follow the rasterized boundary (the lower/left edges count as inside, the upper/right edges as outside).

### One-Shot Rendering

Shapes provide a class-level `.render` method for one-off drawing inside the window's `render do … end` block, which fires every frame after `update`. The block *registers* a callback; `Shape.render(…)` *draws* a single frame inside it. Arguments mirror `.new`'s visual and geometry kwargs: same defaults, same color vocabulary (names, hex, arrays, `Color`, per-vertex). Because a one-shot draw has no persistent object to order, register, or align, `.render` omits the scene-graph and lifecycle kwargs `.new` accepts (`z:`, `add:`, `visible:`, and the `padding*` keywords):

```ruby
render do
  Rectangle.render(x: 0, y: 0, width: 50, height: 50, color: 'red')
  Circle.render(x: 100, y: 100, radius: 25, color: 'green', opacity: 0.5)
end
```

`.render` produces no object: no per-object events, no `contains?`, no `z` ordering. Use `.new` when you need any of those.

#### Why only shapes have class-level `.render`

`Image`, `Text`, `BitmapText`, `Sprite`, `Canvas`, and `Tileset` **do not** offer a class-level `.render` (no `Image.render(...)`, no `Text.render(...)`). That's intentional. Shapes are cheap to describe per frame: a few coordinates and colors pushed straight to the GPU. Textured and text objects, by contrast, own a texture, glyph atlas, or pixel buffer that's expensive to build. Recreating that on every frame would be wasteful.

Their pattern is "construct once, render many" — build the object with `add: false` to keep it out of the scene graph, then call `instance.render(...)` with per-frame overrides inside your `render` block:

```ruby
label = BitmapText.new('FPS', add: false)
img   = Image.new('hero.png', add: false)

render do
  label.render(x: 10, y: 10, color: 'lime')
  img.render(x: Window.mouse_x, y: Window.mouse_y)
end
```

The texture/atlas is built once when `.new` runs, then reused on each `.render` call. This gives you the same "no persistent object" effect as shapes' class-level `.render`, without rebuilding expensive state per frame.

### Construction-time `add:` and `visible:`

Every renderable accepts `add:` and `visible:` at construction (both default to `true`). `add: false` builds the object without registering it in the window's scene graph, useful for entities you'll spawn later, or for the render-block override pattern (see [Images](#images), [Text](#text), etc., below) where you draw the object yourself each frame via `instance.render(...)`. `visible: false` keeps the object in the scene graph but skips drawing it.

An `add: false` object is not drawn, so it also doesn't receive object events (`:click`, `:hover`, …) even if you attach handlers; it isn't part of the scene until you `add` it. A hidden object (`visible: false`) stays in the scene graph and keeps receiving events. For an invisible-but-clickable region, use a [visual-less `Button`](#visual-less-button-hit-area).

```ruby
powerup = Square.new(x: 200, y: 200, size: 32, color: 'yellow', add: false)
powerup.add  # later, when the player triggers the spawn condition
```

For runtime toggling (`.add` / `.remove` for scene-graph membership and `.show` / `.hide` for visibility), see [Managing Objects](#managing-objects).

### Aligning to the window

Pass a symbol to `x:` or `y:` to align an object against the window instead of computing pixels:

```ruby
Text.new('Paused', x: :center, y: :center)
Image.new('logo.png', x: :right, y: :top)
Rectangle.new(x: :center, y: :bottom, width: 200, height: 40)
```

Accepted values: `:left`, `:center`, `:right` for `x`; `:top`, `:center`, `:bottom` for `y`. Resolution happens at draw time against `Window.viewport_width` / `viewport_height` and the object's own measured `width` / `height`, so a `:center`-aligned `Text` re-centers automatically when its `content` changes, and any aligned object follows window resizes.

`obj.x` and `obj.y` return the resolved numeric position (so hit-testing, `contains?`, and event handlers work normally). The intent is exposed separately as `obj.x_align` and `obj.y_align`. Assigning a number explicitly (`text.x = 100`) clears the alignment intent; assigning a symbol (`text.x = :center`) sets it, and so does `text.x_align = :center`.

This works for every shape with a well-defined bounding box: `Text`, `Rectangle`, `Square`, `Circle`, `Ellipse`, `Image`, `Sprite`, and `Button`. For the center-anchored `Circle` and `Ellipse`, the bounding box is aligned just like a rectangle's — `:left` puts the left edge against the wall, `:center` centers it — and the anchor (the center) follows. Shapes with no edge to hug don't support symbolic alignment: the centroid-anchored `Quad`, `Triangle`, `Polygon`, and `Polyline`, plus the pixel-buffer `Canvas` and `BitmapText`. Passing a symbol to their `x` / `y` raises a clear error rather than guessing; use `Text` for aligned text. A free-form `Line` has no `x` / `y` at all; it's positioned through its endpoints `x1` / `y1` / `x2` / `y2`.

#### Padding

Inset an aligned object from the edge it's anchored to:

```ruby
Text.new('Score: 0', x: :right, y: :top, padding: 16)  # 16px from top and right
Button.new(x: :center, y: :bottom, padding_bottom: 24, label: 'Start')
```

`padding:` sets all four edges. Per-edge kwargs (`padding_top`, `padding_right`, `padding_bottom`, `padding_left`) override the uniform value for individual edges. Padding only takes effect on edge-anchored axes; it's a no-op for `:center` and for axes with a numeric position. Negative values are allowed (the object pushes past the edge). All four are also runtime accessors (`obj.padding_top = 8`).

> **Timing.** Aligned positions are `0` until the first frame draws, because the window's viewport dimensions are only known once `show` starts. If you read `obj.x` before the first render, you'll see the placeholder.

## Lines and Polygons

Vertex-defined shapes. For `Triangle`, `Quad`, `Polygon`, and `Polyline`, `x` / `y` refer to the **centroid** — the average of the vertex coordinates — and setting `x=` translates every vertex by the same offset. `Line` is the exception: it has no `x`/`y` and is positioned through its endpoints `x1`/`y1`/`x2`/`y2`. For fill / stroke, rotation, alignment, and other common properties, see [Shape Basics](#shape-basics).

### Line

```ruby
Line.new(x1: 0, y1: 0, x2: 100, y2: 100)
# or:
Line.new(points: [[0, 0], [100, 100]])
```

| Parameter | Default | Description |
|---|---|---|
| `points` | `nil` | `[[x, y], [x, y]]` — overrides the numbered kwargs if given |
| `x1` | `0` | Start x |
| `y1` | `0` | Start y |
| `x2` | `100` | End x |
| `y2` | `100` | End y |
| `z` | `0` | Depth |
| `stroke_width` | `1` | Line thickness |
| `dash` | `0` | Dash length in pixels (`0` = solid) |
| `gap` | `5` | Gap length in pixels (when dashed) |
| `rotate` | `0` | Rotation in degrees |
| `rx`, `ry` | Midpoint | Rotation center |
| `color` | `'white'` | Color (single, or 2-element array `[start, end]` for a gradient along the length; dashed lines interpolate endpoint colors per dash) |
| `opacity` | `nil` | Alpha override |
| `add` | `true` | Add to the window's scene graph on construction |
| `visible` | `true` | Initial visibility (drawn each frame while in the scene graph) |

**Example:**

```ruby
line = Line.new(x1: 0, y1: 0, x2: 200, y2: 200)
line.length  # => geometric length of the line
line.x1 = 50
line.stroke_width = 5

# Dashed line: set `dash:` (and optionally `gap:`) to opt in.
Line.new(x1: 10, y1: 50, x2: 400, y2: 50,
         dash: 15, gap: 8, stroke_width: 2, color: 'yellow')
```

### Triangle

```ruby
Triangle.new(x1: 50, y1: 0, x2: 100, y2: 100, x3: 0, y3: 100)
# or:
Triangle.new(points: [[50, 0], [100, 100], [0, 100]])
```

| Parameter | Default | Description |
|---|---|---|
| `points` | `nil` | `[[x, y], [x, y], [x, y]]` — overrides the numbered kwargs if given |
| `x1` | `50` | Vertex 1 x |
| `y1` | `0` | Vertex 1 y |
| `x2` | `100` | Vertex 2 x |
| `y2` | `100` | Vertex 2 y |
| `x3` | `0` | Vertex 3 x |
| `y3` | `100` | Vertex 3 y |
| `z` | `0` | Depth |
| `rotate` | `0` | Rotation in degrees |
| `rx`, `ry` | Centroid | Rotation center |
| `color` | `'white'` | Color (single or 3-element array for per-vertex) |
| `opacity` | `nil` | Alpha override |
| `fill` | `true` | Whether to fill (see [Fill and Stroke](#fill-and-stroke)) |
| `stroke_width` | `0` | Outline thickness |
| `stroke_color` | Fill color | Outline color |
| `add` | `true` | Add to the window's scene graph on construction |
| `visible` | `true` | Initial visibility (drawn each frame while in the scene graph) |

**Example:**

```ruby
tri = Triangle.new(x1: 50, y1: 0, x2: 100, y2: 100, x3: 0, y3: 100, color: 'green')
tri.x = 200  # translates all vertices (x and y refer to the centroid)
tri.color = 'red'
```

### Quad

A quadrilateral defined by four vertices in clockwise order.

```ruby
Quad.new(x1: 0, y1: 0, x2: 100, y2: 0, x3: 100, y3: 100, x4: 0, y4: 100)
# or:
Quad.new(points: [[0, 0], [100, 0], [100, 100], [0, 100]])
```

| Parameter | Default | Description |
|---|---|---|
| `points` | `nil` | `[[x, y], [x, y], [x, y], [x, y]]` (clockwise from top-left) — overrides the numbered kwargs if given |
| `x1`, `y1` | `0, 0` | Top-left vertex |
| `x2`, `y2` | `100, 0` | Top-right vertex |
| `x3`, `y3` | `100, 100` | Bottom-right vertex |
| `x4`, `y4` | `0, 100` | Bottom-left vertex |
| `z` | `0` | Depth |
| `rotate` | `0` | Rotation in degrees |
| `rx`, `ry` | Center of vertices | Rotation center |
| `color` | `'white'` | Color (single or 4-element array for per-vertex) |
| `opacity` | `nil` | Alpha override |
| `fill` | `true` | Whether to fill (see [Fill and Stroke](#fill-and-stroke)) |
| `stroke_width` | `0` | Outline thickness |
| `stroke_color` | Fill color | Outline color |
| `add` | `true` | Add to the window's scene graph on construction |
| `visible` | `true` | Initial visibility (drawn each frame while in the scene graph) |

**Example:**

```ruby
quad = Quad.new(x1: 0, y1: 0, x2: 80, y2: 0, x3: 100, y3: 100, x4: 20, y4: 100)
quad.x = 150  # translates all four vertices by the same offset
quad.color = ['red', 'green', 'blue', 'yellow']
```

### Polygon

A closed polygon defined by N ≥ 3 vertices supplied as `[[x, y], [x, y], ...]`. Supports single or per-vertex colors.

```ruby
Polygon.new(points: [[100, 50], [200, 100], [180, 200], [80, 200], [50, 120]])
```

| Parameter | Default | Description |
|---|---|---|
| `points` | (required) | Array of `[x, y]` pairs (N ≥ 3) |
| `z` | `0` | Depth |
| `rotate` | `0` | Rotation in degrees |
| `rx`, `ry` | Centroid | Rotation center |
| `color` | `'white'` | Single color, or per-vertex array of length N |
| `opacity` | `nil` | Alpha override |
| `fill` | `true` | Whether to fill (see [Fill and Stroke](#fill-and-stroke)) |
| `stroke_width` | `0` | Outline thickness |
| `stroke_color` | Fill color | Outline color |
| `add` | `true` | Add to the window's scene graph on construction |
| `visible` | `true` | Initial visibility (drawn each frame while in the scene graph) |

Polygon fills work best for convex and simple non-convex shapes. For complex concave shapes, use `Polyline.new(closed: true)` for the outline and `Canvas#fill_polygon` for the interior if a fill is needed.

**Example:**

```ruby
star = Polygon.new(
  points: [[100, 10], [120, 80], [190, 80], [130, 120], [150, 190],
           [100, 150], [50, 190], [70, 120], [10, 80], [80, 80]],
  color: 'yellow', stroke_width: 2, stroke_color: 'orange'
)
```

### Polyline

A stroke-only open or closed path of connected line segments. No fill.

```ruby
Polyline.new(points: [[50, 50], [150, 100], [250, 80], [350, 150]])
```

| Parameter | Default | Description |
|---|---|---|
| `points` | (required) | Array of `[x, y]` pairs (N ≥ 2) |
| `z` | `0` | Depth |
| `rotate` | `0` | Rotation in degrees |
| `rx`, `ry` | Centroid | Rotation center |
| `color` | `'white'` | Stroke color: a single color, or a per-vertex array of length `vertex_count` for a gradient along the path |
| `opacity` | `nil` | Alpha override: single value for all vertices, or an array of per-vertex values |
| `stroke_width` | `1` | Stroke thickness |
| `closed` | `false` | Connect the last point back to the first |
| `add` | `true` | Add to the window's scene graph on construction |
| `visible` | `true` | Initial visibility (drawn each frame while in the scene graph) |

**Example:**

```ruby
path = Polyline.new(
  points: [[50, 200], [100, 150], [150, 200], [200, 120], [250, 200]],
  stroke_width: 3, color: 'aqua'
)

# Closed polyline (just the outline; for a filled version, use Polygon)
outline = Polyline.new(
  points: [[100, 100], [200, 100], [200, 200], [100, 200]],
  stroke_width: 2, color: 'white', closed: true
)
```

## Rectangles and Circles

Anchor-defined shapes. `Rectangle` and `Square` use their **top-left corner** as the anchor; `Circle` and `Ellipse` use their **center**. Both groups support symbolic alignment (`x: :center`, etc.); see [Aligning to the window](#aligning-to-the-window). For fill / stroke, rotation, and other common properties, see [Shape Basics](#shape-basics).

### Rectangle

A rectangle (subclass of Quad).

```ruby
Rectangle.new(x: 0, y: 0, width: 200, height: 100)
```

| Parameter | Default | Description |
|---|---|---|
| `x` | `0` | Top-left x (or `:left`/`:center`/`:right`; see [Aligning to the window](#aligning-to-the-window)) |
| `y` | `0` | Top-left y (or `:top`/`:center`/`:bottom`) |
| `width` | `200` | Width |
| `height` | `100` | Height |
| `z` | `0` | Depth |
| `rotate` | `0` | Rotation in degrees |
| `rx`, `ry` | Center | Rotation center |
| `color` | `'white'` | Color (single or 4-element array for per-vertex) |
| `opacity` | `nil` | Alpha override |
| `fill` | `true` | Whether to fill (see [Fill and Stroke](#fill-and-stroke)) |
| `stroke_width` | `0` | Outline thickness |
| `stroke_color` | Fill color | Outline color |
| `add` | `true` | Add to the window's scene graph on construction |
| `visible` | `true` | Initial visibility (drawn each frame while in the scene graph) |
| `padding` | `0` | Inset from anchored edges (also `padding_top`/`padding_right`/`padding_bottom`/`padding_left`) |

**Example:**

```ruby
rect = Rectangle.new(x: 10, y: 10, width: 100, height: 50)
rect.width = 200
rect.height = 100
```

### Square

A square (subclass of Rectangle).

```ruby
Square.new(x: 0, y: 0, size: 100)
```

| Parameter | Default | Description |
|---|---|---|
| `x` | `0` | Top-left x (or `:left`/`:center`/`:right`; see [Aligning to the window](#aligning-to-the-window)) |
| `y` | `0` | Top-left y (or `:top`/`:center`/`:bottom`) |
| `size` | `100` | Side length |
| `z` | `0` | Depth |
| `rotate` | `0` | Rotation in degrees |
| `rx`, `ry` | Center | Rotation center |
| `color` | `'white'` | Color (single or 4-element array for per-vertex) |
| `opacity` | `nil` | Alpha override |
| `fill` | `true` | Whether to fill (see [Fill and Stroke](#fill-and-stroke)) |
| `stroke_width` | `0` | Outline thickness |
| `stroke_color` | Fill color | Outline color |
| `add` | `true` | Add to the window's scene graph on construction |
| `visible` | `true` | Initial visibility (drawn each frame while in the scene graph) |
| `padding` | `0` | Inset from anchored edges (also `padding_top`/`padding_right`/`padding_bottom`/`padding_left`) |

**Example:**

```ruby
sq = Square.new(x: 10, y: 10, size: 50)
sq.size = 75
```

### Circle

```ruby
Circle.new(x: 0, y: 0, radius: 50)
```

| Parameter | Default | Description |
|---|---|---|
| `x` | `0` | Center x (or `:left`/`:center`/`:right`; see [Aligning to the window](#aligning-to-the-window)) |
| `y` | `0` | Center y (or `:top`/`:center`/`:bottom`) |
| `z` | `0` | Depth |
| `radius` | `50` | Radius |
| `sectors` | `30` | Number of segments around the perimeter (higher = smoother) |
| `rotate` | `0` | Rotation in degrees |
| `rx`, `ry` | Center | Rotation center |
| `color` | `'white'` | Single color only |
| `opacity` | `nil` | Alpha override |
| `fill` | `true` | Whether to fill (see [Fill and Stroke](#fill-and-stroke)) |
| `stroke_width` | `0` | Outline thickness |
| `stroke_color` | Fill color | Outline color |
| `add` | `true` | Add to the window's scene graph on construction |
| `visible` | `true` | Initial visibility (drawn each frame while in the scene graph) |
| `padding` | `0` | Inset from anchored edges (also `padding_top`/`padding_right`/`padding_bottom`/`padding_left`) |

**Example:**

```ruby
circle = Circle.new(x: 200, y: 200, radius: 40, color: 'blue', sectors: 60)
circle.radius = 60
circle.color = 'purple'
```

### Ellipse

```ruby
Ellipse.new(x: 100, y: 100, xradius: 60, yradius: 30)
```

| Parameter | Default | Description |
|---|---|---|
| `x` | `0` | Center x (or `:left`/`:center`/`:right`; see [Aligning to the window](#aligning-to-the-window)) |
| `y` | `0` | Center y (or `:top`/`:center`/`:bottom`) |
| `z` | `0` | Depth |
| `xradius` | `50` | Horizontal radius |
| `yradius` | `30` | Vertical radius |
| `sectors` | `30` | Number of segments around the perimeter (higher = smoother) |
| `rotate` | `0` | Rotation in degrees |
| `rx`, `ry` | Center | Rotation center |
| `color` | `'white'` | Single color only |
| `opacity` | `nil` | Alpha override |
| `fill` | `true` | Whether to fill (see [Fill and Stroke](#fill-and-stroke)) |
| `stroke_width` | `0` | Outline thickness |
| `stroke_color` | Fill color | Outline color |
| `add` | `true` | Add to the window's scene graph on construction |
| `visible` | `true` | Initial visibility (drawn each frame while in the scene graph) |
| `padding` | `0` | Inset from anchored edges (also `padding_top`/`padding_right`/`padding_bottom`/`padding_left`) |

**Example:**

```ruby
ell = Ellipse.new(x: 200, y: 200, xradius: 80, yradius: 40, color: 'teal',
                  stroke_width: 2, stroke_color: 'white')
```

## Images

```ruby
img = Image.new('path/to/image.png')
```

| Parameter | Default | Description |
|---|---|---|
| `path` | (required) | Path to the image file (positional argument) |
| `x` | `0` | X position (or `:left`/`:center`/`:right`; see [Aligning to the window](#aligning-to-the-window)) |
| `y` | `0` | Y position (or `:top`/`:center`/`:bottom`) |
| `z` | `0` | Depth |
| `width` | Native width | Display width |
| `height` | Native height | Display height |
| `rotate` | `0` | Rotation in degrees |
| `rx`, `ry` | Center | Rotation center |
| `tint` | `'white'` | Tint color — modulates the image's texture colors |
| `scale_mode` | `nil` | Texture sampling; `nil` follows the window (see [Scale Mode](#scale-mode)) |
| `opacity` | `nil` | Alpha override |
| `add` | `true` | Add to the window's scene graph on construction |
| `visible` | `true` | Initial visibility (drawn each frame while in the scene graph) |
| `padding` | `0` | Inset from anchored edges (also `padding_top`/`padding_right`/`padding_bottom`/`padding_left`) |

**Example:**

```ruby
img = Image.new('hero.png', x: 100, y: 100, width: 64, height: 64)
img.x = 200
img.rotate = 45
img.tint = 'red'  # tint red: the texture's colors are multiplied by red
```

> Images use `tint` rather than `color` because the texture already has its own colors; `tint` modulates (multiplies) them. A white tint leaves the image unchanged; `tint: 'red'` makes it redder, not solid red.

### Rendering Images in Render Blocks

```ruby
img = Image.new('tile.png', add: false)

render do
  img.render(x: 50, y: 50, width: 32, height: 32)
end
```

### SVG Images

SVGs are rasterized once at load. If `width` and `height` are passed to `Image.new`, the SVG is rasterized at 2× that size so small upscales and rotations stay crisp; otherwise it rasterizes at the SVG's intrinsic size. Setting `width=`/`height=` later just scales the cached raster — for a fresh, sharp rasterization at a new size, use `resize!`:

```ruby
bee = Image.new('bee.svg', width: 64, height: 64)
bee.resize!(256, 256)  # re-rasterize crisp at the new size

bee.width = 400        # cheap scale of the existing raster
bee.resize!            # commit the current width/height to a fresh raster
```

`resize!` also works on raster images (PNG/JPG/BMP), where it resamples the source, useful for trimming GPU memory when displaying a large source small. It re-decodes from disk, so call it on size changes, not every frame.

> `resize!` is not supported on Sprites built from a `SpriteSheet`: every sprite cut from the sheet shares one backing texture, so re-rasterizing it would corrupt all of them. It raises `Ruby2D::Error`; set `width`/`height` to change only this sprite's display size, or use a standalone `Image` if you need a true resize.

## Text

Renders text using a TrueType font.

```ruby
text = Text.new('Hello, Ruby 2D!')
```

| Parameter | Default | Description |
|---|---|---|
| `content` | (required) | The string to display (positional argument) |
| `x` | `0` | X position (or `:left`/`:center`/`:right`; see [Aligning to the window](#aligning-to-the-window)) |
| `y` | `0` | Y position (or `:top`/`:center`/`:bottom`) |
| `z` | `0` | Depth |
| `size` | `20` | Font size in points |
| `style` | `nil` | Font style: `:bold`, `:italic`, `:underline`, `:strikethrough`, or an array combining them |
| `font` | `Font.default` | Path to a `.ttf` font file |
| `rotate` | `0` | Rotation in degrees |
| `rx`, `ry` | Center | Rotation center |
| `color` | `'white'` | Text color |
| `opacity` | `nil` | Alpha override |
| `add` | `true` | Add to the window's scene graph on construction |
| `visible` | `true` | Initial visibility (drawn each frame while in the scene graph) |
| `scale_mode` | `nil` | Texture sampling; `nil` follows the window (see [Scale Mode](#scale-mode)) |
| `padding` | `0` | Inset from anchored edges (also `padding_top`/`padding_right`/`padding_bottom`/`padding_left`) |

**Example:**

```ruby
text = Text.new('Score: 0', x: 10, y: 10, size: 24, color: 'yellow',
                font: '/path/to/font.ttf')
text.content = 'Score: 100'
text.size = 32
text.width   # => calculated width of the rendered text
text.height  # => calculated height of the rendered text
```

Embedded newlines (`"line one\nline two"`) are laid out as separate lines; `width` is the widest line and `height` covers the whole block.

Font `style` combines one or more of `:bold`, `:italic`, `:underline`, and `:strikethrough` (pass an array for several). It can be set at construction or changed later, and `font`/`size`/`style` all re-render the text:

```ruby
title = Text.new('Game Over', size: 48, style: [:bold, :italic])
title.style = :underline  # change it later
```

### Rendering Text in Render Blocks

```ruby
label = Text.new('FPS', add: false)

render do
  label.render(x: 10, y: 10, color: 'white')
end
```

### Fonts

The `Font` class provides utilities for discovering and loading system fonts.

```ruby
Font.all            # => ['arial', 'courier', ...] list of available font names
Font.path('arial')  # => '/Library/Fonts/Arial.ttf' (case-insensitive)
Font.default        # => path to the default font
```

Fonts are cached internally. You do not instantiate `Font` objects directly; they are managed by `Text`.

## Bitmap Text

Renders text using a built-in bitmap font, with no TTF dependency. The font covers printable ASCII only (space through `~`); any other character — accented letters, non-Latin scripts, emoji, tabs, newlines — renders as a `?` placeholder. For full Unicode or multi-line text, use [`Text`](#text).

```ruby
bt = BitmapText.new('Hello!')
```

| Parameter | Default | Description |
|---|---|---|
| `content` | (required) | The string to display (positional argument) |
| `x` | `0` | X position |
| `y` | `0` | Y position |
| `z` | `0` | Depth |
| `scale` | `3` | Size multiplier (must be a positive number; a float truncates to an integer) |
| `rotate` | `0` | Rotation in degrees |
| `rx` | `nil` (center) | Rotation center x; defaults to the text's center |
| `ry` | `nil` (center) | Rotation center y; defaults to the text's center |
| `color` | `'white'` | Text color |
| `opacity` | `nil` | Alpha override |
| `add` | `true` | Add to the window's scene graph on construction |
| `visible` | `true` | Initial visibility (drawn each frame while in the scene graph) |
| `scale_mode` | `nil` | Texture sampling; `nil` follows the window (see [Scale Mode](#scale-mode)) |

**Example:**

```ruby
bt = BitmapText.new('Loading...', x: 10, y: 10, scale: 5, color: 'green')
bt.content = 'Ready!'
bt.scale = 4
bt.rotate = 15  # rotates about the text's center; override with rx/ry
```

### Rendering Bitmap Text in Render Blocks

```ruby
label = BitmapText.new('FPS', add: false)

render do
  label.render(x: 10, y: 10, scale: 2, color: 'white')
end
```

## Sprites

A sprite is an animated image from a sprite sheet (subclass of `Image`).

### Choosing between Sprite, SpriteSheet, and Tileset

Quick rule of thumb: animated thing → `Sprite`; many sprites sharing a packed atlas → `SpriteSheet` + `Sprite(frame:)`; many static tile placements from a grid → `Tileset`.

- **`Sprite`** — one animated thing on screen. Carries per-instance state (current frame, current animation, elapsed time, speed, paused). Good for characters, projectiles, and effects.
- **`SpriteSheet`** — a *resource*, not a drawable. It's a wrapper around a packed atlas (regular grid or arbitrary layout) that loads the source image once and provides named-frame lookup. You don't see a `SpriteSheet` in the scene graph; you build `Sprite`s from it via `Sprite.new(sheet, frame: '<name>')` or `Sprite.new(sheet, animations: { jump: %w[...] })`, and every sprite built from the same sheet shares one GPU texture.
- **`Tileset`** — one source image with named cells drawn at many static positions in a single batched render. No per-cell animation or state. Good for tile-based maps, walls, and HUD elements built from a UI atlas.

The choice between `SpriteSheet` + many `Sprite`s and a single `Tileset` comes down to scene-graph cost: 100 sprites from one `SpriteSheet` produce 100 scene-graph entries sharing one texture (each independently animatable, each free to move); a `Tileset` with 100 placements produces 1 scene-graph entry, batched in one render call, with no per-cell animation.

"Sprite sheet" and "texture atlas" are used interchangeably in practice; Ruby 2D's class accepts the `TextureAtlas` name as an alias and supports both regular-grid (Sparrow XML) and packed-irregular (TexturePacker JSON) layouts. Lowercase "sprite sheet" elsewhere in this document refers to the general concept of multiple frames packed into one image; `Sprite` handles the simplest horizontal-strip case directly without needing a `SpriteSheet` wrapper.

```ruby
sprite = Sprite.new('characters.png',
  clip_width: 32, clip_height: 32,
  animations: {
    walk: 0..3,
    jump: [
      { x: 0, y: 32, width: 32, height: 32, time: 100 },
      { x: 32, y: 32, width: 32, height: 32, time: 200 }
    ]
  }
)
```

| Parameter | Default | Description |
|---|---|---|
| `source` | (required) | Image path **or** a `SpriteSheet` (positional argument); see [Sprite Sheets](#sprite-sheets) |
| `x` | `0` | X position (or `:left`/`:center`/`:right`; see [Aligning to the window](#aligning-to-the-window)) |
| `y` | `0` | Y position (or `:top`/`:center`/`:bottom`) |
| `z` | `0` | Depth |
| `width` | Clip width | Display width |
| `height` | Clip height | Display height |
| `rotate` | `0` | Rotation in degrees |
| `rx`, `ry` | Center | Rotation center |
| `tint` | `'white'` | Tint color — modulates the sprite's texture colors |
| `opacity` | `nil` | Alpha override |
| `add` | `true` | Add to the window's scene graph on construction |
| `visible` | `true` | Initial visibility (drawn each frame while in the scene graph) |
| `scale_mode` | `nil` | Texture sampling; `nil` follows the window (see [Scale Mode](#scale-mode)) |
| `padding` | `0` | Inset from anchored edges (also `padding_top`/`padding_right`/`padding_bottom`/`padding_left`) |
| `frame` | `nil` | When `source` is a `SpriteSheet`, the named frame to display statically |
| `clip_x` | `0` | X offset into the sprite sheet |
| `clip_y` | `0` | Y offset into the sprite sheet |
| `clip_width` | Image width | Width of each frame |
| `clip_height` | Image height | Height of each frame |
| `loop` | `false` | Whether the default animation loops |
| `time` | `300` | Duration of each frame in milliseconds |
| `speed` | `1.0` | Animation rate multiplier (also `sprite.speed=`) |
| `animations` | `{}` | Hash of named animations |
| `default` | `0` | Default frame index |

### Defining Animations

Animations are defined as a hash where keys are names and values are either:

- **Range**: Frame indices across a horizontal strip. `walk: 0..3` plays frames 0, 1, 2, 3 using `clip_width` to determine each frame's position.
- **Array**: Explicit frame regions, with optional per-frame timing. Each entry is one of:
  - A hash with `x`, `y`, `width`, `height`, and optional `time`.
  - A frame name (string) — only when the sprite was constructed from a `SpriteSheet`.
  - A hash with `name:` and optional `time:` — same as above with custom timing.

```ruby
animations: {
  idle: 0..0,
  walk: 0..7,
  attack: [
    { x: 0,  y: 64, width: 48, height: 48, time: 100 },
    { x: 48, y: 64, width: 48, height: 48, time: 150 }
  ]
}
```

For a horizontal-strip image, a `:default` animation is automatically created spanning all frames. Atlas-backed sprites (built from a `SpriteSheet`) skip this auto-default; define your own `:default` if you need one.

### Playing Animations

```ruby
sprite.play(animation: :walk, loop: true)
sprite.play(animation: :walk, flip: :horizontal)

# Non-looping animation: plays once, then holds on its last frame.
# Use this for jump poses, attack follow-throughs, death poses, etc.
sprite.play(animation: :jump)

# With a completion callback:
sprite.play(animation: :attack) do
  sprite.play(animation: :idle, loop: true)
end

sprite.stop         # stop and revert to the default animation's frame
sprite.stop(:walk)  # stop only if :walk is currently playing
```

A non-looping animation that finishes **holds on its last frame** until you call `stop` or `play` something else; the sprite doesn't snap back to the default frame on its own. The completion block (if provided) fires once at that moment.

Re-calling `play` with the animation that's *already* playing doesn't restart it (no jump back to frame 0), so calling it every frame from your update loop is safe. An explicitly-passed `loop:` or completion block still takes effect, letting you adjust those mid-play. To change only the loop setting, `sprite.loop = false` does the same without touching the callback.

| `play` Parameter | Default | Description |
|---|---|---|
| `animation` | `:default` | Animation name |
| `loop` | From defaults | Whether to loop |
| `flip` | `nil` | `:horizontal`, `:vertical`, or `:both` |
| Block | `nil` | Called once when a non-looping animation finishes |

```ruby
sprite.pause     # freeze on the current frame
sprite.resume    # continue from where pause left off
sprite.paused?   # => true / false
sprite.playing?  # true while actively animating; false when idle, paused, or held
sprite.looping?  # true if the current animation loops
sprite.loop = false  # toggle looping mid-play (doesn't restart the animation)
```

`pause` is idempotent and a no-op when nothing is playing. `play` and `stop` both clear the paused state.

```ruby
sprite.speed = 2.0  # animate twice as fast
sprite.speed = 0.5  # half speed
sprite.speed = 0    # frozen (still 'playing', just not advancing)
```

`speed` is a multiplier on top of `time:` — the per-frame duration is effectively `time / speed`. Negative values clamp to `0`; reverse playback is not supported.

Animations advance on real elapsed time — the same frame delta described under [`dt`](#frame-rate-independence-with-dt) — not on a fixed step per frame. So playback runs at the same wall-clock rate on any display refresh rate, a high `speed` genuinely skips frames (it isn't capped at the refresh rate), and a momentary stall is caught up on the next frame rather than dropped. Each frame is shown for its own `time:`, so per-frame durations stay accurate even while skipping.

```ruby
sprite.frame             # => current static frame name, or nil
sprite.frame = 'walk_a'  # swap to that named frame on an atlas-backed sprite
```

Assigning to `frame=` works on sprites built from a `SpriteSheet`. It updates the clip rect to the named frame, stops any playing animation, and (when no explicit `width`/`height` was given at construction) resizes the sprite to match the new frame.

### Rendering Sprites in Render Blocks

```ruby
sprite = Sprite.new('sheet.png', clip_width: 32, clip_height: 32, add: false)

render do
  sprite.render(x: 10, y: 10, clip_x: 64, clip_y: 0, clip_width: 32, clip_height: 32)
end
```

### Sprite Sheets

A `SpriteSheet` (alias `TextureAtlas`) loads a packed atlas where named regions of a single image hold many frames. Two formats are supported:

- **Sparrow XML** (TexturePacker "Generic XML", Kenney.nl asset packs) — `<TextureAtlas imagePath="…"><SubTexture name="…" x y width height/></TextureAtlas>`.
- **TexturePacker JSON** — both the Hash form (frames keyed by name) and the Array form (frames with `filename` fields).

The format is detected from the file extension (`.xml` / `.json`); the texture image referenced inside the atlas is loaded relative to the atlas file's directory. All `Sprite`s built from the same `SpriteSheet` share one GPU texture, so loading a single atlas once and constructing many sprites against it is cheap.

`SpriteSheet.new` also takes `scale_mode:`, which every `Sprite` built from the sheet starts with. See [Scale Mode](#scale-mode).

```ruby
sheet = SpriteSheet.new('characters.xml')

sheet.frame_names              # => ['character_beige_idle', ...]
sheet['character_beige_idle']  # => { x: 1285, y: 0, width: 256, height: 256 }
sheet.frame?('character_beige_idle')

# Static frame: display one named region
hero = Sprite.new(sheet, frame: 'character_beige_idle', x: 100, y: 100)

# Animations defined by frame names
walker = Sprite.new(sheet,
  animations: {
    idle: ['character_beige_idle'],
    walk: %w[character_beige_walk_a character_beige_walk_b]
  }
)
walker.play(animation: :walk, loop: true)

# Mix per-frame timing with frame names
runner = Sprite.new(sheet, animations: {
  run: [
    { name: 'character_beige_walk_a', time: 80 },
    { name: 'character_beige_walk_b', time: 120 }
  ]
})
```

| `SpriteSheet.new` Parameter | Default | Description |
|---|---|---|
| `path` | (required) | Path to the atlas file (`.xml` or `.json`) |

| Method | Description |
|---|---|
| `path` | The atlas file path |
| `image_path` | Resolved path to the atlas's texture image |
| `texture` | The shared backing `Image` |
| `frame_names` | All frame names, in declaration order |
| `frame(name)` / `[name]` | Look up a frame's `{x:, y:, width:, height:}`, or `nil` if absent |
| `frame?(name)` | Whether the sheet contains the named frame |

TexturePacker can pack frames rotated 90° (the `"rotated": true` flag). Ruby 2D doesn't draw rotated atlas frames yet; building a `Sprite` against one raises `Ruby2D::Error`. For now, repack the atlas with rotation disabled.

**Trimmed frames** are supported. When TexturePacker (or Aseprite, etc.) crops transparent edges from each frame, the atlas stores the original frame size (`sourceSize`/`frameWidth`,`frameHeight`) and the offset of the trimmed pixels within it (`spriteSourceSize.x`,`y` / `frameX`,`frameY`). Ruby 2D draws those frames at their original logical size: `sprite.width` and `sprite.height` reflect the un-trimmed footprint, and the packed pixels render at the correct offset. No setup is needed; if the atlas carries trim metadata, it just works.

## Tilesets

For drawing tile-based maps from a single tileset image.

```ruby
ts = Tileset.new('tiles.png', tile_width: 16, tile_height: 16, scale: 2)

# Define tiles by their grid position in the image
ts.define(:grass, 0, 0)
ts.define(:water, 1, 0)
ts.define(:wall, 0, 1, rotate: 90)
ts.define(:tree, 2, 0, flip: :horizontal)

# Place tiles at screen coordinates
ts.place(:grass, [[0, 0], [32, 0], [64, 0]])
ts[0, 32] = :water
```

| Parameter | Default | Description |
|---|---|---|
| `path` | (required) | Path to the tileset image (positional argument) |
| `tile_width` | `32` | Width of each tile in the source image |
| `tile_height` | `32` | Height of each tile in the source image |
| `z` | `0` | Depth |
| `padding` | `0` | Padding around the tileset edges |
| `spacing` | `0` | Spacing between tiles |
| `scale` | `1` | Scale multiplier for tile rendering |
| `add` | `true` | Add to the window's scene graph on construction |
| `visible` | `true` | Initial visibility (drawn each frame while in the scene graph) |
| `scale_mode` | `nil` | Texture sampling; `nil` follows the window (see [Scale Mode](#scale-mode)) |

### Tileset Methods

```ruby
ts.define(name, x, y, rotate: 0, flip: nil)  # define a tile type
ts.place(name, coordinates)                  # stamp tiles at [[x, y], ...]
ts[x, y] = name                              # stamp a single tile (replaces any existing)
ts[x, y]                                     # name placed at (x, y), or nil
ts.delete(x, y)                              # remove the tile at (x, y)
ts.clear                                     # remove all placed tiles
```

Placing a tile at a coordinate that's already occupied replaces the existing one. The `flip:` option for `define` accepts `:horizontal`, `:vertical`, or `:both`.

Setting `tileset.tint` multiplies all placed tiles against the texture (white = untinted, the default).

## Canvas

A pixel-level drawing surface for procedural graphics.

```ruby
canvas = Canvas.new(width: 200, height: 200)
```

| Parameter | Default | Description |
|---|---|---|
| `width` | (required) | Canvas width |
| `height` | (required) | Canvas height |
| `x` | `0` | X position |
| `y` | `0` | Y position |
| `z` | `0` | Depth |
| `rotate` | `0` | Rotation in degrees |
| `fill` | Transparent | Background fill color (RGBA array) |
| `tint` | `'white'` | Multiplied against the canvas texture when drawn (white = untinted); also used as the implicit color for `fill_*` / `stroke_*` / `draw_*` methods when none is passed |
| `opacity` | `nil` | Alpha override on the tint |
| `add` | `true` | Add to the window's scene graph on construction |
| `visible` | `true` | Initial visibility (drawn each frame while in the scene graph) |
| `scale_mode` | `nil` | Texture sampling; `nil` follows the window (see [Scale Mode](#scale-mode)) |

A Canvas captures the display scale once, at construction, and bakes it into its pixel buffer; it never re-evaluates (unlike `Text`, which re-rasterizes on scale changes), because doing so would discard your accumulated drawing. This is handled for you, before or after `show`, including with `pixel_scale: true` (where the buffer is 1:1 with physical pixels). The one thing that isn't known before `show` is the window's viewport size, so a Canvas meant to fill the viewport under `pixel_scale` still needs the `update`-loop pattern under [Pixel Scale](#pixel-scale).

### Filled Shapes

```ruby
canvas.fill_rectangle(x: 10, y: 10, width: 50, height: 30, color: 'red')
canvas.fill_square(x: 10, y: 10, size: 50, color: 'blue')
canvas.fill_triangle(x1: 0, y1: 0, x2: 50, y2: 0, x3: 25, y3: 50, color: 'green')
canvas.fill_quad(x1: 0, y1: 0, x2: 50, y2: 0, x3: 50, y3: 50, x4: 0, y4: 50)
canvas.fill_circle(x: 100, y: 100, radius: 25, color: 'yellow')
canvas.fill_ellipse(x: 100, y: 100, xradius: 40, yradius: 20)
canvas.fill_polygon(points: [[x1, y1], [x2, y2], [x3, y3], ...], color: 'purple')
canvas.fill_rectangles(rectangles: [[x1, y1, w1, h1], [x2, y2, w2, h2], ...], color: 'blue')
```

`fill_rectangles` fills many rectangles with a single shared color in one call, useful for hot-path workloads that would otherwise issue hundreds of `fill_rectangle` calls per frame.

For grids where every cell has its *own* color (heatmaps, fluid sims, tile fields), use `fill_pixel_grid`. The cell geometry is implicit — you describe the grid once and pass a flat color buffer:

```ruby
# 100 x 75 grid of 8x8 cells; colors is a flat array of 100*75*4 floats (rgba per cell, 0..1)
canvas.fill_pixel_grid(cols: 100, rows: 75, cell_w: 8, cell_h: 8, x: 0, y: 0, colors: colors)
```

Cell `(c, r)` covers `(x + c*cell_w, y + r*cell_h, cell_w, cell_h)` and reads its color from `colors[(r*cols + c)*4 .. +3]`. Cells with alpha 0 are skipped. One FFI crossing replaces an inner loop of `fill_rectangle` calls.

The vertex-based fills — `fill_triangle` (3), `fill_quad` / `fill_rectangle` / `fill_square` (4), and `fill_polygon` (N) — accept per-vertex colors by passing an array of colors (one per vertex), interpolated across the fill:

```ruby
canvas.fill_triangle(x1: 0, y1: 0, x2: 100, y2: 0, x3: 50, y3: 100,
                     color: ['red', 'green', 'blue'])
```

The same methods accept a per-vertex `opacity:` array (one alpha per vertex) for a fade across the fill (with a single color or a per-vertex color array); see [Canvas Opacity Overrides](#canvas-opacity-overrides). `fill_circle` / `fill_ellipse` are rasterized, not vertex-based, so they take only a single color and a scalar `opacity:`.

### Stroked (Outlined) Shapes

```ruby
canvas.stroke_triangle(x1: 0, y1: 0, x2: 50, y2: 0, x3: 25, y3: 50, stroke_width: 1)
canvas.stroke_quad(x1: 0, y1: 0, x2: 50, y2: 0, x3: 50, y3: 50, x4: 0, y4: 50)
canvas.stroke_rectangle(x: 10, y: 10, width: 50, height: 30, stroke_width: 2)
canvas.stroke_square(x: 10, y: 10, size: 50)
canvas.stroke_circle(x: 100, y: 100, radius: 25, sectors: 30)
canvas.stroke_ellipse(x: 100, y: 100, xradius: 40, yradius: 20, sectors: 30)
```

### Lines and Polylines

```ruby
canvas.draw_line(x1: 0, y1: 0, x2: 100, y2: 100, stroke_width: 2, color: 'white')
canvas.draw_line(x1: 0, y1: 0, x2: 100, y2: 100, stroke_width: 2, dash: 10, gap: 5, color: 'white')
canvas.draw_polyline(points: [[x1, y1], [x2, y2], ...], stroke_width: 1, closed: false)
canvas.draw_lines(segments: [[[x1a, y1a], [x2a, y2a]], [[x1b, y1b], [x2b, y2b]], ...], stroke_width: 1, color: 'white')
```

`draw_line` accepts a 2-element `color:` array `[start, end]` for a gradient along the length, matching `Line` semantics. Dashed lines interpolate the endpoint colors per segment so the gradient carries smoothly across dashes. Set `closed: true` on `draw_polyline` to connect the last point back to the first.

`draw_polyline`, `stroke_triangle`, `stroke_quad`, `stroke_rectangle`, and `stroke_square` all accept a per-vertex `color:` array (length matching the vertex count) for a gradient around the path / perimeter. `stroke_circle` and `stroke_ellipse` are single-color only. `draw_polyline` also accepts a per-vertex `opacity:` array; see [Opacity](#opacity).

`draw_lines` draws many disconnected line segments with a single shared color and stroke width in one call, useful for hot-path workloads that would otherwise issue hundreds of `draw_line` calls per frame. Unlike `draw_polyline`, segments are independent pairs of endpoints, not a connected path.

### Drawing Images and Text onto a Canvas

```ruby
img = Image.new('texture.png', add: false)
canvas.draw_image(img, x: 10, y: 10, width: 64, height: 64)

label = Text.new('Canvas text', add: false)
canvas.draw_text(label, x: 10, y: 80, color: 'yellow')
```

### Canvas Opacity Overrides

Every Canvas draw method that accepts `color:` also accepts `opacity:` as an optional alpha override. When provided, it replaces the color's alpha channel; when omitted, the color's own alpha is used unchanged. The caller's `Color` object is not mutated.

```ruby
canvas.draw_line(x1: 0, y1: 0, x2: 100, y2: 100, color: 'red', opacity: 0.35)
canvas.fill_rectangle(x: 0, y: 0, width: 50, height: 50, color: 'blue', opacity: 0.5)
```

For methods that accept a per-vertex color array, a scalar `opacity:` overrides alpha on every color — "fade the whole fill to this alpha":

```ruby
canvas.fill_rectangle(
  x: 0, y: 0, width: 100, height: 100,
  color: ['red', 'green', 'blue', 'yellow'],
  opacity: 0.35
)
```

The vertex-based fills (`fill_triangle`, `fill_quad`, `fill_rectangle`, `fill_square`, `fill_polygon`) and `draw_polyline` also accept a per-vertex `opacity:` **array** — one alpha per vertex, interpolated across the fill — with either a single color or a per-vertex color array. The array length must match the vertex count, or a clear error is raised:

```ruby
canvas.fill_triangle(
  points: [[0, 0], [100, 0], [50, 100]],
  color: 'red', opacity: [1.0, 0.5, 0.0]  # opaque tip fading to transparent
)
```

### Clearing the Canvas

```ruby
canvas.clear         # reset to the fill color
canvas.clear('red')  # clear to a specific color
canvas.clear(nil, x: 10, y: 10, width: 50, height: 50)  # clear a region
```

Drawing methods take effect on their own; there is no commit step, and only the region you actually touched is re-uploaded to the GPU. In `:on_demand` render mode, canvas drawing calls (including `clear`) auto-request a render for you; see [Render Mode](#render-mode).

### One-Shot Rendering

Like other textured renderables, `canvas.render(...)` accepts per-frame overrides for use inside a `render` block. Build the canvas with `add: false` and draw it yourself each frame:

```ruby
canvas = Canvas.new(width: 200, height: 200, add: false)
canvas.fill_circle(x: 100, y: 100, radius: 80, color: 'red')

render do
  canvas.render(x: Window.mouse_x, y: Window.mouse_y, rotate: Window.frames, opacity: 0.5)
end
```

Overrides: `x`, `y`, `width`, `height`, `rotate`, `tint`, `opacity`. `width:` and `height:` scale the displayed output; the underlying pixel buffer is fixed at construction.

## Audio

A unified audio class for playing sound effects and music.

```ruby
sound = Audio.new('bang.wav')
music = Audio.new('theme.ogg', loop: true)
```

| Parameter | Default | Description |
|---|---|---|
| `path` | (required) | Path to an audio file (positional argument) |
| `loop` | `false` | Whether to loop playback |

**Instance methods:**

```ruby
audio.play
audio.pause
audio.resume
audio.stop         # stop immediately
audio.stop(500)    # fade out over 500 ms
audio.length       # duration in seconds
audio.volume       # current volume (0.0–1.0)
audio.volume = 0.8
audio.loop = true
audio.looping?     # => true
```

**Overlapping playback:** each `Audio` plays on a single voice, so calling `play` again while it's still sounding restarts that one voice rather than layering a second copy. To overlap the same sound (rapid gunshots, coin pickups), give each simultaneous voice its own `Audio` and cycle through them:

```ruby
bangs = Array.new(4) { Audio.new('bang.wav') }
i = 0
on :key_down do
  bangs[i].play              # round-robin across voices so repeats overlap
  i = (i + 1) % bangs.size
end
```

**Global mixer volume:**

```ruby
Audio.volume        # get the mixer volume (0.0–1.0)
Audio.volume = 0.5  # set the mixer volume
```

## Button

A clickable UI region with optional label and hover effect. The trailing block is sugar for an `:click` handler; for any other event use `btn.on(...)` (see [Per-Object Events](#per-object-events)); `:click`, `:mouse_down`, `:mouse_up`, `:mouse_held`, `:hover`, `:hover_out`, `:drag`, and `:mouse_scroll` all fire on a Button.

```ruby
btn = Button.new(x: 100, y: 200, width: 150, height: 40,
                 label: 'Click Me', color: '#333') do |event|
  puts 'Button clicked!'
end

btn.on(:mouse_down) { btn.color = '#555' }
btn.on(:mouse_up)   { btn.color = '#333' }
```

| Parameter | Default | Description |
|---|---|---|
| `visual` | `nil` | An existing shape to use as the button (positional, optional) |
| `x` | `0` | X position (or `:left`/`:center`/`:right`; see [Aligning to the window](#aligning-to-the-window); owned visuals only) |
| `y` | `0` | Y position (or `:top`/`:center`/`:bottom`) |
| `z` | `0` | Depth |
| `width` | `200` | Width |
| `height` | `50` | Height |
| `label` | `nil` | Button label text |
| `color` | `'#333'` | Background color |
| `hover_color` | `nil` (no auto-tint) | Hover-tint color. Pass `:auto` to lighten the base, or any color to use it explicitly |
| `pressed_color` | `nil` (no auto-tint) | Color while held. Pass `:auto` to darken the base, or any color to use it explicitly |
| `stroke_color` | `nil` | Outline color (self-rendered Buttons only) |
| `stroke_width` | `0` | Outline width in pixels (self-rendered Buttons only) |
| `label_color` | `'white'` | Label text color |
| `hover_label_color` | `nil` | Label color while hovering |
| `pressed_label_color` | `nil` | Label color while held |
| `label_size` | `20` | Label font size |
| `padding` | `0` | Inset from anchored edges (also `padding_top`/`padding_right`/`padding_bottom`/`padding_left`; owned visuals only) |
| Block | `nil` | Sugar for `on(:click)` |

### Hover and Pressed States

`hover_color:` tints the Button while the cursor is over it; `pressed_color:` tints it while the mouse is held down. When both are set and the user is hovering+pressed, **pressed wins**. Dragging out while held releases the press tint; dragging back in re-engages it.

```ruby
Button.new(x: 100, y: 100, width: 80, height: 26,
           label:         'RUMBLE',
           color:         '#333',
           stroke_color:  '#888', stroke_width: 1,
           label_color:   '#bbb',
           pressed_color: '#ff9800',  # fill while held
           pressed_label_color: '#000') do
  pad&.rumble(strength: 0.8, duration: 0.4)
end
```

`:auto` derives a tint from the base color: it lightens for hover and darkens for pressed. Useful when you want feedback without picking specific colors:

```ruby
Button.new(..., hover_color: :auto, pressed_color: :auto)
```

Tints work with a [gradient fill](#per-vertex-colors) too. `:auto` lightens or darkens each vertex, preserving the gradient; an explicit `hover_color:`/`pressed_color:` may itself be a single color or a 4-color gradient:

```ruby
Button.new(color: ['navy', 'blue', 'teal', 'aqua'], hover_color: :auto)
```

`hover_label_color:` and `pressed_label_color:` require a `label:` to tint; supplying them without one raises an `ArgumentError`. When a tint is configured, change the resting color through `btn.color = …` (which updates the base color the tint derives from), not by mutating the visual directly; a direct change is overwritten on the next hover/press. Reading `btn.color` back returns that resting color, not the transient hover/press tint.

### Custom Visual Button

Wrap any shape as a button. The hit area follows the visual, and moving the button (`button.x = …` / `button.y = …`) moves the wrapped shape, the click region, and any label together.

```ruby
circle = Circle.new(x: 200, y: 200, radius: 30, color: 'blue')
btn = Button.new(circle) { puts 'Circle clicked!' }
```

By default, wrapping a visual does *not* tint it on hover. Opt in with `hover_color:`:

```ruby
Button.new(circle, hover_color: :auto)      # lighten on hover
Button.new(circle, hover_color: '#1976d2')  # explicit hover color
```

### Visual-less Button (hit area)

Omit `label`, `color`, and `stroke_color` to get an interactive region that renders nothing. Useful when the visual is drawn elsewhere (e.g., onto a `Canvas`):

```ruby
btn = Button.new(x: 12, y: 10, width: 26, height: 26)
btn.on(:click)      { puts 'swatch clicked' }
btn.on(:mouse_down) { fill.color = ACCENT }
btn.on(:mouse_up)   { fill.color = BG }
```

A visual-less Button with no handlers is not registered as interactive; it neither fires events nor blocks events from interactive shapes underneath. Adding any of `label:`, `color:`, or `stroke_color:` reverts to the rendered button.

### Button Methods

```ruby
btn.x = 50
btn.y = 50
btn.label = 'New Label'
btn.label  # => current label string or nil
btn.color = '#555'  # set the fill color (the resting color when a tint is configured)
btn.color           # => current fill color, or nil for a visual-less button
btn.contains?(x, y)
btn.on(event)  # see Per-Object Events
btn.off(descriptor)
btn.remove
btn.add
```

## Input Events

Keyboard and mouse event handling for the DSL pattern. For per-object event handlers (`rect.on(:click) { ... }`), see [Working with Objects](#working-with-objects). For gamepads, see [Gamepads](#gamepads).

### DSL Event Handlers

Register handlers with `on`:

```ruby
on :key_down do |event|
  puts event.key
end
```

The return value is an `EventDescriptor` that can be used to unregister:

```ruby
handler = on :key_down do |event|
  puts event.key
end

off handler
```

For events that carry a key, button, or axis, `on` also accepts a hash that filters by value. Each pair registers its own handler against the same block, so a single call can subscribe to multiple inputs at once:

```ruby
on key_down: :escape do
  close
end

on key_down: [:left, :a] do  # array → match any
  player.move_left
end

on key_down: :right, gamepad_button_down: :dpad_right do  # multi-event
  player.move_right
end
```

The filtering form works for `:key_down` / `:key_held` / `:key_up`, `:mouse_down` / `:mouse_held` / `:mouse_up`, `:gamepad_button_down` / `:gamepad_button_held` / `:gamepad_button_up`, and `:gamepad_axis`. Other events have no matcher field and use the regular `on :event do |e| ... end` form: this includes the `:key` and `:mouse` catch-alls (which fire for *any* key or mouse event, so there's no single value to filter on — branch on the event object's `type` instead), as well as `:mouse_move`, `:mouse_scroll`, `:close`, and so on. A single filter returns one `EventDescriptor`; multiple filters return an array. Gamepad events also accept a hash matcher; see [Gamepads](#gamepads).

### Keyboard Events

| Event | Fires | Event Object |
|---|---|---|
| `:key` | On any key event | `KeyEvent` (type, key) |
| `:key_down` | Once when a key is pressed | `KeyEvent` |
| `:key_held` | Every frame while a key is held | `KeyEvent` |
| `:key_up` | Once when a key is released | `KeyEvent` |

```ruby
on :key_down do |event|
  close if event.key? :escape
end

on :key_held do |event|
  puts "Holding: #{event.key}"
end
```

The `KeyEvent` struct has fields: `type` (`:down`, `:held`, `:up`) and `key` (lowercase string), plus `key?(name)` for matching. `key?` accepts either a string or a symbol: `event.key?(:space)` and `event.key?('space')` are equivalent.

**Class pattern polling:**

```ruby
def update
  close if key_pressed?('escape')
  @x += 1 if key_held?('right')
  puts 'released space' if key_released?('space')
end
```

### Mouse Events

| Event | Fires | Event Object |
|---|---|---|
| `:mouse` | On any mouse event | `MouseEvent` |
| `:mouse_down` | Once when a button is pressed | `MouseEvent` |
| `:mouse_held` | Every frame while a button is held | `MouseEvent` |
| `:mouse_up` | Once when a button is released | `MouseEvent` |
| `:mouse_scroll` | When the scroll wheel moves | `MouseEvent` |
| `:mouse_move` | When the mouse moves | `MouseEvent` |
| `:mouse_enter` | When the cursor enters the window | `MouseEvent` |
| `:mouse_leave` | When the cursor leaves the window | `MouseEvent` |

The `MouseEvent` struct has fields: `type`, `button`, `direction`, `x`, `y`, `delta_x`, `delta_y`, plus `button?(name)` for matching, `position` returning `[x, y]`, and `delta` returning `[delta_x, delta_y]`. `:mouse_enter` / `:mouse_leave` carry only `type`; query `mouse_position` if you need the current location.

```ruby
on :mouse_down do |event|
  puts "#{event.button} pressed at (#{event.x}, #{event.y})"
end

on :mouse_scroll do |event|
  puts "Scrolled #{event.direction}: dx=#{event.delta_x} dy=#{event.delta_y}"
end

on :mouse_move do |event|
  puts "Mouse at (#{event.x}, #{event.y})"
end

on :mouse_leave do
  puts 'cursor left the window, pausing input-driven effects'
end
```

**Class pattern polling:**

```ruby
def update
  puts 'left click' if mouse_pressed?(:left)
  puts 'right released' if mouse_released?(:right)
  paint(mouse_x, mouse_y) if mouse_held?(:left)

  if mouse_scrolled?
    puts mouse_scroll_direction
    puts mouse_scroll_delta_x
    puts mouse_scroll_delta_y
  end

  if mouse_moved?
    puts mouse_move_delta_x
    puts mouse_move_delta_y
  end

  # Mouse position is always available:
  puts mouse_x
  puts mouse_y
  mx, my = mouse_position  # both as a pair when you need them together

  paint(mouse_x, mouse_y) if mouse_inside?  # cursor is over the window
end
```

## Gamepads

Multi-gamepad support is the default. Every event carries the `Gamepad` it came from, and per-pad state (button/axis polling, dead zone, feedback) lives on the `Gamepad` object. The same `pad` instance survives until the device is unplugged; reconnects produce a new object.

A few things worth knowing before you start:

- **Cardinal face button names, not labels.** `:south` / `:east` / `:west` / `:north` are the *positions* on the pad; `:south` is always the bottom face button, regardless of whether your pad prints A (Xbox), B (Nintendo), or ✕ (PlayStation). See "Buttons and axes" below for the layout. If you'd rather write `:a` / `:b` / `:x` / `:y` in your game code, define your own constants; the section "Common patterns" shows how.
- **Reconnects produce a new `Gamepad`.** If a player swaps pads mid-game, the new pad is a fresh `Gamepad` object, not a revival of the old one. The old object stays valid but disconnected (polling returns safe defaults, feedback methods no-op). For stable player slots that survive disconnect, see "Common patterns" below.
- **`gamepads[0]` is connect order, not "Player 1".** The collection is ordered by when each pad plugged in. If you want stable player slots, build the mapping yourself; connect order is rarely what you want once disconnects are in play.

### Lifecycle

`:gamepad_connect` fires for every pad already plugged in when `show` is called, and again for any pad plugged in mid-game. `:gamepad_disconnect` fires on unplug. Both blocks receive the `Gamepad`:

```ruby
on :gamepad_connect do |pad|
  puts "Connected: #{pad.name} (id=#{pad.id}, type=#{pad.type})"
end

on :gamepad_disconnect do |pad|
  puts "Disconnected: #{pad.name}"
end
```

Polling a disconnected gamepad is safe: `held?` returns `false`, `axis` returns `0.0`, feedback methods return `false`. No exceptions.

### Event handlers

Six gamepad event types. Block args are unpacked from the event:

| Event | Block args | Fires |
|---|---|---|
| `:gamepad_connect` | `(pad)` | When a pad is plugged in (and once at `show` for each pad already present) |
| `:gamepad_disconnect` | `(pad)` | When a pad is unplugged |
| `:gamepad_button_down` | `(pad, button)` | Once on transition to down |
| `:gamepad_button_held` | `(pad, button)` | Every frame while the button is held |
| `:gamepad_button_up` | `(pad, button)` | Once on transition to up |
| `:gamepad_axis` | `(pad, axis, value)` | When a stick or trigger moves outside the dead zone |

```ruby
on :gamepad_button_down do |pad, button|
  player_for(pad).jump if button == :south
end

on :gamepad_axis do |pad, axis, value|
  steer(pad, value) if axis == :left_x
end
```

Filter form takes either a scalar / array (matched against `button` for button events, `axis` for axis events) or a hash matched against any of `gamepad`, `button`, `axis`:

```ruby
on gamepad_button_down: :south do |pad|
  player_for(pad).jump
end

on gamepad_button_down: { gamepad: pad1, button: :south } do
  player1.jump
end

on gamepad_axis: :left_x do |pad, axis, value|
  steer(pad, value)
end
```

A filter narrows *which* events fire the handler; it doesn't change the block args. A filtered handler still receives the same arguments as its unfiltered form, so a filtered `:gamepad_axis` block takes `(pad, axis, value)`, not `(pad, value)`.

Cross-source filters compose with keyboard / mouse:

```ruby
on key_down: :right, gamepad_button_down: :dpad_right do
  player.move_right
end
```

### The `gamepads` collection

`window.gamepads` is an `Enumerable` of all currently connected pads in connect order. Index 0 is the first-connected pad still present. Iteration order is documented as a contract.

```ruby
gamepads     # Array, Enumerable
gamepads[0]  # first connected pad, or nil
gamepads.size
gamepads.first
gamepads.each { |pad| ... }
gamepads.find { |pad| pad.id == n }
```

Polling every connected pad each frame is the natural shape for games that don't care which slot a player is in:

```ruby
update do |dt|
  gamepads.each do |pad|
    player_for(pad).move(pad.axis(:left_x), pad.axis(:left_y), dt)
  end
end
```

`Gamepad` instances use identity equality, so they're stable `Hash` keys for the lifetime of the connection. Hang per-player state directly off the pad:

```ruby
players = {}  # { Gamepad => player state }

on(:gamepad_connect)    { |pad| players[pad] = { score: 0, color: NEXT_COLOR.call } }
on(:gamepad_disconnect) { |pad| players.delete(pad) }

on :gamepad_button_down do |pad, button|
  players[pad][:score] += 1 if button == :south
end
```

### Common patterns

#### Single-pad games

`each` is a no-op when no pad is connected, so single-player games don't need a nil check:

```ruby
update do |dt|
  gamepads.each do |pad|
    player.x += pad.axis(:left_x) * SPEED * dt
    player.jump if pad.pressed?(:south)
  end
end
```

#### Press-to-join lobby

Gate joins on a state flag and a known button (`:start` is the convention). The `Gamepad` becomes a hash key as soon as it joins:

```ruby
state = :lobby
players = {}

on :gamepad_button_down do |pad, button|
  next unless state == :lobby && button == :start
  next if players.key?(pad)  # already joined

  players[pad] = { slot: players.size }
  state = :playing if players.size >= 2
end
```

#### Slots that survive disconnect

If your game has stable player slots ("Player 1", "Player 2"), keep an array of pad references with `nil` for empty slots. Disconnect leaves a hole; the next pad to press `:start` fills it:

```ruby
slots  = [nil, nil]  # two-player game; nil = open slot
paused = false

on :gamepad_disconnect do |pad|
  i = slots.index(pad) or next
  slots[i] = nil
  paused = true
end

on :gamepad_button_down do |pad, button|
  next unless paused && button == :start
  i = slots.index(nil) or next
  slots[i] = pad
  paused = slots.any?(&:nil?)
end

update do |dt|
  next if paused
  slots.each_with_index do |pad, i|
    next if pad.nil?
    dx = pad.axis(:left_x)
    dy = pad.axis(:left_y)
    # drive slot i's game state from (dx, dy) and any other pad input
  end
end
```

The reconnecting pad is a new `Gamepad`; that's why slots hold raw pad references rather than being keyed by pad. The new pad takes over the open slot; the old `Gamepad` object is forgotten.

#### Per-pad input remapping

Control schemes are just data — keep a per-pad map and look up button names instead of hard-coding them:

```ruby
controls = {}

on :gamepad_connect do |pad|
  controls[pad] = { jump: :south, attack: :east, dodge: :west }
end

on :gamepad_button_down do |pad, button|
  case controls[pad].key(button)
  when :jump   then players[pad].jump
  when :attack then players[pad].attack
  when :dodge  then players[pad].dodge
  end
end
```

Two players can have different control maps by assigning different hashes when each pad connects.

### Per-gamepad polling

```ruby
pad.held?(:south)             # currently held
pad.pressed?(:south)          # transitioned to down this frame
pad.released?(:south)         # transitioned to up this frame
pad.buttons_held              # Array of currently-held buttons

pad.axis(:left_x)             # -1.0..1.0, dead-zoned
pad.axis(:left_x, raw: true)  # raw, no dead zone
pad.axes                      # full Hash {:left_x => 0.4, :left_y => 0.0, ...}
pad.axis_moved?(:left_x)      # axis moved this frame
pad.axes_moved                # Array of axes moved this frame
```

Unknown names are safe: `pad.held?(:not_a_button)` returns `false`, `pad.axis(:not_an_axis)` returns `0.0`. `pad.axes` always includes every axis with a default of `0.0` for axes that haven't fired events yet.

### Dead zones

Sticks only: `:left_trigger` and `:right_trigger` are exempt because they rest at zero and rarely drift, so the full 0.0..1.0 range stays usable. Default 0.05. Below the threshold, sticks return `0.0` (symmetric around 0). `:gamepad_axis` events receive the dead-zoned value, and successive events with the same dead-zoned value are suppressed, so handlers don't get spammed by motion entirely inside the dead zone.

```ruby
pad.dead_zone                 # Float, default 0.05 (sticks only)
pad.dead_zone = 0.0           # disable
pad.axis(:left_x, raw: true)  # bypass per-call
```

### Buttons and axes

Names are positional; they describe the *layout*, not the labels printed on the pad. Face buttons use cardinal directions:

```
          north
       (Y / X / △)
       
   west           east
(X / Y / □)    (B / A / ○)

          south
       (A / B / ✕)
```

Labels in parens are Xbox / Nintendo / PlayStation, in that order. The cardinal name refers to the *position* on the pad; the same code works on any layout.

**Buttons** — `:south`, `:east`, `:west`, `:north`, `:back`, `:guide`, `:start`, `:left_stick`, `:right_stick`, `:left_shoulder`, `:right_shoulder`, `:dpad_up`, `:dpad_down`, `:dpad_left`, `:dpad_right`, `:misc1`, `:paddle1`, `:paddle2`, `:paddle3`, `:paddle4`, `:touchpad`, `:misc2`, `:misc3`, `:misc4`, `:misc5`, `:misc6`. Extended buttons (`:misc*`, `:paddle*`, `:touchpad`) only fire on pads that physically have them; use `pad.has?(:button, :paddle1)` to check.

**Axes** — `:left_x`, `:left_y`, `:right_x`, `:right_y` (range -1.0..1.0); `:left_trigger`, `:right_trigger` (range 0.0..1.0).

#### User-defined aliases

Cardinal is the canonical vocabulary because it's unambiguous across pad layouts, but Ruby's first-class symbols mean any project can layer game-specific names on top in two lines. This isn't a workaround; it's the intended pattern.

```ruby
# Shorter names matching your preferred layout
A, B, X, Y = :south, :east, :west, :north
pad.held?(A)
on gamepad_button_down: B do |pad|
  punch(pad)
end

# Or game-specific actions
ACTIONS = { jump: :south, attack: :east, dodge: :west }
pad.held?(ACTIONS[:jump])
```

### Capability queries, type, and battery

```ruby
pad.id          # identifier, opaque integer, stable for the connection
pad.name        # String, e.g. "Xbox Wireless Controller"
pad.type        # :xbox, :playstation, :nintendo, :generic, :unknown
pad.connected?  # false after disconnect

pad.has?(:rumble)
pad.has?(:rumble_triggers)
pad.has?(:led)
pad.has?(:button, :paddle1)
pad.has?(:axis, :left_trigger)

pad.battery  # :wired, :full, :medium, :low, :empty, or nil
```

`id`, `name`, `type`, and capability checks are cached at connect time and never change for the lifetime of the connection. `battery` is queried live every call.

For debugging an unrecognized device or composing a custom mapping, `pad.debug_info` returns a Hash with the GUID, USB vendor / product / version IDs, serial number, connection state (`:wired` / `:wireless` / `:unknown`), un-remapped real type, touchpad count, and the resolved mapping string. Returns `nil` for a disconnected pad.

`pad.joystick_state` returns the raw, pre-mapping hardware snapshot — `{ buttons:, axes:, hats: }` with axes as raw `-32768..32767` values and hats as SDL hat bitmasks — for mapping-generation tools that need to observe the physical device before SDL remaps it. Returns `nil` for a disconnected pad.

### Feedback

Rumble strengths are 0.0..1.0; durations are in seconds. `rumble` and `rumble_triggers` return `false` silently if the pad is disconnected or doesn't support the feature. The `led =` form is a Ruby assignment, so it evaluates to the assigned array rather than a success flag; call `pad.set_led(rgb)` instead when you need the `false`-on-failure return.

```ruby
pad.rumble(strength: 0.5, duration: 0.2)
pad.rumble(low: 0.5, high: 1.0, duration: 0.2)
pad.rumble_triggers(left: 1.0, right: 0.0, duration: 0.1)
pad.led = [255, 0, 128]
```

### Mappings

Ruby 2D ships with virtually all common mappings built in, so most projects never need this. For the rare exception:

- `~/.ruby2d/gamepads.txt` is loaded automatically when the window is shown.
- `add_gamepad_mapping(path_or_string)` smart-parses its argument: if it points at an existing file, it loads it; otherwise it's treated as a single mapping string

The string format is the standard SDL gamepad mapping (e.g. `030000005e040000ea02000000007801,Xbox One S Controller,a:b0,b:b1,...`); the [SDL_GameControllerDB](https://github.com/mdqinc/SDL_GameControllerDB) community database works as-is.

The leading 32-hex segment is the gamepad's GUID: a stable identifier derived from the device's bus (USB or Bluetooth), USB vendor / product / version IDs, and a hash of its name. The same pad keeps the same GUID across reboots and machines, which is why a mapping written once works for every user with that hardware. Two things change it for the same physical pad: switching connection mode (a pad paired over USB and over Bluetooth gets two different GUIDs, and may need two mapping entries), and renaming the controller in the OS; on macOS, the label in System Settings → Game Controllers feeds into the name hash, so renaming a pad silently invalidates any mapping keyed to its old GUID.

## Working with Objects

Every renderable object — shapes, images, text, sprites, canvases, buttons — can register per-object event handlers for mouse interactions, and has independent lifecycle controls for adding, removing, showing, and hiding.

### Per-Object Events

Any renderable object can register its own event handlers for mouse interactions.

| Object Event | Description |
|---|---|
| `:click` | Mouse down and up on the same object |
| `:hover` | Mouse enters the object |
| `:hover_out` | Mouse leaves the object |
| `:mouse_down` | Mouse button pressed on the object |
| `:mouse_held` | Every frame while a button is held (fires on the object originally pressed) |
| `:mouse_up` | Mouse button released. Fires on the originally-pressed object, plus on the topmost object under the cursor at release if different |
| `:drag` | Mouse moved while pressed on the object |
| `:mouse_scroll` | Scroll wheel while hovering over the object |

Events are dispatched to the topmost (highest z-order) interactive object at the mouse position.

**Example:**

```ruby
rect = Rectangle.new(x: 100, y: 100, width: 80, height: 80, color: 'blue')

rect.on :click do |event|
  puts "Clicked at (#{event.x}, #{event.y})"
end

rect.on :hover do |event|
  rect.color = 'yellow'
end

rect.on :hover_out do |event|
  rect.color = 'blue'
end

rect.on :mouse_down do |event|
  puts "Mouse down: #{event.button}"
end

rect.on :mouse_up do |event|
  puts "Mouse up"
end

rect.on :drag do |event|
  rect.x += event.delta_x
  rect.y += event.delta_y
end

rect.on :mouse_scroll do |event|
  puts "Scrolled #{event.direction}"
end
```

The kwarg form filtering by button works on objects too, for events that carry a button (`:mouse_down`, `:mouse_held`, `:mouse_up`, `:click`, `:drag`):

```ruby
rect.on(click: :left) { puts 'left-clicked' }
rect.on(mouse_down: :right, click: :right) { open_context_menu }
```

Remove a per-object handler:

```ruby
handler = rect.on(:click) { puts 'clicked' }
rect.off(handler)
```

Check if an object has handlers:

```ruby
rect.interactive?          # any handlers at all?
rect.interactive?(:click)  # handlers for :click specifically?
```

### Managing Objects

Every renderable object has two independent lifecycle controls:

```ruby
sq = Square.new(x: 0, y: 0, size: 50)

# Scene-graph membership
sq.remove  # remove from the window's drawing list
sq.add     # re-add (appended at its z-bucket)

# Visibility (preserves scene-graph position and z-order)
sq.hide             # stop drawing, but stay in the scene graph
sq.show             # draw again
sq.visible = false  # same as .hide
sq.visible?         # => false

clear  # remove all objects from the window
```

**When to use which:**

- `.hide` / `.show` for frame-by-frame visibility (blinking, UI overlays, paused entities). Cheap, preserves z-order among siblings.
- `.remove` / `.add` for lifecycle (spawn, despawn, destroy). Use `.remove` only when you genuinely want to stop participating in the scene graph.

Toggling with `.remove` + `.add`, or by blanking a `Text`'s `content`, to achieve a hide/show effect is wasteful: `.remove` / `.add` re-inserts at the end of the object's z-bucket so z-equal siblings may reorder, and reassigning `content` rebuilds the texture on every toggle. Use `.hide` / `.show` instead.

The `z` property controls draw order. Higher values are drawn on top:

```ruby
bg = Rectangle.new(x: 0, y: 0, width: 640, height: 480, z: 0)
fg = Square.new(x: 100, y: 100, size: 50, z: 10)
```

## Performance

Most apps never need to think about performance. It starts to matter when a scene has hundreds of moving parts, or targets [the web](#building-for-the-web), where Ruby runs several times slower than native. Three habits cover nearly all of it:

**Create shapes once and mutate them each frame.** A persistent object made with `.new` costs far less per frame than redrawing with a `.render` call, which re-processes all of its arguments on every call.

**Recolor in place.** Assigning `shape.color = [r, g, b, a]` builds a new color object each time; assigning channels directly (`shape.color.r = 0.5`) allocates nothing.

```ruby
require 'ruby2d'

# Created once; the update block just reshapes and recolors them
bars = Array.new(50) do |i|
  Rectangle.new(x: 10 + i * 12, y: 240, width: 10, height: 0, color: [0.2, 0.6, 1.0, 1])
end

update do
  bars.each_with_index do |bar, i|
    height = 140 + Math.sin(elapsed * 2 + i * 0.3) * 120
    bar.y = 340 - height
    bar.height = height
    bar.color.g = 0.3 + 0.4 * (height / 260.0)  # mutate the channel, no allocation
  end
end

show
```

**In the [render block](#render-block), prefer string colors.** Color strings like `'red'` or `'#33aaff'` are resolved once and cached across calls; array colors are re-parsed on every call; if a per-frame array color shows up hot, switch that drawing to a persistent shape and mutate its color instead.

## Building Native Applications

`ruby2d build app.rb` compiles your app into a standalone native executable in `build/native/` (on macOS it also produces an `App.app` bundle); run it with `ruby2d launch --native`. The build targets the machine it runs on and does not cross-compile.

Native builds link SDL3 and mruby as static libraries. The gem bundles these for the most common platforms — macOS on Apple silicon, and Windows on x86-64 and ARM64 — where native building works with no extra setup.

### Setting Up Other Platforms

On a platform the gem doesn't bundle — such as Linux, Intel macOS, or BSD — Ruby 2D needs SDL3 to build its native extension. If SDL3 isn't found when the gem installs, it installs *without* the extension and prints how to finish; running an app before then (`require 'ruby2d'`) prints the same guidance. You have two ways to complete it.

**Install SDL3 with your system package manager**, then rebuild the extension:

```bash
sudo apt install libsdl3-dev libsdl3-image-dev libsdl3-mixer-dev libsdl3-ttf-dev  # Debian/Ubuntu
gem pristine ruby2d
```

Use your distribution's equivalent; the install message names the exact command for your system. SDL3 is recent, so some package repositories may not carry it yet; if yours doesn't, use `ruby2d setup` instead.

**Or build the libraries locally** with `ruby2d setup` — no SDL3 packages required, so this works even where your distro doesn't package SDL3 yet:

```bash
ruby2d setup
```

This clones and compiles SDL3 and mruby for your platform (it needs `git`, `cmake`, and a C compiler — on Linux, also `pkg-config` and the X11 or Wayland development libraries — and takes a few minutes), caches them, and rebuilds the extension for you. The same libraries are what `ruby2d build --native` links against, so this one step covers both running and building apps. `setup` checks for these up front and stops with a clear message if any are missing, naming what to install.

Because that's a lot to kick off, `setup` first prints the platform it detected, the exact cache location it will write to, and the steps it will run, then asks to continue before doing any of it. Press Enter to accept, or anything else to cancel. The prompt is skipped when standard input isn't a terminal, so scripts and CI runs aren't left hanging.

```bash
ruby2d setup --force    # rebuild even if the libraries already exist
ruby2d setup --clean    # remove the built libraries for this platform
ruby2d setup --yes      # skip the confirmation prompt (also -y)
```

Re-run `ruby2d setup` after upgrading Ruby 2D: a newer version may pin newer SDL or mruby.

## Bundling Assets

Apps that load external files — images, audio, sprite sheets — need those files available to the built app, whether it runs natively or in the browser. `ruby2d build` bundles a directory of assets for both targets: a web build mounts it into the WebAssembly virtual filesystem; a native build copies it next to the executable (under `build/native/`, and into the macOS `App.app` bundle). Either way the directory lands at the same relative path you name it, so one reference like `Image.new('media/x.png')` resolves in both.

Pass the directory with `--assets`:

```bash
ruby2d build --assets media app.rb
```

Or declare it inline, so no flag is needed — add a `# ruby2d:assets <dir>` directive anywhere in the source (one directory per line; repeat for several):

```ruby
require 'ruby2d'

# ruby2d:assets media
```

A directive behaves exactly like `--assets`, and the two combine (a build honors both the flag and every directive). Paths resolve relative to the directory `ruby2d build` runs in, and a declared directory that doesn't exist aborts the build.

## Building for the Web

Ruby 2D apps can be compiled to WebAssembly using the `ruby2d` CLI. This requires [Emscripten](https://emscripten.org) — specifically the `emcc` compiler — to be installed and on your `PATH`; if it isn't, a plain `ruby2d build` skips the web build and still produces the native app, while an explicit `ruby2d build --web` reports the missing `emcc` as an error. Web builds also compile your Ruby with `mrbc`, the mruby compiler: it's bundled for macOS and Windows, and provided by [`ruby2d setup`](#setting-up-other-platforms) on other platforms.

### Commands

```bash
# Build for all platforms (native + web)
ruby2d build app.rb

# Build for web only
ruby2d build --web app.rb

# Launch the built web app in a local server
ruby2d launch --web
```

### Output

A web build produces the following files in `build/web/`:

- `app.html` — the HTML shell page
- `app.js` — the compiled JavaScript/Wasm loader
- `app.wasm` — the WebAssembly binary
- `app.data` — bundled asset data (always produced: the default font, plus any [bundled assets](#bundling-assets))

When you deploy these files, serve them with gzip or Brotli compression; `app.wasm` is by far the largest file and compresses to roughly a third of its size, which noticeably speeds up the first load. Most static hosts and CDNs (GitHub Pages, Netlify, Cloudflare, and the like) do this automatically; if you run your own server, enable it there.

### Options

To bundle images, audio, or other media into the build, see [Bundling Assets](#bundling-assets); `--assets` and the `# ruby2d:assets` directive work for web and native builds alike.

**Use a custom HTML template** instead of the built-in page:

```bash
ruby2d build --web --template page.html app.rb
```

Your template must load the compiled app and provide the canvas it draws to. The simplest starting point is the built-in template; copy it from the output of a plain `ruby2d build --web` (it's the generated `build/web/app.html`) and edit from there. The essentials it sets up:

- A `<canvas id="canvas">` element for rendering.
- A `Module` object whose `canvas` property points at that element (and, optionally, a `print` function to capture output).
- `<script async src="app.js"></script>` to load the compiled app.

For a `--single-file` build (below) the template is passed to Emscripten as its [shell file](https://emscripten.org/docs/tools_reference/emcc.html) instead, so it follows that format: include the `{{{ SCRIPT }}}` placeholder where the inlined app code should go, rather than a `<script src>` tag.

**Produce a single self-contained HTML file** (no separate `.js`, `.wasm`, or `.data` files):

```bash
ruby2d build --web --single-file app.rb
```

### mruby and CRuby Differences

Web builds compile your Ruby code using [mruby](https://mruby.org) rather than the standard CRuby interpreter. mruby is a lightweight, embeddable Ruby implementation and is not fully compatible with CRuby. Things to be aware of:

- The standard library is limited: many CRuby built-in classes and modules are unavailable or have reduced functionality.
- Gems that rely on C extensions or CRuby internals will not work.
- Some Ruby syntax and language features supported by CRuby may not be available in mruby.

Test your app with `ruby2d build --web` early to catch any incompatibilities.

### Frame Rate

Web builds drive the render loop from the browser's `requestAnimationFrame`, so they run at the display's refresh rate, including high-refresh displays (120 Hz and up). Write motion to be [frame-rate independent with `dt`](#frame-rate-independence-with-dt) so it looks the same at any refresh rate; this matters more on the web, where a complex scene may not reach native frame rates (mruby is slower than CRuby, and WebAssembly trails native code).

Browser specifics:

- **Chrome** and **Firefox** run at the full refresh rate by default.
- **Safari** caps `requestAnimationFrame` at 60 Hz unless you turn off the **"Prefer Page Rendering Updates near 60 fps"** flag (Safari ▸ Develop ▸ Feature Flags). With it off, Safari matches the display refresh rate too.

### Detecting the Web Build

`Ruby2D.web?` reports whether the running app was compiled for the web, so a scene can be sized to the target — the browser being the slower one, give it less to do:

```ruby
particles = 500 if Ruby2D.web?
```

The answer is settled when the app is built rather than probed at runtime: `true` only in a web build, `false` in a native build and when running with `ruby`.

### Cleaning Up

```bash
ruby2d build --clean
```
