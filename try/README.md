# try/

This directory builds the interactive "Try Ruby 2D" webpage components hosted at [ruby2d.com/try](https://www.ruby2d.com/try). It's not part of the Ruby 2D library itself, but a standalone build tool that compiles the library to WebAssembly so users can write and run Ruby 2D code directly in a browser.

## Files

- `build.rb` — Build script — run this to produce the output files
- `try_main.c` — WASM entry point, replacing the normal mruby `main()` from `ruby2d.c`. Exposes `main()` (initializes mruby + Ruby 2D) and `try_run_code()` (evaluates user code sent from the browser via `ccall`)
- `test.html` — A smoke test page used to verify the build locally. The production page at `ruby2d.com/try` is maintained separately.

The `build/` directory is generated and not checked in.

## How it works

1. **Assemble** — `build.rb` concatenates the curated list of Ruby 2D library files into a single `ruby2d_lib.rb`. The list (`Ruby2D::CLI::LIB_FILES`, defined in `lib/ruby2d/cli/lib_files.rb`) is the single source of truth shared with the native/web build (`lib/ruby2d/cli/build.rb`), so the two can't drift. It includes files from subdirectories like `cli/` and `window/`, so it's not a plain `lib/ruby2d/*.rb` glob.
2. **Compile to bytecode** — `mrbc` (the mruby compiler) compiles `ruby2d_lib.rb` into a C byte array (`ruby2d_lib.c`).
3. **Combine C sources** — all `.c` files from `ext/ruby2d/` are merged into a single `app.c`, with the mruby `main()` stripped out and replaced by `try_main.c`. The Ruby 2D bytecode is appended.
4. **Compile to WASM** — Emscripten (`emcc`) compiles `app.c` against the pre-built WASM SDL libraries in `assets/` to produce `app.js`, `app.wasm`, and `app.data` (font files).
5. **Copy HTML** — `test.html` is copied to `build/try.html`.

The resulting `build/` files are deployed to ruby2d.com. When the page loads, the WASM module initializes and signals JavaScript when it's ready. Clicking **Run** calls `try_run_code()` via Emscripten's `ccall`, which spins up a fresh mruby VM, loads the Ruby 2D library bytecode, and evaluates whatever code the user has written in the editor.

## Building

You'll need [Emscripten](https://emscripten.org) installed and `emsdk_env.sh` sourced, plus `mrbc` (the mruby compiler) available on your PATH or bundled in `assets/`.

```
rake try:build
```

Output files will be in `try/build/`. To preview locally:

```
rake try:serve
```
