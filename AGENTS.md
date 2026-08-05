# Ruby 2D guide for AI coding agents

## Testing

Run `rake` to test: it reinstalls the gem (rebuilding the native C extension) and runs the full RSpec suite in `spec/`. Never use `gem build`, `gem install`, or `rspec` directly.

The `test/` directory contains interactive tests for human verification. Don't run them.

Anything built through the `ruby2d` CLI — `rake test:native`, `rake test:web`, `rake benchmark:web` — compiles the **installed** gem's `lib/`, not the working tree, so run `rake` after editing `lib/` or the build silently won't include the change. `rake try:build` is the exception; it reads the working tree directly.

## Architecture

See `ARCHITECTURE.md` for the full picture: design principles and decisions, layering, the Ruby-to-C bridge, and the rendering and event pipelines.

Always use SDL3 libraries and APIs. SDL2 is not supported. Verify any constant, signature, or struct field against the vendored headers in `assets/platform/include/` rather than guessing or searching online.

### Multi-Ruby support

Both the C extension and `lib/` compile against CRuby and mruby. In `.c` files, use the `r_*` macros from `ext/ruby2d/ruby2d.h`, never `rb_*` or `mrb_*` directly (`ARCHITECTURE.md` covers the layer; its few sanctioned exceptions are documented at the sites that need them).

In `lib/`, CRuby-only idioms compile fine under `mrbc` and keep the specs green, then crash the native and web builds at runtime. `defined?` is the common one — use `instance_variable_defined?(:@x)` for ivar guards. When unsure whether something exists in mruby, confirm it with a throwaway script built by `ruby2d build --native`, ending the script's `update` block with `close` (closing any earlier leaves a window that has to be force-killed).

## Documentation

- Update `USAGE.md` for user-facing changes. It's the API reference: what the user types, sees, and does. Verify claims against the code; every example must run as-is when copy-pasted. One canonical home per concept, linked from elsewhere; re-explaining guarantees drift. If removing a sentence wouldn't change what the user could do correctly, cut it.
- Update `README.md` for development-related changes (build process, dependencies, architecture, contributing).
- When working in `examples/`, `benchmark/`, or `try/`, follow the conventions documented in that directory's `README.md`.

## Style & conventions

- Write "Ruby 2D" (with a space) in prose and documentation; in code the module name is `Ruby2D` (`Ruby2D::Window`, `ruby2d`).
- Ruby: single-quoted strings by default, double-quoted only for interpolation or escape sequences.
- Wrap comments to about 80 characters: aim to fill the width, but let readability win over the exact count.
- Don't wrap lines in Markdown files (one paragraph = one line), so a typo fix touches one line, not five.
- The `ruby2d` CLI, `rake`, and the build scripts are one visual system, though each defines some of its own helpers — reuse them instead of formatting output by hand. Reference screens: `ruby2d`, `ruby2d examples`, `ruby2d usage`.

### Native C extension

Match the surrounding code. The conventions that aren't obvious from it:
- Full-line comments (dividers, banners) are exactly 80 characters.
- Errors: log via `R2D_Error()`/`R2D_Log()` with caller context, early-return on failure, `NULL`-check before use.

### Commit messages

- One-line summary, then optional bullets: one physical line each, no matter how long (don't hard-wrap; let the viewer soft-wrap). No paragraphs, no trailing prose, no trailers.
- Wrap code identifiers (functions, files, flags, classes) in backticks.
- Show the draft as raw text so the backticks are visible and reviewable before committing.
