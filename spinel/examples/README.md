# Spinel examples

Ordinary Ruby 2D scripts that the Spinel target can build today. Each one runs unmodified on all three engines — CRuby, mruby, and Spinel — which is the bar: an example that only runs on one of them proves nothing.

```sh
RUBY2D_SPINEL=../spinel/bin/spinel ruby2d build --spinel spinel/examples/fountain.rb
ruby2d launch --native
```

| Example | What it's for |
|---|---|
| `fountain.rb` | The demo. A sweeping emitter sprays balls that fall, bounce and recycle |
| `balls.rb` | The benchmark scene. Deliberately dull; fixed workload, fixed timestep |
| `mandelbrot.rb` | The heavy one. 30,000 squares recolored band by band, zooming itself |

`../square.rb` is not here on purpose — it is the build smoke target (`tools/build_square.rb` reads it by path), and it draws one static shape.

Two things the target does not have yet shape what these can be: `Canvas` and `Text`. Both are Ruby-object-shaped all the way down in C — every entry point takes the Ruby object and reads ivars off it — so neither can be reached over an FFI that passes scalars. `mandelbrot.rb` is what an example looks like when it works around the first (a grid of `Square`s in place of a canvas) and does without the second (a progress bar in place of a status line).

## Measuring them

Any example here can be run on all three engines with:

```sh
cd spinel && rake fps                  # balls, the default
cd spinel && rake fps[fountain,200]    # name, measured frames
```

The tool splices its own timing around whatever `update` and `render` blocks the example registered, so examples need to know nothing about being measured. What it reports is Ruby-side cost per frame, not fps — see the header of `../tools/fps.rb` for why wall-clock fps cannot answer the question on a desktop.

**A benchmark-grade example holds its workload still.** `balls.rb` creates every object at startup and steps a fixed timestep; `fountain.rb` grows its scene, so its number is an average over a changing workload and the tool drops the per-object column when the engines end on different object counts. Both are legitimate to measure — just read the second kind as "this scene on this engine", not as a per-object figure.

`mandelbrot.rb` is the third kind: its workload depends on *where* it has zoomed to, and it picks that at random. Two runs of identical source came out 37% apart before that was noticed. Comparing anything in it means pinning the view first — see `../README.md`.

**What the number is made of matters more than the number.** Every scene here blends per-object dispatch, where Spinel is a flat ~3.2× faster, with whatever Ruby-level work the example does, where a tight numeric loop runs ~25×. An example dominated by the first measures ~3×, one dominated by the second measures ~25×, and neither figure describes the compiler on its own.

## Writing a new one

Write ordinary Ruby 2D. Four things the target cannot do yet, all of which have a natural way around:

- **No input.** `on :key_down` and friends do not compile. Drive the scene from time instead, the way `fountain.rb`'s emitter sweeps rather than following the mouse.
- **No `remove`.** It reaches a `Hash#delete_if` the compiler refuses. Recycle objects instead of dropping and rebuilding them, which is better practice regardless.
- **No `obj.attr += value`** when the writer is a hand-written `def`, which covers `x`, `y` and the rest of `Renderable`. Write it longhand: `s.x = s.x + dx`.
- **No array of objects captured by the `update` block** when it was populated outside it. `unsupported closure capturing a non-integer variable` is the message, and it names no line. Hold the collection in a constant instead and let your methods read it directly, the way `mandelbrot.rb`'s `GRID` and `COUNTS` do.

And one that will silently do nothing rather than fail: **a nested block that reads the `update` block's own `dt`** makes Spinel infer `dt` as `Integer`, so every frame delta truncates to zero and the scene sits still at full frame rate. Read it into a local first — `step = dt` — before any `each`. See `../README.md`.

Each of these is a live compiler bug rather than a permanent limit, so this list should shrink. Add a comment at the site naming the issue, as the current examples do, so it is obvious what to delete when it does.
