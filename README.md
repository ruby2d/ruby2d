# Welcome to Ruby 2D!

[![Gem](https://img.shields.io/gem/v/ruby2d.svg?color=%23f63c38&style=for-the-badge)](https://rubygems.org/gems/ruby2d) [![Build Status](https://img.shields.io/github/actions/workflow/status/ruby2d/ruby2d/ci.yml?branch=main&style=for-the-badge)](https://github.com/ruby2d/ruby2d/actions/workflows/ci.yml) [![Discord](https://img.shields.io/discord/807786505434693632?style=for-the-badge)](https://discord.com/invite/QBWguEasV7)

**Ruby 2D** is a library for creating 2D applications, games, graphics, and interactive art in a way that's simple, natural, and joyful, in the spirit of [Ruby](https://www.ruby-lang.org) itself. The same code can run as an interpreted Ruby app, a native executable on macOS, Windows, and Linux, or a web app in the browser.

Install it with `gem install ruby2d`, then visit the [Ruby 2D website](https://www.ruby2d.com) to learn how to use the gem and build your first app.

## Hacking on Ruby 2D

Want to build the gem from source, fix a bug, or explore how it works under the hood? Start by cloning the repo together with its [assets](https://github.com/ruby2d/assets) submodule:

```bash
git clone --recurse-submodules https://github.com/ruby2d/ruby2d.git
```

The assets submodule holds prebuilt binaries, so it's fetched shallow: a single commit, no history. If you've already cloned without `--recurse-submodules`, run `git submodule update --init` to fill it in. Once it's there, `rake update` syncs the assets to their latest upstream commit any time you want.

Next, run `bundle install` to get the development gem dependencies. If you're on Linux, BSD, or an Intel Mac, you'll also need to build SDL3 yourself first with `rake deps:build` (see [building native dependencies](#building-native-dependencies) below).

Finally, run `rake` — it reinstalls the gem from your working tree, compiling the C extension, then runs the automated test suite. You'll run this often while developing; it's the main loop for working on Ruby 2D.

### Building native dependencies

Ruby 2D ships with pre-built SDL3 static libraries for macOS (arm64) and Windows (UCRT, both x86_64 and arm64), bundled via the [assets](https://github.com/ruby2d/assets) submodule. A local `rake` build links those and nothing else: `rake build` packages `assets/platform/` into the gem, and the extension build links `SDL3`, `SDL3_image`, `SDL3_mixer`, and `SDL3_ttf` from there. What you test is what ships. On platforms with no pre-built libraries (Linux, BSD, Intel macOS) `rake` stops and tells you to build them, which is what the next section is for.

The published gem is deliberately more forgiving, since someone installing from RubyGems has no working tree to build in: it falls back to a `ruby2d setup` cache build, then to system-installed SDL3, and installs without the native extension if it finds neither.

#### Building dependencies from source

`rake deps:build` compiles SDL3 and mruby from the pinned versions in the [assets](https://github.com/ruby2d/assets) submodule, plus the WebAssembly libraries if Emscripten is available. Make sure you have CMake installed, then run:

```bash
rake deps:build
```

The static libraries land in `assets/platform/<target>/lib/`, where `rake` picks them up from then on. This is the expected path on Linux, BSD, and Intel macOS: a one-time cost that builds the same pinned SDL3 the release gem bundles, so your build matches everyone else's.

#### Using system libraries instead

To test against your own SDL3 (a distro package, a Homebrew install, a local build), pass `--with-system-libs` to override the bundled or self-built static libraries:

```bash
CONFIGURE_ARGS=--with-system-libs rake
```

`rake install` composes its own `gem install` command line, so there's no slot to append your own arguments. `CONFIGURE_ARGS` is the environment variable mkmf reads them from instead. Installing the published gem, you pass the flag directly:

```bash
gem install ruby2d -- --with-system-libs
```

Either way you'll need the **development** packages (headers, not just the runtime libraries) for version 3 of SDL, SDL_image, SDL_mixer, and SDL_ttf. Names vary by system (`libsdl3-dev`, `SDL3-devel`, `sdl3`), and SDL3 is new enough that some distros don't carry it yet. If yours doesn't, use `rake deps:build` above.

## Tests

Ruby 2D's test suite has two halves: automated [RSpec](https://rspec.info) tests for things a machine can verify, and interactive tests in [`test/`](test/) for things a person needs to see, hear, or click on.

Run `rake` to build, install, and run the full automated suite. To run an interactive test, use `rake test <name_of_test>`.

```bash
# Run `test/shapes.rb` with CRuby (the default)
rake test shapes
# ...or, equivalently, the explicit form:
rake test:ruby shapes

# Run `test/audio.rb` as a native executable (built with mruby)
rake test:native audio

# Run `test/input.rb` as a web app (built with mruby and WebAssembly) in the browser
rake test:web input

# Run every interactive test sequentially; press Esc to close one and start the next
rake test:all

# Auto-run every interactive test for about a second each, exiting non-zero
# if any crashes. Useful for CI and automated checks. Override the per-test
# timeout via the RUBY2D_TEST_AUTO_TIMEOUT environment variable.
rake test:auto
```

The interactive tests are organized by domain, each one a comprehensive visual check for an area like `shapes`, `text`, or `audio`. They follow a shared visual style; see the [Style section of `test/README.md`](test/README.md#style).

## Examples

Demo apps that exercise the gem live in [`examples/`](examples/) — short, self-contained programs that double as Ruby 2D's visible portfolio. List them with `rake examples`, then run one with `rake examples <name_of_example>`.

```bash
# Run `examples/asteroids.rb` with CRuby (the default)
rake examples asteroids
# ...or, equivalently, the explicit form:
rake examples:ruby asteroids

# Run `examples/snake.rb` as a native executable (built with mruby)
rake examples:native snake

# Run `examples/boids.rb` as a web app (built with mruby and WebAssembly) in the browser
rake examples:web boids

# Run every example sequentially; press Esc to close one and start the next
rake examples:all

# Auto-run every example for about a second each, exiting non-zero if any
# crashes. Useful for CI and automated checks. Override the per-example
# timeout via the RUBY2D_EXAMPLES_AUTO_TIMEOUT environment variable.
rake examples:auto
```

The examples follow shared conventions for file layout, tunables, comments, and visual polish; see [`examples/README.md`](examples/README.md).

## Benchmarks

Performance benchmarks are in [`benchmark/`](benchmark/). List them with `rake benchmark`, run a specific one with `rake benchmark:<name>`, or run all with `rake benchmark:all`. To measure the WebAssembly build, `rake benchmark:web[<name>]` runs one in headless Chrome. See [`benchmark/README.md`](benchmark/README.md) for the full list and how to read the output.

## Contribute

Ruby 2D is built by a community that cares about making 2D programming approachable and fun. There are many ways to pitch in:

- **Suggest a new feature.** 🌟 Got an idea, a new API, a DSL tweak, anything else? [Open an issue](https://github.com/ruby2d/ruby2d/issues/new) or come chat on [Discord](https://chat.ruby2d.com).

- **Help support more platforms.** 💻 Ruby 2D aims to run anywhere. Test it on yours and help us improve the experience, or [file an issue](https://github.com/ruby2d/ruby2d/issues) for one we don't yet support.

- **Fix bugs and squeeze out more performance.** 🐛 Help others have a solid experience: pick something from the [issue tracker](https://github.com/ruby2d/ruby2d/issues) or have a go at improving benchmark results.

- **Improve the docs.** 📚 Spot something unclear or missing on the [Ruby 2D website](https://www.ruby2d.com)? Most pages have a "suggest an edit" link that takes you straight to the source in the [website repo](https://github.com/ruby2d/ruby2d.com).

### Writing code

Ruby 2D's simple surface hides a fair bit of moving parts underneath. See [`ARCHITECTURE.md`](ARCHITECTURE.md) for an overview, and [`AGENTS.md`](AGENTS.md) for the code conventions: naming, comments, string quoting, and commit-message format. It's written for AI coding agents, but it applies to everyone. When you're ready to contribute code, a few things will help your PR land smoothly:

- **Start with an issue.** Search for an existing one or open a new one before writing code. Let's align on direction and strategy first, so the effort doesn't go to waste.

- **Use a subset of Ruby that works everywhere.** Ruby 2D apps run unchanged on both CRuby (the standard interpreter) and [mruby](https://mruby.org) (which powers the native and [WebAssembly](https://webassembly.org) builds), so your contribution must stick to language and standard-library features supported by both. When in doubt, try snippets in their respective REPLs: `irb` for CRuby, `mirb` for mruby.

- **Comprehensively test your change.** Unit tests alone won't catch everything here. Visuals must look right, audio must sound right, inputs must respond, and behavior must hold across every supported platform.

Don't worry if any of it sounds daunting. We're happy to help along the way.

## Preparing a release

Maintainers: run `rake release`, which prints the release checklist, marks off every step it can verify, and walks the rest with you. See [`RELEASING.md`](RELEASING.md) for what it does on your behalf and the platforms to test on before cutting a release.
