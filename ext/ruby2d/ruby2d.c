// Native C extension for Ruby and MRuby

#include "ruby2d.h"


// =============================================================================
// Global Variables
// =============================================================================

// Initialize shared data
bool R2D_diagnostics = false;

// Initialization status
static bool initted = false;

// MRuby context
#ifdef MRUBY
  static mrb_state *mrb;
#endif


// Pre-window display info — populated by R2D_Init, consumed by window_create
static float r2d_init_content_scale = 1.0f;
static float r2d_init_display_scale = 1.0f;
static float r2d_init_refresh_rate = 60.0f;
static int   r2d_init_display_width = 0;
static int   r2d_init_display_height = 0;
static int   r2d_init_display_pixel_width = 0;
static int   r2d_init_display_pixel_height = 0;

float R2D_GetInitDisplayScale(void)       { return r2d_init_display_scale; }
float R2D_GetInitContentScale(void)       { return r2d_init_content_scale; }
float R2D_GetInitRefreshRate(void)        { return r2d_init_refresh_rate; }
int   R2D_GetInitDisplayWidth(void)       { return r2d_init_display_width; }
int   R2D_GetInitDisplayHeight(void)      { return r2d_init_display_height; }
int   R2D_GetInitDisplayPixelWidth(void)  { return r2d_init_display_pixel_width; }
int   R2D_GetInitDisplayPixelHeight(void) { return r2d_init_display_pixel_height; }

// Ruby 2D module
R_CLASS ruby2d_module;


// =============================================================================
// Platform-Specific Code
// =============================================================================

/*
 * Provide a `vasprintf()` implementation for Windows
 */
#ifdef _WIN32
int vasprintf(char **strp, const char *fmt, va_list ap) {
  int r = -1, size = _vscprintf(fmt, ap);
  if ((size >= 0) && (size < INT_MAX)) {
    *strp = (char *)malloc(size + 1);
    if (*strp) {
      r = vsnprintf(*strp, size + 1, fmt, ap);
      if (r == -1) { free(*strp); *strp = 0; }
    }
  } else { *strp = 0; }
  return(r);
}
#endif


// =============================================================================
// Utility Functions
// =============================================================================

/*
 * Checks if a file exists and can be accessed
 */
bool R2D_FileExists(const char *path) {
  if (!path) return false;

  return access(path, F_OK) != -1;
}


/*
 * Logs standard messages to the console
 */
void R2D_Log(int type, const char *msg, ...) {

  // Always log if diagnostics set, or if a warning or error message
  if (R2D_diagnostics || type != R2D_INFO) {

    va_list args;
    va_start(args, msg);

    switch (type) {
      case R2D_INFO:
        fprintf(stderr, "\033[1;34m[INFO]\033[0m ");
        break;
      case R2D_WARN:
        fprintf(stderr, "\033[1;33m[WARN]\033[0m ");
        break;
      case R2D_ERROR:
        fprintf(stderr, "\033[1;31m[ERROR]\033[0m ");
        break;
    }

    vfprintf(stderr, msg, args);
    fprintf(stderr, "\n");
    va_end(args);
  }
}


/*
 * Warn once per process if an SDL render call reported failure. The draw path
 * calls these every frame, so a persistent GPU/driver fault would flood the
 * console — this emits a single diagnostic instead of silently rendering
 * nothing. `what` names the SDL function; the SDL error string is appended.
 */
void R2D_CheckSDL(bool ok, const char *what) {
  static bool warned = false;
  if (!ok && !warned) {
    R2D_Log(R2D_WARN, "%s failed: %s", what, SDL_GetError());
    warned = true;
  }
}


/*
 * Logs Ruby 2D errors to the console, with caller and message body
 */
void R2D_Error(const char *caller, const char *msg, ...) {
  va_list args;
  va_start(args, msg);
  char *fmsg = NULL;
  int len = vasprintf(&fmsg, msg, args);
  va_end(args);

  // On failure vasprintf leaves fmsg undefined; fall back to the raw format
  // string rather than log/free a garbage pointer while reporting an error.
  if (len >= 0 && fmsg) {
    R2D_Log(R2D_ERROR, "(%s) %s", caller, fmsg);
    free(fmsg);
  } else {
    R2D_Log(R2D_ERROR, "(%s) %s", caller, msg);
  }
}


/*
 * Enable/disable logging of diagnostics
 */
void R2D_Diagnostics(bool status) {
  R2D_diagnostics = status;
  R2D_Window *w = R2D_GetWindow();
  if (w) w->diagnostics = status;
}


/*
 * Enable/disable FPS display
 */
void R2D_ShowFPS(bool status) {
  if (R2D_GetWindow()) R2D_GetWindow()->show_fps = status;
}


// =============================================================================
// Initialization and Cleanup
// =============================================================================

/*
 * Initialize Ruby 2D subsystems
 */
bool R2D_Init() {
  if (initted) return true;

  R2D_Log(R2D_INFO, "Initializing Ruby 2D");

  // Initialize SDL (only needed subsystems)
  if (!SDL_Init(SDL_INIT_VIDEO | SDL_INIT_AUDIO | SDL_INIT_GAMEPAD)) {
    R2D_Error("SDL_Init", "%s", SDL_GetError());
    return false;
  }

  // Initialize SDL_ttf (SDL3 style: returns true on success)
  if (!TTF_Init()) {
    R2D_Error("TTF_Init", "%s", SDL_GetError());
    return false;
  }

  // The audio mixer device is intentionally NOT opened here. Opening the default
  // playback device fails on a headless/audio-blocked machine, and graphics must
  // not depend on that. Audio entry points call R2D_InitAudio() lazily instead.

  // Get display information (content scale, dimensions). Done early so Text and
  // Image can use it before a window is created. The r2d_init_* statics keep
  // their file-scope defaults until a display is found below.
  int display_count = 0;
  SDL_DisplayID *display_ids = SDL_GetDisplays(&display_count);
  if (display_ids && display_count > 0) {
    const SDL_DisplayMode *mode = SDL_GetCurrentDisplayMode(display_ids[0]);
    if (mode) {
      r2d_init_content_scale = SDL_GetDisplayContentScale(display_ids[0]);
      // SDL returns 0.0f if this query fails; clamp so it can't zero out
      // display_scale or become a divide-by-zero in the resize handler.
      if (r2d_init_content_scale <= 0.0f) r2d_init_content_scale = 1.0f;
      r2d_init_display_scale = mode->pixel_density * r2d_init_content_scale;
      r2d_init_refresh_rate = mode->refresh_rate;
      r2d_init_display_width = mode->w;
      r2d_init_display_height = mode->h;
      r2d_init_display_pixel_width  = (int)(mode->w * mode->pixel_density);
      r2d_init_display_pixel_height = (int)(mode->h * mode->pixel_density);

      R2D_Log(R2D_INFO, "Display (%u of %d)", display_ids[0], display_count);
      R2D_Log(R2D_INFO, "  width: %d", mode->w);
      R2D_Log(R2D_INFO, "  height: %d", mode->h);
      R2D_Log(R2D_INFO, "  pixel_width: %d", r2d_init_display_pixel_width);
      R2D_Log(R2D_INFO, "  pixel_height: %d", r2d_init_display_pixel_height);
      R2D_Log(R2D_INFO, "  pixel_density: %.2f", mode->pixel_density);
      R2D_Log(R2D_INFO, "  content_scale: %.2f", r2d_init_content_scale);
      R2D_Log(R2D_INFO, "  display_scale: %.2f", r2d_init_display_scale);
      R2D_Log(R2D_INFO, "  refresh_rate: %.2f", mode->refresh_rate);
    }
    SDL_free(display_ids);
  }

  // All subsystems initted
  initted = true;
  return true;
}


/*
 * Gets the primary display's dimensions
 */
void R2D_GetDisplayDimensions(int *w, int *h) {
  R2D_Init();
  int display_count = 0;
  SDL_DisplayID *display_ids = SDL_GetDisplays(&display_count);
  if (!display_ids || display_count < 1) {
    R2D_Error("SDL_GetDisplays", "%s", SDL_GetError());
    *w = 0;
    *h = 0;
    return;
  }
  const SDL_DisplayMode *mode = SDL_GetCurrentDisplayMode(display_ids[0]);
  if (!mode) {
    R2D_Error("SDL_GetCurrentDisplayMode", "%s", SDL_GetError());
    SDL_free(display_ids);
    *w = 0;
    *h = 0;
    return;
  }
  *w = mode->w;
  *h = mode->h;
  SDL_free(display_ids);
}


/*
 * Add gamepad mappings from a file. Returns the number of mappings added,
 * or -1 on error.
 */
int R2D_AddGamepadMappingsFromFile(const char *path) {
  if (!path) return -1;
  int result = SDL_AddGamepadMappingsFromFile(path);
  if (result < 0) {
    R2D_Error("R2D_AddGamepadMappingsFromFile", "%s", SDL_GetError());
  } else {
    R2D_Log(R2D_INFO, "Added %d gamepad mappings", result);
  }
  return result;
}


/*
 * Add a single gamepad mapping from a string. Returns 1 if the mapping was
 * added, 0 if it updated an existing one, or -1 on error.
 */
int R2D_AddGamepadMapping(const char *mapping) {
  if (!mapping) return -1;
  int result = SDL_AddGamepadMapping(mapping);
  if (result < 0) {
    R2D_Error("R2D_AddGamepadMapping", "%s", SDL_GetError());
  }
  return result;
}


/*
 * Trigger whole-gamepad rumble.
 */
bool R2D_RumbleGamepad(SDL_JoystickID id, double low, double high, double duration) {
  SDL_Gamepad *pad = SDL_GetGamepadFromID(id);
  if (!pad) return false;
  if (low  < 0.0) low  = 0.0; if (low  > 1.0) low  = 1.0;
  if (high < 0.0) high = 0.0; if (high > 1.0) high = 1.0;
  if (duration < 0.0) duration = 0.0;
  Uint16 lo = (Uint16)(low  * 0xFFFF);
  Uint16 hi = (Uint16)(high * 0xFFFF);
  Uint32 ms = (Uint32)(duration * 1000.0);
  return SDL_RumbleGamepad(pad, lo, hi, ms);
}


/*
 * Trigger trigger-only rumble.
 */
bool R2D_RumbleGamepadTriggers(SDL_JoystickID id, double left, double right, double duration) {
  SDL_Gamepad *pad = SDL_GetGamepadFromID(id);
  if (!pad) return false;
  if (left  < 0.0) left  = 0.0; if (left  > 1.0) left  = 1.0;
  if (right < 0.0) right = 0.0; if (right > 1.0) right = 1.0;
  if (duration < 0.0) duration = 0.0;
  Uint16 l = (Uint16)(left  * 0xFFFF);
  Uint16 r = (Uint16)(right * 0xFFFF);
  Uint32 ms = (Uint32)(duration * 1000.0);
  return SDL_RumbleGamepadTriggers(pad, l, r, ms);
}


/*
 * Set the gamepad's LED color (PS4/PS5).
 */
bool R2D_SetGamepadLED(SDL_JoystickID id, int r, int g, int b) {
  SDL_Gamepad *pad = SDL_GetGamepadFromID(id);
  if (!pad) return false;
  if (r < 0) r = 0; if (r > 255) r = 255;
  if (g < 0) g = 0; if (g > 255) g = 255;
  if (b < 0) b = 0; if (b > 255) b = 255;
  return SDL_SetGamepadLED(pad, (Uint8)r, (Uint8)g, (Uint8)b);
}


/*
 * Look up the gamepad's battery status. The high-level state and percent
 * are returned separately so the Ruby side can map them into the
 * documented :wired/:full/:medium/:low/:empty/nil vocabulary.
 */
int R2D_GetGamepadBattery(SDL_JoystickID id, int *out_percent) {
  if (out_percent) *out_percent = -1;
  SDL_Gamepad *pad = SDL_GetGamepadFromID(id);
  if (!pad) return R2D_GAMEPAD_BATTERY_UNKNOWN;
  int percent = -1;
  SDL_PowerState ps = SDL_GetGamepadPowerInfo(pad, &percent);
  if (out_percent) *out_percent = percent;
  switch (ps) {
    case SDL_POWERSTATE_NO_BATTERY:
    case SDL_POWERSTATE_CHARGING:
    case SDL_POWERSTATE_CHARGED:
      return R2D_GAMEPAD_BATTERY_WIRED;
    case SDL_POWERSTATE_ON_BATTERY:
      return R2D_GAMEPAD_BATTERY_ON_BATTERY;
    default:
      return R2D_GAMEPAD_BATTERY_UNKNOWN;
  }
}


/*
 * Capability checks for buttons / axes on a connected gamepad.
 */
bool R2D_GamepadHasButton(SDL_JoystickID id, int button) {
  SDL_Gamepad *pad = SDL_GetGamepadFromID(id);
  if (!pad) return false;
  return SDL_GamepadHasButton(pad, (SDL_GamepadButton)button);
}


bool R2D_GamepadHasAxis(SDL_JoystickID id, int axis) {
  SDL_Gamepad *pad = SDL_GetGamepadFromID(id);
  if (!pad) return false;
  return SDL_GamepadHasAxis(pad, (SDL_GamepadAxis)axis);
}


/*
 * Returns a bitfield of feedback capabilities for the gamepad.
 */
int R2D_GetGamepadCaps(SDL_JoystickID id) {
  SDL_Gamepad *pad = SDL_GetGamepadFromID(id);
  if (!pad) return 0;
  SDL_PropertiesID props = SDL_GetGamepadProperties(pad);
  if (!props) return 0;
  int caps = 0;
  if (SDL_GetBooleanProperty(props, SDL_PROP_GAMEPAD_CAP_RUMBLE_BOOLEAN, false))
    caps |= R2D_GAMEPAD_CAP_RUMBLE;
  if (SDL_GetBooleanProperty(props, SDL_PROP_GAMEPAD_CAP_TRIGGER_RUMBLE_BOOLEAN, false))
    caps |= R2D_GAMEPAD_CAP_RUMBLE_TRIGGERS;
  if (SDL_GetBooleanProperty(props, SDL_PROP_GAMEPAD_CAP_RGB_LED_BOOLEAN, false))
    caps |= R2D_GAMEPAD_CAP_RGB_LED;
  return caps;
}


// =============================================================================
// Module Methods
// =============================================================================

/*
 * Ruby2D.web?
 * Whether this build targets the web. Emscripten defines `__EMSCRIPTEN__` for
 * the WASM build and nothing else does, so the answer is settled at compile
 * time: a native build reports false, as does the gem running under CRuby.
 * Apps use it to size work to the target, which the web needs less of.
 */
static R_VAL ruby2d_web_p(RUBY2D_METHOD_ARGS_VARIADIC) {
#ifdef __EMSCRIPTEN__
  return R_TRUE;
#else
  return R_FALSE;
#endif
}


// =============================================================================
// Extension Initialization
// =============================================================================


#if defined(MRUBY) && !defined(__EMSCRIPTEN__)

#include <string.h>
#if defined(__APPLE__)
  #include <mach-o/dyld.h>
#elif defined(_WIN32)
  #include <windows.h>
  #include <direct.h>
  #define chdir _chdir
#endif

/*
 * Change the working directory to the one containing this executable, so
 * relative resource paths (notably the bundled default font `ruby2d/fonts/…`)
 * resolve no matter how the app was launched. A Finder-launched macOS .app
 * starts with the working directory set to `/`, which would otherwise break
 * the bundled-font lookup. Native builds only — the WASM build keeps its
 * Emscripten-preloaded filesystem rooted at the working directory.
 */
static void R2D_ChdirToExeDir(void) {
  char path[4096];

#if defined(__APPLE__)
  uint32_t size = sizeof(path);
  if (_NSGetExecutablePath(path, &size) != 0) return;
#elif defined(_WIN32)
  DWORD len = GetModuleFileNameA(NULL, path, sizeof(path));
  if (len == 0 || len >= sizeof(path)) return;
#else
  ssize_t len = readlink("/proc/self/exe", path, sizeof(path) - 1);
  if (len <= 0) return;
  path[len] = '\0';
#endif

  // Trim the trailing path component to get the containing directory
  char *sep = strrchr(path, '/');
#if defined(_WIN32)
  char *backslash = strrchr(path, '\\');
  if (backslash > sep) sep = backslash;
#endif
  if (!sep) return;
  *sep = '\0';

  if (chdir(path) != 0) R2D_Log(R2D_WARN, "Could not change directory to `%s`", path);
}

#endif


#ifdef MRUBY
/*
 * MRuby entry point. This is the one sanctioned exception to the "never call
 * `mrb_*` directly, use the `r_*` macros" rule (see AGENTS.md): it bootstraps,
 * runs, and tears down the very interpreter the `r_*` layer runs inside, so the
 * raw `mrb_open`/`mrb_load_irep`/`mrb_close` calls here have no abstraction to
 * route through (CRuby has no equivalent — its VM calls `Init_ruby2d` instead).
 *
 * Raw calls only, though: never exchange a compile-time symbol id (`MRB_SYM`
 * and friends, or vendored macros expanding to them) with `libmruby` here.
 * Presym ids are assigned per build, so these vendored headers' numbering can
 * be wrong for a cross-compiled target — intern at runtime with
 * `mrb_intern_lit` instead. The `SystemExit` status read below is a live case.
 */
int main() {
  // Open the MRuby environment
  mrb = mrb_open();
  if (!mrb) {
    R2D_Error("mrb_open", "Could not initialize the mruby interpreter");
    return EXIT_FAILURE;
  }

#ifndef __EMSCRIPTEN__
  R2D_ChdirToExeDir();
#endif

#else
/*
 * Ruby C extension init
 */
void Init_ruby2d() {
#endif

  // Ruby2D
  ruby2d_module = r_define_module("Ruby2D");
  r_define_class_method(ruby2d_module, "web?", ruby2d_web_p, r_args_variadic);

  // Initialize Ruby2D::Ext bindings (must come before any module that uses them)
  R2D_Ext_Init();

  // Initialize Ruby2D::Image native parts
  R2D_Image_Init();

  // Initialize Ruby2D::Text native parts
  R2D_Text_Init();

  // Initialize Ruby2D::BitmapText native parts
  R2D_BitmapText_Init();

  // Initialize Ruby2D::Canvas native parts
  R2D_Canvas_Init();

  // Initialize Ruby2D::Audio native parts
  R2D_Audio_Init();

  // Initialize Ruby2D::Ext keyboard bindings
  R2D_Keyboard_Init();

  // Initialize Ruby2D::Window native parts
  R2D_Window_Init();

#ifdef MRUBY
  // Load the Ruby 2D library
  mrb_load_irep(mrb, ruby2d_lib);
  if (mrb->exc) { mrb_print_error(mrb); mrb->exc = 0; }

  // Load the Ruby 2D app. A clean run returns success; a `Kernel#exit`
  // terminates with its own status; any other uncaught exception prints a
  // backtrace and returns failure — so a crashing app reports non-zero to the
  // shell/CI, matching CRuby and mruby's own `mruby` binary.
  int exit_code = EXIT_SUCCESS;
  mrb_load_irep(mrb, ruby2d_app);
  if (mrb->exc) {
    struct RException *e = (struct RException *)mrb->exc;
    // `Kernel#exit` raises SystemExit with the exit flag set. Honor its status
    // and terminate quietly, rather than printing a backtrace for what is an
    // ordinary, deliberate exit. Read the status by interning "status" in the
    // live interpreter instead of MRB_EXC_EXIT_STATUS's MRB_SYM(status): that
    // presym id, baked into these vendored headers, matches the native libmruby
    // but not the cross-compiled wasm one, where it reads back as nil and
    // aborts. Default to success.
    if (MRB_EXC_EXIT_P(e)) {
      mrb_value status = mrb_iv_get(mrb, mrb_obj_value(e), mrb_intern_lit(mrb, "status"));
      exit(mrb_integer_p(status) ? (int)mrb_integer(status) : EXIT_SUCCESS);
    }
    mrb_print_error(mrb);
    exit_code = EXIT_FAILURE;
  }

  // Close the MRuby environment
  mrb_close(mrb);

  return exit_code;
#endif
}
