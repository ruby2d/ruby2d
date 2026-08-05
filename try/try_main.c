// try_main.c -- WASM entry point for the "Try Ruby 2D" interactive webpage
//
// Replaces the normal mruby main() from ruby2d.c. Provides two functions:
//   main()          -- initialize mruby + Ruby 2D, signal JS when ready
//   try_run_code()  -- reset state and evaluate user code from the browser

#include <mruby/compile.h>


// Forward declarations for bytecode compiled from ruby2d_lib.rb
extern const uint8_t ruby2d_lib[];


// =============================================================================
// Helper: Register all Ruby 2D extensions and cache R_IDs
// =============================================================================

/*
 * Cache all R_ID variables and register Ruby 2D classes/methods.
 * Must be called after every mrb_open() since symbols are per-VM.
 */
static void try_register_ruby2d(void) {
  // Ruby2D module. Its own methods are registered here rather than inherited,
  // because the build strips ruby2d.c's entry point — the block that defines
  // them — and substitutes this file. Keep this list in step with the one in
  // `Init_ruby2d`, or a method works everywhere but the Try page.
  ruby2d_module = r_define_module("Ruby2D");
  r_define_class_method(ruby2d_module, "web?", ruby2d_web_p, r_args_variadic);

  // Initialize Ruby 2D extension modules. R2D_Ext_Init must run first so the
  // Ruby2D::Ext module exists when subsystem inits register methods on it.
  // R2D_Ext_Init and R2D_Window_Init cache all needed R_IDs internally.
  R2D_Ext_Init();
  R2D_Image_Init();
  R2D_Text_Init();
  R2D_BitmapText_Init();
  R2D_Canvas_Init();
  R2D_Audio_Init();
  R2D_Window_Init();
}


// =============================================================================
// Main Entry Point
// =============================================================================

/*
 * Called once on page load. Initializes mruby and Ruby 2D, loads the library
 * bytecode, then signals JavaScript that WASM is ready.
 */
int main() {
  mrb = mrb_open();
  if (!mrb) return 1;

  try_register_ruby2d();

  // Load the Ruby 2D library bytecode
  mrb_load_irep(mrb, ruby2d_lib);
  if (mrb->exc) { mrb_print_error(mrb); mrb->exc = 0; }

  // Signal JavaScript that WASM is ready
  EM_ASM({ if (window.onWasmReady) window.onWasmReady(); });

  return 0;
}


// =============================================================================
// Runtime Code Evaluation
// =============================================================================

/*
 * Called from JavaScript on each "Run" button press. Resets all state and
 * evaluates the user's Ruby code.
 *
 * State reset strategy:
 * - Cancel any running Emscripten main loop
 * - Reset FPS tracking statics
 * - Rebase the Ext.now clock so `elapsed` starts at zero for the new program
 * - Close and reopen the mruby VM for a clean Ruby state
 *   (mrb_close triggers GC which frees the R2D_Window via R2D_Window_free)
 * - Re-register all C extensions and reload library bytecode
 * - Evaluate the user's code via mrb_load_string()
 *
 * The build script patches emscripten_set_main_loop to use
 * simulate_infinite_loop=false, so ext_show returns normally after setting up
 * the animation loop. This avoids corrupting mruby's internal exception
 * handler state (mrb->jmp), which would happen if the throw/unwind mechanism
 * were used from a function called via ccall.
 */
EMSCRIPTEN_KEEPALIVE
void try_run_code(const char *code) {
  // Stop any running animation loop
  emscripten_cancel_main_loop();

  // Reset FPS tracking statics (accessible since all C files are concatenated)
  fps_initialized = false;
  frame_index = 0;
  frame_count = 0;

  // Rebase the Ext.now clock so `elapsed` reads zero for this program. SDL is
  // initialized once per page load and never quits, so its tick count spans the
  // whole visit rather than this run. Without this, a program whose motion is a
  // function of `elapsed` renders its first frame mid-animation: the code did
  // start over, but every position it computes is for a moment far in the past.
  r2d_time_origin_ns = SDL_GetTicksNS();

  // Restore the cursor. Its shape and visibility are global SDL state rather
  // than window state, so closing the window below leaves them alone, and a
  // program that never mentions the cursor never sets them back. Without this,
  // one `set cursor: :hidden` would hide the cursor for every program run
  // afterwards, until the page is reloaded.
  SDL_SetCursor(SDL_GetDefaultCursor());
  SDL_ShowCursor();

  // Close mruby -- the GC will free the R2D_Window (if any) via the
  // R2D_Window_free callback registered with R2D_DEFINE_DATA_TYPE.
  // We must NOT manually call R2D_FreeWindow before this, as that would
  // cause a double-free when the GC later invokes R2D_Window_free.
  mrb_close(mrb);
  R2D_SetWindow(NULL);

  mrb = mrb_open();
  if (!mrb) {
    printf("Error: Failed to reopen mruby VM\n");
    return;
  }

  // Re-register all Ruby 2D C extensions (symbols are per-VM)
  try_register_ruby2d();

  // Reload the Ruby 2D library bytecode
  mrb_load_irep(mrb, ruby2d_lib);
  if (mrb->exc) { mrb_print_error(mrb); mrb->exc = 0; }

  // Evaluate the user's code
  mrb_load_string(mrb, code);
  if (mrb->exc) mrb_print_error(mrb);
}
