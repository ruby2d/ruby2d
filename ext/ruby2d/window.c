// window.c

#include "ruby2d.h"
#include <math.h>  // isinf, for the Float::INFINITY (uncapped) fps_cap path


// =============================================================================
// Global Variables
// =============================================================================

#ifndef RUBY2D_NO_RUBY
R2D_DEFINE_DATA_TYPE(R2D_Window);
#endif

// The single active window instance. Other files access it via R2D_Get*() functions.
static R2D_Window *r2d_window = NULL;

#ifndef RUBY2D_NO_RUBY
// Ruby VALUE for the Window object — used by the mruby tick trampoline.
R_VAL ruby2d_window;
#endif

// Message from the last R2D_CreateWindow / R2D_ShowWindow failure. The Ruby
// bridge turns it into an exception; the Spinel build reads it over FFI,
// having no `r_raise`.
static char r2d_last_error[512] = {0};

const char *R2D_LastError(void) { return r2d_last_error; }

// Record a failure and return false, so callers can `return r2d_fail(...)`.
static bool r2d_fail(const char *msg, const char *detail) {
  SDL_snprintf(r2d_last_error, sizeof r2d_last_error, "%s%s%s",
               msg, detail ? ": " : "", detail ? detail : "");
  return false;
}

R2D_Window *R2D_GetWindow(void)     { return r2d_window; }
SDL_Renderer *R2D_GetRenderer(void) { return r2d_window ? r2d_window->sdl_renderer : NULL; }
float R2D_GetAssetScale(void)       { return r2d_window ? r2d_window->asset_scale : 1.0f; }
float R2D_GetDisplayScale(void)     { return r2d_window ? r2d_window->display_scale : 1.0f; }
void R2D_SetWindow(R2D_Window *w)   { r2d_window = w; }

// Window-specific ivar IDs. Shared id_width / id_height live in ext.c.
static R_ID id_title, id_icon, id_ext_window;
static R_ID id_resizable, id_highdpi, id_pixel_scale;
static R_ID id_viewport_mode;
static R_ID id_fps_cap, id_render_mode;
// Scale mode value symbols, not ivars.
static R_ID id_sm_linear, id_sm_nearest, id_sm_pixel_art;
static R_ID id_background, id_mouse_x, id_mouse_y;
static R_ID id_frames, id_fps, id_close;


/*
 * Initialize
 */
#ifndef RUBY2D_NO_RUBY
void R2D_Window_Init() {
  id_title      = r_id("@title");
  id_icon       = r_id("@icon");
  id_ext_window = r_id("@ext_window");
  id_resizable  = r_id("@resizable");
  id_highdpi      = r_id("@highdpi");
  id_pixel_scale  = r_id("@pixel_scale");
  id_viewport_mode   = r_id("@viewport_mode");
  id_fps_cap         = r_id("@fps_cap");
  id_render_mode     = r_id("@render_mode");
  id_sm_linear       = r_id("linear");
  id_sm_nearest      = r_id("nearest");
  id_sm_pixel_art    = r_id("pixel_art");
  id_background      = r_id("@background");
  id_mouse_x         = r_id("@mouse_x");
  id_mouse_y         = r_id("@mouse_y");
  id_frames          = r_id("@frames");
  id_fps             = r_id("@fps");
  id_close           = r_id("@close");

  r_define_class_method(ruby2d_ext_module, "window_create",                     ruby2d_ext_window_create,                     r_args_variadic);
  r_define_class_method(ruby2d_ext_module, "window_show",                       ruby2d_ext_window_show,                       r_args_variadic);
  r_define_class_method(ruby2d_ext_module, "poll_events",                       ruby2d_ext_window_poll_events,                r_args_variadic);
  r_define_class_method(ruby2d_ext_module, "drain_events",                      ruby2d_ext_window_drain_events,               r_args_variadic);
  r_define_class_method(ruby2d_ext_module, "begin_frame",                       ruby2d_ext_window_begin_frame,                r_args_variadic);
  r_define_class_method(ruby2d_ext_module, "end_frame",                         ruby2d_ext_window_end_frame,                  r_args_variadic);
  r_define_class_method(ruby2d_ext_module, "now",                               ruby2d_ext_now,                               r_args_variadic);
  r_define_class_method(ruby2d_ext_module, "window_get_display_dimensions",     ruby2d_ext_window_get_display_dimensions,     r_args_variadic);
  r_define_class_method(ruby2d_ext_module, "window_set_viewport_mode",          ruby2d_ext_window_set_viewport_mode,          r_args_variadic);
  r_define_class_method(ruby2d_ext_module, "window_set_icon",                   ruby2d_ext_window_set_icon,                   r_args_variadic);
  r_define_class_method(ruby2d_ext_module, "window_set_title",                  ruby2d_ext_window_set_title,                  r_args_variadic);
  r_define_class_method(ruby2d_ext_module, "window_set_resizable",              ruby2d_ext_window_set_resizable,              r_args_variadic);
  r_define_class_method(ruby2d_ext_module, "window_set_size",                   ruby2d_ext_window_set_size,                   r_args_variadic);
  r_define_class_method(ruby2d_ext_module, "window_diagnostics",                ruby2d_ext_window_diagnostics,                r_args_variadic);
  r_define_class_method(ruby2d_ext_module, "window_set_fps_cap",                ruby2d_ext_window_set_fps_cap,                r_args_variadic);
  r_define_class_method(ruby2d_ext_module, "window_show_fps",                   ruby2d_ext_window_show_fps,                   r_args_variadic);
  r_define_class_method(ruby2d_ext_module, "window_load_gamepad_mappings_file", ruby2d_ext_window_load_gamepad_mappings_file, r_args_variadic);
  r_define_class_method(ruby2d_ext_module, "window_add_gamepad_mapping",        ruby2d_ext_window_add_gamepad_mapping,        r_args_variadic);
  r_define_class_method(ruby2d_ext_module, "window_gamepad_rumble",             ruby2d_ext_window_gamepad_rumble,             r_args_variadic);
  r_define_class_method(ruby2d_ext_module, "window_gamepad_rumble_triggers",    ruby2d_ext_window_gamepad_rumble_triggers,    r_args_variadic);
  r_define_class_method(ruby2d_ext_module, "window_gamepad_set_led",            ruby2d_ext_window_gamepad_set_led,            r_args_variadic);
  r_define_class_method(ruby2d_ext_module, "window_gamepad_type",               ruby2d_ext_window_gamepad_type,               r_args_variadic);
  r_define_class_method(ruby2d_ext_module, "window_gamepad_battery",            ruby2d_ext_window_gamepad_battery,            r_args_variadic);
  r_define_class_method(ruby2d_ext_module, "window_gamepad_has_button",         ruby2d_ext_window_gamepad_has_button,         r_args_variadic);
  r_define_class_method(ruby2d_ext_module, "window_gamepad_has_axis",           ruby2d_ext_window_gamepad_has_axis,           r_args_variadic);
  r_define_class_method(ruby2d_ext_module, "window_gamepad_caps",               ruby2d_ext_window_gamepad_caps,               r_args_variadic);
  r_define_class_method(ruby2d_ext_module, "window_gamepad_debug_info",         ruby2d_ext_window_gamepad_debug_info,         r_args_variadic);
  r_define_class_method(ruby2d_ext_module, "window_gamepad_joystick_state",     ruby2d_ext_window_gamepad_joystick_state,     r_args_variadic);
  r_define_class_method(ruby2d_ext_module, "window_screenshot",                 ruby2d_ext_window_screenshot,                 r_args_variadic);
  r_define_class_method(ruby2d_ext_module, "window_show_cursor",                ruby2d_ext_window_show_cursor,                r_args_variadic);
  r_define_class_method(ruby2d_ext_module, "window_hide_cursor",                ruby2d_ext_window_hide_cursor,                r_args_variadic);
  r_define_class_method(ruby2d_ext_module, "window_cursor_visible",             ruby2d_ext_window_cursor_visible,             r_args_variadic);
  r_define_class_method(ruby2d_ext_module, "window_set_system_cursor",          ruby2d_ext_window_set_system_cursor,          r_args_variadic);
  r_define_class_method(ruby2d_ext_module, "window_close",                      ruby2d_ext_window_close,                      r_args_variadic);
  r_define_class_method(ruby2d_ext_module, "window_set_render_mode",            ruby2d_ext_window_set_render_mode,            r_args_variadic);
  r_define_class_method(ruby2d_ext_module, "window_set_scale_mode",             ruby2d_ext_window_set_scale_mode,             r_args_variadic);
  r_define_class_method(ruby2d_ext_module, "window_request_render",             ruby2d_ext_window_request_render,             r_args_variadic);
}
#endif


// =============================================================================
// Viewport Mode
// =============================================================================

/*
 * Parse a viewport mode name into an R2D_VIEWPORT_* constant. Returns
 * R2D_VIEWPORT_LETTERBOX for NULL or an unrecognized name. Ruby-free, so the
 * Spinel build can pass the mode as a string; the Ruby bridge converts its
 * symbol and calls through here, keeping one table of names.
 */
int R2D_ParseViewportModeName(const char *name) {
  if (name) {
    if (SDL_strcmp(name, "letterbox") == 0)     return R2D_VIEWPORT_LETTERBOX;
    else if (SDL_strcmp(name, "stretch") == 0)  return R2D_VIEWPORT_STRETCH;
    else if (SDL_strcmp(name, "integer") == 0)  return R2D_VIEWPORT_INTEGER;
    else if (SDL_strcmp(name, "overscan") == 0) return R2D_VIEWPORT_OVERSCAN;
    else if (SDL_strcmp(name, "expand") == 0)   return R2D_VIEWPORT_EXPAND;
    else if (SDL_strcmp(name, "fixed") == 0)    return R2D_VIEWPORT_FIXED;
  }
  return R2D_VIEWPORT_LETTERBOX;
}


/*
 * Parse a viewport mode symbol from Ruby into an R2D_VIEWPORT_* constant.
 * Returns R2D_VIEWPORT_LETTERBOX if the value is nil or unrecognized.
 */
#ifndef RUBY2D_NO_RUBY
static int R2D_ParseViewportMode(R_VAL vm_val) {
  if (!r_test(vm_val)) return R2D_VIEWPORT_LETTERBOX;

  return R2D_ParseViewportModeName(r_sym_name(vm_val));
}
#endif


/*
 * Compute and apply the fixed-mode viewport rect. Centers the viewport at 1:1
 * scale within the window, with no content scaling. The rect is in logical
 * (point) coordinates because SDL_SetRenderViewport interprets its rect in the
 * current scaled coordinate space.
 */
static void R2D_ApplyFixedViewport(R2D_Window *window) {
  float ds = (window->pixel_scale && (window->flags & R2D_HIGHDPI))
           ? 1.0f : window->display_scale;
  SDL_SetRenderScale(window->sdl_renderer, ds, ds);

  int vp_w = window->viewport.width;
  int vp_h = window->viewport.height;

  window->viewport.fixed_rect.x = (window->width - vp_w) / 2;
  window->viewport.fixed_rect.y = (window->height - vp_h) / 2;
  window->viewport.fixed_rect.w = vp_w;
  window->viewport.fixed_rect.h = vp_h;

  SDL_SetRenderViewport(window->sdl_renderer, &window->viewport.fixed_rect);
}


/*
 * Apply viewport scaling mode via SDL3 logical presentation.
 * Maps the R2D_VIEWPORT_* constants to SDL_RendererLogicalPresentation values
 * and configures the renderer accordingly. Fixed mode bypasses logical
 * presentation entirely and uses a manually centered viewport at 1:1 scale.
 */
void R2D_ApplyViewportMode(R2D_Window *window) {

  // Fixed mode: disable logical presentation, manage viewport manually
  if (window->viewport.mode == R2D_VIEWPORT_FIXED) {
    SDL_SetRenderLogicalPresentation(
      window->sdl_renderer, 0, 0, SDL_LOGICAL_PRESENTATION_DISABLED
    );
    R2D_ApplyFixedViewport(window);
    return;
  }

  // All other modes use SDL logical presentation — reset any manual viewport
  // and scale that fixed mode may have set.
  SDL_SetRenderViewport(window->sdl_renderer, NULL);
  SDL_SetRenderScale(window->sdl_renderer, 1.0f, 1.0f);

  SDL_RendererLogicalPresentation sdl_mode;

  switch (window->viewport.mode) {
    case R2D_VIEWPORT_STRETCH:
      sdl_mode = SDL_LOGICAL_PRESENTATION_STRETCH;
      break;
    case R2D_VIEWPORT_INTEGER:
      sdl_mode = SDL_LOGICAL_PRESENTATION_INTEGER_SCALE;
      break;
    case R2D_VIEWPORT_OVERSCAN:
      sdl_mode = SDL_LOGICAL_PRESENTATION_OVERSCAN;
      break;
    case R2D_VIEWPORT_EXPAND:
    case R2D_VIEWPORT_LETTERBOX:
    default:
      sdl_mode = SDL_LOGICAL_PRESENTATION_LETTERBOX;
      break;
  }

  if (!SDL_SetRenderLogicalPresentation(
    window->sdl_renderer,
    window->viewport.width,
    window->viewport.height,
    sdl_mode
  )) {
    R2D_Error("R2D_ApplyViewportMode", "SDL_SetRenderLogicalPresentation failed: %s", SDL_GetError());
  }
}


/*
 * Derive the render (physical) dimensions from the logical, user-intended
 * sizes: window `orig_width`/`orig_height` and `viewport.base_width`/`base_height`.
 * When pixel_scale is active on a HiDPI window, scale by display_scale once so
 * coordinates map 1:1 with physical pixels (and asset_scale drops to 1.0, since
 * assets are already authored in physical pixels); otherwise assets carry the
 * display scale. Idempotent by construction — it always recomputes from the
 * logical sizes, never from the current (possibly already-scaled) values — so it
 * can be re-applied on every set()/resize without compounding. Expects
 * `viewport.mode` and `pixel_scale` to be current.
 */
static void R2D_ApplyPixelScale(R2D_Window *window) {
  bool ps_active = window->pixel_scale && (window->flags & R2D_HIGHDPI);
  float ds = ps_active ? window->display_scale : 1.0f;

  window->width  = (int)(window->orig_width  * ds);
  window->height = (int)(window->orig_height * ds);

  // In expand mode the viewport always matches the window; other modes keep a
  // fixed logical canvas (base_*) that scales with pixel_scale.
  if (window->viewport.mode == R2D_VIEWPORT_EXPAND) {
    window->viewport.width  = window->width;
    window->viewport.height = window->height;
  } else {
    window->viewport.width  = (int)(window->viewport.base_width  * ds);
    window->viewport.height = (int)(window->viewport.base_height * ds);
  }

  window->asset_scale = ps_active ? 1.0f : window->display_scale;
}


// =============================================================================
// Render Mode
// =============================================================================

/*
 * Parse a render mode name into an R2D_RENDER_* constant. Returns
 * R2D_RENDER_CONTINUOUS for NULL or an unrecognized name. Ruby-free
 * counterpart to R2D_ParseRenderMode, as for the viewport modes above.
 */
int R2D_ParseRenderModeName(const char *name) {
  if (name && SDL_strcmp(name, "on_demand") == 0) return R2D_RENDER_ON_DEMAND;

  return R2D_RENDER_CONTINUOUS;
}


/*
 * Parse a render mode symbol from Ruby into an R2D_RENDER_* constant.
 * Returns R2D_RENDER_CONTINUOUS if the value is nil or unrecognized.
 */
#ifndef RUBY2D_NO_RUBY
static int R2D_ParseRenderMode(R_VAL rm_val) {
  if (!r_test(rm_val)) return R2D_RENDER_CONTINUOUS;

  return R2D_ParseRenderModeName(r_sym_name(rm_val));
}
#endif


// =============================================================================
// Scale Mode
// =============================================================================

/*
 * Parse a scale mode name into an SDL_ScaleMode. Returns `fallback` for NULL
 * or an unrecognized name. Ruby-free counterpart to R2D_ParseScaleMode, as for
 * the viewport and render modes above.
 */
SDL_ScaleMode R2D_ParseScaleModeName(const char *name, SDL_ScaleMode fallback) {
  if (name) {
    if (SDL_strcmp(name, "linear") == 0)         return SDL_SCALEMODE_LINEAR;
    else if (SDL_strcmp(name, "nearest") == 0)   return SDL_SCALEMODE_NEAREST;
    else if (SDL_strcmp(name, "pixel_art") == 0) return SDL_SCALEMODE_PIXELART;
  }
  return fallback;
}


/*
 * Parse a scale mode symbol from Ruby into an SDL_ScaleMode.
 * Returns `fallback` if the value is nil or unrecognized.
 */
#ifndef RUBY2D_NO_RUBY
static SDL_ScaleMode R2D_ParseScaleMode(R_VAL sm_val, SDL_ScaleMode fallback) {
  if (!r_test(sm_val)) return fallback;

  return R2D_ParseScaleModeName(r_sym_name(sm_val), fallback);
}
#endif


/*
 * Resolve a renderable's scale mode: its own `scale_mode:` when set, and the
 * window-wide default when nil.
 */
#ifndef RUBY2D_NO_RUBY
SDL_ScaleMode R2D_ResolveScaleMode(R_VAL obj) {
  SDL_ScaleMode fallback = r2d_window ? r2d_window->scale_mode : SDL_SCALEMODE_LINEAR;
  return R2D_ParseScaleMode(r_ivar_get(obj, id_scale_mode), fallback);
}
#endif


/*
 * Set a renderable's resolved scale mode on its texture. Modes are resolved
 * per draw rather than at texture creation, so a live `set scale_mode:`
 * reaches objects that already exist and the texture rebuilds in text.c and
 * font.c don't each have to re-apply. `applied` records the mode last pushed
 * so SDL is called only on a change; reset it to SDL_SCALEMODE_INVALID
 * wherever the texture is (re)created, since a fresh texture carries SDL's
 * own default rather than the old one's mode.
 */
void R2D_ApplyScaleMode(SDL_Texture *texture, R_VAL obj, SDL_ScaleMode *applied) {
  if (!texture) return;
  SDL_ScaleMode mode = R2D_ResolveScaleMode(obj);
  if (mode == *applied) return;
  SDL_SetTextureScaleMode(texture, mode);
  *applied = mode;
}


/*
 * The CPU-surface equivalent. PIXELART is a shader technique with no
 * software scaler behind it, so it degrades to nearest — which is what it
 * does at integer scales anyway.
 */
SDL_ScaleMode R2D_ResolveSurfaceScaleMode(R_VAL obj) {
  SDL_ScaleMode mode = R2D_ResolveScaleMode(obj);
  return mode == SDL_SCALEMODE_PIXELART ? SDL_SCALEMODE_NEAREST : mode;
}


// =============================================================================
// Window Creation and Setup
// =============================================================================

/*
 * Ruby2D::Window#ext_create
 */
/*
 * Initialize the engine and allocate the window with default values. Returns
 * false on failure, with the reason from R2D_LastError.
 *
 * Ruby-free core behind Ext.window_create. Only the values that must be right
 * before R2D_ShowWindow runs are parameters — everything else it would read
 * from Ruby (flags, render mode, pixel scale) is re-applied by R2D_ShowWindow
 * anyway, so passing it twice would just be two chances to disagree.
 *
 * Width or height may be R2D_DISPLAY_WIDTH / R2D_DISPLAY_HEIGHT to mean "fill
 * the display"; `title` and the viewport dimensions follow R2D_ShowWindow's
 * conventions (NULL, and non-positive for "unset").
 */
bool R2D_CreateWindow(const char *title, int width, int height,
                      int viewport_width, int viewport_height,
                      const char *viewport_mode) {
  r2d_last_error[0] = '\0';

  if (!R2D_Init()) return r2d_fail("Ruby2D: failed to initialize", SDL_GetError());

  // Use display dimensions from init-time query if requested
  if (width == R2D_DISPLAY_WIDTH) width = R2D_GetInitDisplayWidth();
  if (height == R2D_DISPLAY_HEIGHT) height = R2D_GetInitDisplayHeight();

  // Allocate window and set default values. Use calloc so every field starts
  // zeroed — defends against reads of any field not explicitly set below (e.g.
  // viewport.fixed_rect) and against future field additions.
  R2D_Window *window      = (R2D_Window *) calloc(1, sizeof(R2D_Window));
  if (!window) return r2d_fail("Ruby2D: failed to allocate window", NULL);

  window->title           = title;
  window->flags           = 0;  // re-applied by R2D_ShowWindow
  window->width           = width;
  window->height          = height;
  window->orig_width      = width;
  window->orig_height     = height;
  window->viewport.width  = viewport_width  > 0 ? viewport_width  : width;
  window->viewport.height = viewport_height > 0 ? viewport_height : height;
  window->viewport.base_width  = window->viewport.width;
  window->viewport.base_height = window->viewport.height;
  window->viewport.mode   = R2D_ParseViewportModeName(viewport_mode);

  window->fps_cap         = (int)R2D_GetInitRefreshRate();
  window->background.r    = 0.0;
  window->background.g    = 0.0;
  window->background.b    = 0.0;
  window->background.a    = 1.0;
  window->icon            = NULL;
  window->close           = true;
  window->pixel_scale     = false;                 // re-applied by R2D_ShowWindow
  window->render_mode     = R2D_RENDER_CONTINUOUS; // re-applied by R2D_ShowWindow
  window->scale_mode      = SDL_SCALEMODE_LINEAR;  // re-applied by R2D_ShowWindow

  // Start with render_pending set so the first tick always presents a frame,
  // even in on-demand mode before the app calls request_render.
  SDL_SetAtomicInt(&window->render_pending, 1);

  // Copy display info from pre-window statics (populated by R2D_Init)
  int dw = R2D_GetInitDisplayWidth();
  int dh = R2D_GetInitDisplayHeight();
  window->display_width = dw ? dw : width;
  window->display_height = dh ? dh : height;
  window->display_content_scale = R2D_GetInitContentScale();
  window->display_scale = R2D_GetInitDisplayScale();
  window->display_refresh_rate = R2D_GetInitRefreshRate();
  window->asset_scale = R2D_GetInitDisplayScale();
  window->display_pixel_width = R2D_GetInitDisplayPixelWidth();
  window->display_pixel_height = R2D_GetInitDisplayPixelHeight();
  window->diagnostics = false;
  window->show_fps = false;
  window->screenshot_path = NULL;

  // SDL window and renderer are created later, in R2D_ShowWindow.
  r2d_window = window;

  return true;
}


#ifndef RUBY2D_NO_RUBY
/*
 * Ruby2D::Window#ext_create
 *
 * Ruby bridge over R2D_CreateWindow, which also hands the allocated struct to
 * the window object so the GC frees it with the window.
 */
R_VAL ruby2d_ext_window_create(RUBY2D_METHOD_ARGS_VARIADIC) {
  RUBY2D_EXTRACT_VARIADIC;
  if (argc != 1) r_raise("Ruby2D::Ext.window_create expects 1 arg (window), got %d", (int)argc);
  R_VAL obj = argv[0];

  R_VAL vw_val = r_ivar_get(obj, id_viewport_width);
  R_VAL vh_val = r_ivar_get(obj, id_viewport_height);
  R_VAL vm_val = r_ivar_get(obj, id_viewport_mode);

  if (!R2D_CreateWindow(
    obj_str(obj, id_title), obj_int(obj, id_width), obj_int(obj, id_height),
    r_test(vw_val) ? NUM2INT(vw_val) : 0,
    r_test(vh_val) ? NUM2INT(vh_val) : 0,
    r_test(vm_val) ? r_sym_name(vm_val) : NULL
  )) {
    r_raise("%s", R2D_LastError());
  }

  obj_set_struct(obj, id_ext_window, R2D_Window, r2d_window);

  return R_TRUE;
}
#endif


// =============================================================================
// Per-Frame Ext Bindings
// =============================================================================
//
// Ruby owns frame sequencing via its `tick` method, which calls these Ext
// primitives each frame: poll_events → drain_events → begin_frame → end_frame.
// Events are queued into a C-side buffer and returned to Ruby as a flat array.

// Frame timing statics
Uint64 frames;
Uint64 perf_freq;
double target_frame;
static Uint64 frame_start;
static bool current_frame_rendered;

// Event buffer — grows as needed, reset each frame, never freed.
static R2D_QueuedEvent *event_buf = NULL;
static int event_count = 0;
static int event_capacity = 0;

static void event_buf_push(R2D_QueuedEvent ev) {
  if (event_count == event_capacity) {
    int new_capacity = event_capacity ? event_capacity * 2 : 64;
    R2D_QueuedEvent *grown = (R2D_QueuedEvent *)realloc(event_buf,
      new_capacity * sizeof(R2D_QueuedEvent));
    // On failure realloc leaves the old buffer intact; drop this event rather
    // than overwrite event_buf with NULL and crash on the next write.
    if (!grown) return;
    event_buf = grown;
    event_capacity = new_capacity;
  }
  event_buf[event_count++] = ev;
}

// Initial gamepad scan — runs once on the first poll_events call so that
// connect events for already-plugged-in pads appear in the first drain.
static bool first_poll = true;


/*
 * Ext.poll_events(window)
 *
 * Poll SDL events and held-input state, queue into the event buffer, and
 * update timing. Ruby-free: the resulting state lives on `r2d_window` and is
 * read back by the caller — `ruby2d_ext_window_poll_events` syncs it to ivars
 * for the mruby/CRuby bridge, while the Spinel build reads it through the flat
 * `R2D_Poll*` accessors below. Keeping one body means the two bridges can't
 * drift.
 */
void R2D_PollEvents(void) {
  frame_start = SDL_GetPerformanceCounter();
  event_count = 0;

  // On the first call, push connect events for already-plugged-in gamepads
  if (first_poll) {
    first_poll = false;
    int num_pads = 0;
    SDL_JoystickID *pads = SDL_GetGamepads(&num_pads);
    if (pads) {
      for (int i = 0; i < num_pads; i++) {
        SDL_JoystickID gid = pads[i];
        SDL_Gamepad *pad = SDL_GetGamepadFromID(gid);
        if (!pad) pad = SDL_OpenGamepad(gid);
        if (!pad) continue;
        // Own the name: drain frees it. SDL_GetGamepadName returns a borrowed
        // pointer that SDL_CloseGamepad frees, so copy it now (see drain).
        const char *name = SDL_GetGamepadName(pad);
        event_buf_push((R2D_QueuedEvent){
          .category = R2D_EVT_GAMEPAD, .type = R2D_GAMEPAD_CONNECT,
          .id = gid, .str = name ? SDL_strdup(name) : NULL
        });
      }
      SDL_free(pads);
    }
  }

  // Poll SDL events ///////////////////////////////////////////////////////////

  SDL_Event e;
  while (SDL_PollEvent(&e)) {
    SDL_ConvertEventToRenderCoordinates(r2d_window->sdl_renderer, &e);

    switch (e.type) {
      case SDL_EVENT_KEY_DOWN:
        if (e.key.repeat == 0) {
          event_buf_push((R2D_QueuedEvent){
            .category = R2D_EVT_KEY, .type = R2D_KEY_DOWN,
            .id = e.key.scancode
          });
        }
        break;

      case SDL_EVENT_KEY_UP:
        event_buf_push((R2D_QueuedEvent){
          .category = R2D_EVT_KEY, .type = R2D_KEY_UP,
          .id = e.key.scancode
        });
        break;

      case SDL_EVENT_MOUSE_BUTTON_DOWN:
      case SDL_EVENT_MOUSE_BUTTON_UP:
        event_buf_push((R2D_QueuedEvent){
          .category = R2D_EVT_MOUSE,
          .type = e.type == SDL_EVENT_MOUSE_BUTTON_DOWN ? R2D_MOUSE_DOWN : R2D_MOUSE_UP,
          .button = e.button.button,
          .x = (int)e.button.x, .y = (int)e.button.y
        });
        break;

      case SDL_EVENT_MOUSE_WHEEL:
        event_buf_push((R2D_QueuedEvent){
          .category = R2D_EVT_MOUSE, .type = R2D_MOUSE_SCROLL,
          .direction = e.wheel.direction,
          .delta_x = e.wheel.x, .delta_y = -e.wheel.y
        });
        break;

      case SDL_EVENT_MOUSE_MOTION:
        event_buf_push((R2D_QueuedEvent){
          .category = R2D_EVT_MOUSE, .type = R2D_MOUSE_MOVE,
          .x = (int)e.motion.x, .y = (int)e.motion.y,
          .delta_x = e.motion.xrel, .delta_y = e.motion.yrel
        });
        break;

      case SDL_EVENT_GAMEPAD_AXIS_MOTION:
        event_buf_push((R2D_QueuedEvent){
          .category = R2D_EVT_GAMEPAD, .type = R2D_GAMEPAD_AXIS,
          .id = e.gaxis.which, .axis = e.gaxis.axis, .value = e.gaxis.value
        });
        break;

      case SDL_EVENT_GAMEPAD_BUTTON_DOWN:
      case SDL_EVENT_GAMEPAD_BUTTON_UP:
        event_buf_push((R2D_QueuedEvent){
          .category = R2D_EVT_GAMEPAD,
          .type = e.type == SDL_EVENT_GAMEPAD_BUTTON_DOWN
            ? R2D_GAMEPAD_BUTTON_DOWN : R2D_GAMEPAD_BUTTON_UP,
          .id = e.gbutton.which, .button = e.gbutton.button
        });
        break;

      case SDL_EVENT_GAMEPAD_ADDED: {
        SDL_JoystickID gid = e.gdevice.which;
        SDL_Gamepad *pad = SDL_OpenGamepad(gid);
        if (!pad) {
          R2D_Error("SDL_OpenGamepad", "SDL_OpenGamepad(%u) failed: %s", (unsigned)gid, SDL_GetError());
        } else {
          // Own the name: drain frees it. SDL_GetGamepadName returns a borrowed
          // pointer that SDL_CloseGamepad frees, so copy it now (see drain).
          const char *name = SDL_GetGamepadName(pad);
          R2D_Log(R2D_INFO, "Gamepad added: id=%u, name=%s", (unsigned)gid, name);
          event_buf_push((R2D_QueuedEvent){
            .category = R2D_EVT_GAMEPAD, .type = R2D_GAMEPAD_CONNECT,
            .id = gid, .str = name ? SDL_strdup(name) : NULL
          });
        }
        break;
      }

      case SDL_EVENT_GAMEPAD_REMOVED: {
        SDL_JoystickID gid = e.gdevice.which;
        SDL_Gamepad *pad = SDL_GetGamepadFromID(gid);
        R2D_Log(R2D_INFO, "Gamepad removed: id=%u", (unsigned)gid);
        event_buf_push((R2D_QueuedEvent){
          .category = R2D_EVT_GAMEPAD, .type = R2D_GAMEPAD_DISCONNECT,
          .id = gid
        });
        if (pad) SDL_CloseGamepad(pad);
        break;
      }

      case SDL_EVENT_WINDOW_RESIZED:
        // New logical (user-intended) window size from the OS event, before any
        // pixel_scale multiplier. R2D_ApplyPixelScale derives the render size.
        r2d_window->orig_width  = (int)(e.window.data1 / r2d_window->display_content_scale);
        r2d_window->orig_height = (int)(e.window.data2 / r2d_window->display_content_scale);

        // In expand mode the viewport tracks the window, so its logical base
        // follows the new size; fixed/scaled modes keep their base canvas.
        if (r2d_window->viewport.mode == R2D_VIEWPORT_EXPAND) {
          r2d_window->viewport.base_width  = r2d_window->orig_width;
          r2d_window->viewport.base_height = r2d_window->orig_height;
        }

        R2D_ApplyPixelScale(r2d_window);
        R2D_ApplyViewportMode(r2d_window);

        SDL_SetAtomicInt(&r2d_window->render_pending, 1);
        break;

      case SDL_EVENT_WINDOW_EXPOSED:
      case SDL_EVENT_WINDOW_SHOWN:
      case SDL_EVENT_WINDOW_DISPLAY_CHANGED:
        SDL_SetAtomicInt(&r2d_window->render_pending, 1);
        break;

      case SDL_EVENT_WINDOW_MOUSE_ENTER:
      case SDL_EVENT_WINDOW_MOUSE_LEAVE:
        event_buf_push((R2D_QueuedEvent){
          .category = R2D_EVT_MOUSE,
          .type = e.type == SDL_EVENT_WINDOW_MOUSE_ENTER
            ? R2D_MOUSE_ENTER : R2D_MOUSE_LEAVE
        });
        break;

      case SDL_EVENT_QUIT:
        event_buf_push((R2D_QueuedEvent){ .category = R2D_EVT_CLOSE });
        break;
    }
  }

  // Detect keys held down. Each held key queues its scancode, which drain
  // translates to a name symbol via R2D_KeyName; interning is a lookup, not an
  // allocation, so the per-frame path allocates nothing.
  int num_keys;
  const bool *key_state = SDL_GetKeyboardState(&num_keys);
  for (int i = 0; i < num_keys; i++) {
    if (key_state[i]) {
      event_buf_push((R2D_QueuedEvent){
        .category = R2D_EVT_KEY, .type = R2D_KEY_HELD,
        .id = i
      });
    }
  }

  // Get and store mouse position in logical renderer coordinates
  float ms_x, ms_y;
  Uint32 mouse_buttons = SDL_GetMouseState(&ms_x, &ms_y);
  float logical_x, logical_y;
  SDL_RenderCoordinatesFromWindow(r2d_window->sdl_renderer, ms_x, ms_y, &logical_x, &logical_y);
  r2d_window->mouse.x = (int)logical_x;
  r2d_window->mouse.y = (int)logical_y;

  // Detect mouse buttons held down
  static const int mouse_held_buttons[] = {
    R2D_MOUSE_LEFT, R2D_MOUSE_MIDDLE, R2D_MOUSE_RIGHT, R2D_MOUSE_X1, R2D_MOUSE_X2
  };
  for (int i = 0; i < 5; i++) {
    int btn = mouse_held_buttons[i];
    if (mouse_buttons & SDL_BUTTON_MASK(btn)) {
      event_buf_push((R2D_QueuedEvent){
        .category = R2D_EVT_MOUSE, .type = R2D_MOUSE_HELD,
        .button = btn, .x = (int)logical_x, .y = (int)logical_y
      });
    }
  }

  // Detect gamepad buttons held down. Gated on SDL_HasGamepad(): with no pad
  // connected — the common case — this skips SDL_GetGamepads, whose returned
  // ID array is a per-frame malloc/free that an empty window shouldn't pay.
  if (SDL_HasGamepad()) {
    int num_pads = 0;
    SDL_JoystickID *pads = SDL_GetGamepads(&num_pads);
    if (pads) {
      for (int i = 0; i < num_pads; i++) {
        SDL_Gamepad *pad = SDL_GetGamepadFromID(pads[i]);
        if (!pad) continue;
        for (int b = 0; b < R2D_BUTTON_COUNT; b++) {
          if (SDL_GetGamepadButton(pad, b)) {
            event_buf_push((R2D_QueuedEvent){
              .category = R2D_EVT_GAMEPAD, .type = R2D_GAMEPAD_BUTTON_HELD,
              .id = pads[i], .button = b
            });
          }
        }
      }
      SDL_free(pads);
    }
  }
}


/*
 * Flat accessors for the state R2D_PollEvents leaves on `r2d_window`. The
 * Ruby bridge reads it straight off the struct when syncing ivars; the Spinel
 * build has no Ruby objects, so it calls these over FFI instead.
 */
int  R2D_PollMouseX(void)        { return r2d_window ? r2d_window->mouse.x : 0; }
int  R2D_PollMouseY(void)        { return r2d_window ? r2d_window->mouse.y : 0; }
int  R2D_PollWidth(void)         { return r2d_window ? r2d_window->orig_width : 0; }
int  R2D_PollHeight(void)        { return r2d_window ? r2d_window->orig_height : 0; }
int  R2D_PollViewportWidth(void) { return r2d_window ? r2d_window->viewport.width : 0; }
int  R2D_PollViewportHeight(void){ return r2d_window ? r2d_window->viewport.height : 0; }

/*
 * Whether the app should stop looping: the window is already closed, or the
 * last poll saw a quit. The second half matters only here. Every other engine
 * reads the queued R2D_EVT_CLOSE out of `drain_events` and closes the window
 * from Ruby, which sets `close`; the Spinel build has no way to return an
 * event array over FFI, so without this the red X and Cmd-Q were polled,
 * queued, and then dropped, and `tick until @close` never ended.
 */
bool R2D_PollClosed(void) {
  if (!r2d_window) return true;
  if (r2d_window->close) return true;

  for (int i = 0; i < event_count; i++) {
    if (event_buf[i].category == R2D_EVT_CLOSE) return true;
  }
  return false;
}


/*
 * Ext.poll_events(window) → nil
 *
 * Ruby bridge over R2D_PollEvents: poll, then sync the resulting C state to the
 * window's ivars.
 */
#ifndef RUBY2D_NO_RUBY
R_VAL ruby2d_ext_window_poll_events(RUBY2D_METHOD_ARGS_VARIADIC) {
  RUBY2D_EXTRACT_VARIADIC;
  if (argc != 1) r_raise("Ruby2D::Ext.poll_events expects 1 arg (window), got %d", (int)argc);
  R_VAL obj = argv[0];

  R2D_PollEvents();

  // Sync C state to Ruby ivars. Frame count and fps are deferred to begin_frame
  // so they track frames actually presented, not ticks — in :on_demand mode most
  // ticks present nothing.
  r_ivar_set(obj, id_mouse_x, INT2NUM(r2d_window->mouse.x));
  r_ivar_set(obj, id_mouse_y, INT2NUM(r2d_window->mouse.y));
  // width/height are the logical (user-intended) size per USAGE.md — sync
  // orig_width/orig_height, not window->width/height, which carry the physical
  // render size under pixel_scale. viewport_width/height expose the physical size.
  r_ivar_set(obj, id_width, INT2NUM(r2d_window->orig_width));
  r_ivar_set(obj, id_height, INT2NUM(r2d_window->orig_height));
  r_ivar_set(obj, id_viewport_width, INT2NUM(r2d_window->viewport.width));
  r_ivar_set(obj, id_viewport_height, INT2NUM(r2d_window->viewport.height));

  if (r2d_window->close) r_ivar_set(obj, id_close, R_TRUE);

  return R_NIL;
}
#endif


/*
 * Ext.drain_events(window) → flat Array or nil
 *
 * Return queued events as a flat array with R2D_EVT_STRIDE elements per event:
 * [category, type, id, button, direction, axis, x, y, delta_x, delta_y, value, str]
 * `id` is an Integer for every category except R2D_EVT_KEY, where it is the
 * key's name Symbol — the scancode is translated here and never reaches Ruby.
 * Returns nil when no events are queued (the common case, every frame).
 */
#ifndef RUBY2D_NO_RUBY
R_VAL ruby2d_ext_window_drain_events(RUBY2D_METHOD_ARGS_VARIADIC) {
  RUBY2D_EXTRACT_VARIADIC;
  (void)argc; (void)argv;

  // Most frames have no events — return nil instead of allocating an empty
  // array 60–120 times a second. The Ruby side skips dispatch on nil.
  if (event_count == 0) return R_NIL;

  R_VAL ary = r_ary_new();
  for (int i = 0; i < event_count; i++) {
    R2D_QueuedEvent *ev = &event_buf[i];
    r_ary_push(ary, INT2NUM(ev->category));
    r_ary_push(ary, INT2NUM(ev->type));
    // Key events carry their name symbol in the id slot; every other category
    // carries an integer there. Ruby never sees a scancode: the SDL code goes
    // no further than this translation. Interning is a lookup, not an
    // allocation, so the per-frame held-key path allocates nothing.
    if (ev->category == R2D_EVT_KEY) {
      r_ary_push(ary, r_char_to_sym(R2D_KeyName(ev->id)));
    } else {
      r_ary_push(ary, INT2NUM(ev->id));
    }
    r_ary_push(ary, INT2NUM(ev->button));
    r_ary_push(ary, INT2NUM(ev->direction));
    r_ary_push(ary, INT2NUM(ev->axis));
    r_ary_push(ary, INT2NUM(ev->x));
    r_ary_push(ary, INT2NUM(ev->y));
    r_ary_push(ary, DBL2NUM(ev->delta_x));
    r_ary_push(ary, DBL2NUM(ev->delta_y));
    r_ary_push(ary, INT2NUM(ev->value));
    r_ary_push(ary, ev->str ? r_str_new(ev->str) : R_NIL);
    // Ownership contract: poll strdups gamepad-connect names into ev->str, drain
    // frees them here. All other events leave ev->str NULL via designated init,
    // so freeing every non-NULL ev->str is correct.
    if (ev->str) {
      SDL_free((void *)ev->str);
      ev->str = NULL;
    }
  }
  event_count = 0;
  return ary;
}
#endif


/*
 * Take the background color as flat components, decide whether to render, and
 * clear. Returns true if the caller should draw the scene this frame.
 *
 * Ruby-free core behind Ext.begin_frame: the Ruby bridge reads the background
 * off the window's Color ivar and passes it in, while the Spinel build passes
 * the components directly. Frame count and fps land on `r2d_window` and are
 * read back via R2D_FrameCount / R2D_Fps.
 */
bool R2D_BeginFrame(float bg_r, float bg_g, float bg_b, float bg_a) {
  r2d_window->background.r = bg_r;
  r2d_window->background.g = bg_g;
  r2d_window->background.b = bg_b;
  r2d_window->background.a = bg_a;

  int was_pending = SDL_SetAtomicInt(&r2d_window->render_pending, 0);
  current_frame_rendered =
    r2d_window->render_mode == R2D_RENDER_CONTINUOUS ||
    was_pending != 0 ||
    r2d_window->screenshot_path != NULL;

  if (current_frame_rendered) {
    // Count and time only frames actually drawn. In :on_demand mode the tick
    // loop still runs every cycle for input and pacing but presents only when a
    // frame is pending, so frames/fps must advance per present, not per tick.
    // (In :continuous mode every tick renders, so this is unchanged.)
    frames++;
    r2d_window->frames = frames;
    r2d_window->fps    = R2D_GetFrameRate();

    if (r2d_window->viewport.mode == R2D_VIEWPORT_FIXED) {
      SDL_SetRenderViewport(r2d_window->sdl_renderer, NULL);
      SDL_SetRenderDrawColorFloat(r2d_window->sdl_renderer, 0, 0, 0, 1);
      SDL_RenderClear(r2d_window->sdl_renderer);
      SDL_SetRenderViewport(
        r2d_window->sdl_renderer, &r2d_window->viewport.fixed_rect
      );
      SDL_SetRenderDrawColorFloat(
        r2d_window->sdl_renderer,
        r2d_window->background.r,
        r2d_window->background.g,
        r2d_window->background.b,
        r2d_window->background.a
      );
      SDL_RenderFillRect(r2d_window->sdl_renderer, NULL);
    } else {
      SDL_SetRenderDrawColorFloat(
        r2d_window->sdl_renderer,
        r2d_window->background.r,
        r2d_window->background.g,
        r2d_window->background.b,
        r2d_window->background.a
      );
      SDL_RenderClear(r2d_window->sdl_renderer);
    }
  }

  return current_frame_rendered;
}


// Frame count and fps for the frame R2D_BeginFrame just admitted. Deferred from
// polling so they track frames actually presented, not ticks — in :on_demand
// mode most ticks present nothing.
unsigned long long R2D_FrameCount(void) { return r2d_window ? r2d_window->frames : 0; }
double             R2D_Fps(void)        { return r2d_window ? r2d_window->fps : 0.0; }


/*
 * Ext.begin_frame(window) → true/false
 *
 * Ruby bridge over R2D_BeginFrame: read the background off the window's Color
 * ivar, then sync the resulting frame count and fps back.
 */
#ifndef RUBY2D_NO_RUBY
R_VAL ruby2d_ext_window_begin_frame(RUBY2D_METHOD_ARGS_VARIADIC) {
  RUBY2D_EXTRACT_VARIADIC;
  if (argc != 1) r_raise("Ruby2D::Ext.begin_frame expects 1 arg (window), got %d", (int)argc);
  R_VAL obj = argv[0];

  R_VAL bc = r_ivar_get(obj, id_background);
  bool rendered = R2D_BeginFrame(
    NUM2DBL(r_ivar_get(bc, id_r)),
    NUM2DBL(r_ivar_get(bc, id_g)),
    NUM2DBL(r_ivar_get(bc, id_b)),
    NUM2DBL(r_ivar_get(bc, id_a))
  );

  if (rendered) {
    r_ivar_set(obj, id_frames, ULL2NUM(r2d_window->frames));
    r_ivar_set(obj, id_fps, DBL2NUM(r2d_window->fps));
  }

  return rendered ? R_TRUE : R_FALSE;
}
#endif


/*
 * FPS overlay, deferred screenshot, present (if rendered), and frame cap.
 * Ruby-free core behind Ext.end_frame, which never read the window object.
 */
void R2D_EndFrame(void) {
  if (current_frame_rendered) {
    if (r2d_window->diagnostics || r2d_window->show_fps) {
      R2D_DrawFrameRate(r2d_window);
    }

    if (r2d_window->screenshot_path) {
      R2D_Screenshot(r2d_window, r2d_window->screenshot_path);
      free(r2d_window->screenshot_path);
      r2d_window->screenshot_path = NULL;
    }

    if (r2d_window->sdl_renderer) {
      SDL_RenderPresent(r2d_window->sdl_renderer);
    }
  }

  #ifndef __EMSCRIPTEN__
  if (target_frame > 0.0) {
    Uint64 frame_end = SDL_GetPerformanceCounter();
    double elapsed = (double)(frame_end - frame_start) / perf_freq;
    double remaining = target_frame - elapsed;

    if (remaining > 0.0) {
      SDL_DelayPrecise((Uint64)(remaining * 1e9));
    }
  }
  #endif
}


/*
 * Ext.end_frame(window)
 */
#ifndef RUBY2D_NO_RUBY
R_VAL ruby2d_ext_window_end_frame(RUBY2D_METHOD_ARGS_VARIADIC) {
  RUBY2D_EXTRACT_VARIADIC;
  (void)argc; (void)argv;

  R2D_EndFrame();

  return R_NIL;
}
#endif


// Origin the Ext.now clock is measured from, so it reads zero when a program
// starts rather than when SDL did. Natively the two amount to the same thing —
// the engine comes up on first use and lives as long as the process does — so
// the origin stays 0 and nothing rebases it. The browser is the exception: SDL
// is initialized once per page load and never quits, while try_run_code starts
// a new program on every Run. Rebasing there keeps `elapsed` meaning "since
// this program started" on both, so motion derived from it begins at the
// beginning rather than picking up wherever the page's uptime had reached.
static Uint64 r2d_time_origin_ns = 0;


/*
 * Ext.now
 *
 * Monotonic, high-resolution time in seconds since the program started. This is
 * the clock the per-frame delta time is measured from. On Emscripten
 * SDL_GetTicksNS maps to performance.now() — the same monotonic high-resolution
 * source the requestAnimationFrame timestamp is drawn from — which is what makes
 * web motion smooth. Time.now (gettimeofday → Date.now on the web) is only ~1 ms
 * and is wall-clock (non-monotonic), so it quantizes and can tick backward,
 * jittering frame pacing. This is the dt clock on mruby (native and web); CRuby
 * uses Process.clock_gettime(CLOCK_MONOTONIC), which is already monotonic.
 */
double R2D_Now(void) {
  return (double)(SDL_GetTicksNS() - r2d_time_origin_ns) / 1.0e9;
}

#ifndef RUBY2D_NO_RUBY
R_VAL ruby2d_ext_now(RUBY2D_METHOD_ARGS_VARIADIC) {
  RUBY2D_EXTRACT_VARIADIC;
  (void)argc; (void)argv;
  return DBL2NUM(R2D_Now());
}
#endif


// =============================================================================
// Window Show and Initialization
// =============================================================================

#ifdef __EMSCRIPTEN__
// Web frame pacing. The browser owns the loop via requestAnimationFrame, which
// always fires at the display refresh rate, so a numeric fps_cap is honored by
// decimation: EM_TIMING_RAF with interval N runs the tick on every Nth vsync
// (Emscripten's runner skips the frames in between), giving refresh/N — only
// divisors of the refresh rate are achievable (120Hz → 60, 40, 30…). N derives
// from a measured refresh estimate because SDL's Emscripten backend never
// reports the display's refresh rate. `:infinity` switches to free-running
// setTimeout(0), the browser's only faster-than-vsync loop, for benchmarking.
typedef enum {
  WASM_PACE_REFRESH,  // no user cap: tick every animation frame (interval 1)
  WASM_PACE_CAPPED,   // numeric cap: decimated rAF (interval N)
  WASM_PACE_FREE      // :infinity: free-running setTimeout(0)
} WasmPaceMode;

static WasmPaceMode wasm_pace_mode = WASM_PACE_REFRESH;
static double wasm_pace_cap = 0.0;       // target fps when WASM_PACE_CAPPED
static double wasm_last_tick_time = 0.0; // seconds; 0 = no sample yet
static double wasm_refresh_est = 0.0;    // smoothed rAF rate (Hz); 0 = unknown
static int    wasm_interval = 1;         // current decimation interval N

// Map the Ruby fps_cap value onto a web pace mode: nil → display refresh,
// Float::INFINITY → free-running, a number → capped. Called from ext_show and
// ext_set_fps_cap; the trampoline applies the mode after every tick.
static void wasm_set_pace_mode(R_VAL fps_cap_val) {
  if (!r_test(fps_cap_val)) {
    wasm_pace_mode = WASM_PACE_REFRESH;
  } else if (isinf(NUM2DBL(fps_cap_val))) {
    wasm_pace_mode = WASM_PACE_FREE;
  } else {
    wasm_pace_mode = WASM_PACE_CAPPED;
    wasm_pace_cap = NUM2DBL(fps_cap_val);
  }
}

static void wasm_tick_trampoline(void) {
  // Release the tick's return value from the GC arena — this call runs outside
  // the VM once per frame, and mrb_funcall arena-protects what it returns, so
  // a heap-object return would otherwise accumulate one pinned object per
  // frame, forever.
  int ai = r_gc_arena_save();
  r_funcall(ruby2d_window, "tick", 0);
  r_gc_arena_restore(ai);

  // Re-assert the loop timing after every tick, not once: SDL's Emscripten
  // backend defers the renderer's creation-time vsync-0 swap interval
  // (`pending_swap_interval`) and applies it during the first SDL_PumpEvents —
  // mid-tick, after any one-shot pin — silently flipping the loop to
  // free-running setTimeout(0). Pinning after the tick always gets the last
  // word. (It can't run at setup time anyway: emscripten_set_main_loop_timing
  // only takes effect once a main loop is registered.)

  if (wasm_pace_mode == WASM_PACE_FREE) {
    wasm_last_tick_time = 0.0;  // rAF rate can't be sampled from setTimeout ticks
    emscripten_set_main_loop_timing(EM_TIMING_SETTIMEOUT, 0);
    return;
  }

  // Estimate the raw rAF (display refresh) rate from tick spacing: ticks arrive
  // every `wasm_interval` animation frames, so raw = interval / dt. Samples
  // outside plausible display rates (20–400 Hz) are dropped — the first tick,
  // hidden-tab gaps, and mode switches all land there.
  double now = (double)SDL_GetTicksNS() / 1.0e9;
  if (wasm_last_tick_time > 0.0) {
    double dt = now - wasm_last_tick_time;
    double raw = dt > 0.0 ? (double)wasm_interval / dt : 0.0;
    if (raw >= 20.0 && raw <= 400.0) {
      wasm_refresh_est = wasm_refresh_est > 0.0
                       ? wasm_refresh_est * 0.9 + raw * 0.1
                       : raw;
    }
  }
  wasm_last_tick_time = now;

  int interval = 1;
  if (wasm_pace_mode == WASM_PACE_CAPPED &&
      wasm_refresh_est > 0.0 && wasm_pace_cap > 0.0) {
    // Keep the current interval while the ideal ratio stays within ±0.55 of
    // it — hysteresis so estimator noise at a rounding boundary can't
    // oscillate N (visibly flipping the frame rate) between adjacent values.
    double ratio = wasm_refresh_est / wasm_pace_cap;
    interval = wasm_interval;
    if (fabs(ratio - (double)wasm_interval) > 0.55) {
      interval = (int)SDL_round(ratio);
      if (interval < 1) interval = 1;
    }
  }
  wasm_interval = interval;
  emscripten_set_main_loop_timing(EM_TIMING_RAF, interval);
}
#endif


/*
 * Create the SDL window and renderer, apply window/viewport/render settings,
 * and reveal the window. Returns false on failure, with the reason available
 * from R2D_LastError.
 *
 * Ruby-free core behind Ext.window_show, taking as flat arguments everything
 * the bridge previously read off the window object. `fps_cap` is negative for
 * "not set" (fall back to the display refresh rate) and infinite for uncapped;
 * `icon` and the mode names may be NULL. Does *not* run a main loop — the
 * caller owns that, as Window#show already does on CRuby.
 */
bool R2D_ShowWindow(const char *title, int width, int height,
                    bool resizable, bool highdpi, bool pixel_scale,
                    double fps_cap,
                    int viewport_width, int viewport_height,
                    const char *viewport_mode, const char *render_mode,
                    const char *scale_mode, const char *icon) {
  r2d_last_error[0] = '\0';

  if (!r2d_window) {
    return r2d_fail("Ruby2D: window cannot be shown (native window is NULL)", NULL);
  }

  int flags = 0;
  if (resizable) flags |= R2D_RESIZABLE;
  if (highdpi)   flags |= R2D_HIGHDPI;
  r2d_window->flags = flags;

  // Scale window dimensions by content_scale for correct visual size on all
  // platforms. On macOS content_scale is 1.0 (coordinates are already logical
  // points); on Windows with DPI scaling it compensates for physical pixels.
  float cs = r2d_window->display_content_scale;
  int win_w = (int)(width  * cs);
  int win_h = (int)(height * cs);

  // Create the window hidden on native platforms so it can be centered before
  // its first paint; repositioning an already-visible window makes it visibly
  // jump. On the web the "window" is the page canvas — there is nothing to
  // position — so it is created shown, as before.
  int create_flags = r2d_window->flags;
  #ifndef __EMSCRIPTEN__
  create_flags |= SDL_WINDOW_HIDDEN;
  #endif

  // Create SDL window and renderer
  if (!SDL_CreateWindowAndRenderer(
    title, win_w, win_h,
    create_flags,
    &r2d_window->sdl_window, &r2d_window->sdl_renderer
  )) {
    return r2d_fail("Ruby2D: failed to create window and renderer", SDL_GetError());
  }

  // Defensive check: ensure both window and renderer are non-NULL
  if (!r2d_window->sdl_window || !r2d_window->sdl_renderer) {
    return r2d_fail("Ruby2D: window or renderer is NULL after creation", SDL_GetError());
  }

  // Enable alpha blending for shape rendering (SDL_RenderGeometry)
  SDL_SetRenderDrawBlendMode(r2d_window->sdl_renderer, SDL_BLENDMODE_BLEND);

  // Resolve the effective fps_cap. An infinite cap means "uncapped" → fps_cap 0,
  // so target_frame stays 0 (no frame delay). A negative cap means the caller
  // set none, so fall back to the display refresh rate.
  bool capped = fps_cap >= 0.0;
  if (capped) {
    r2d_window->fps_cap = isinf(fps_cap) ? 0 : (int)fps_cap;
  } else {
    r2d_window->fps_cap = (int)r2d_window->display_refresh_rate;
  }

  #ifndef __EMSCRIPTEN__
  // Native frame pacing: enable vsync for smooth display-synced rendering. A user
  // cap disables vsync and paces solely via SDL_DelayPrecise; without a cap, use
  // vsync AND a refresh-rate SDL_DelayPrecise fallback — this prevents uncapped
  // rendering when the window is occluded, where macOS (and other platforms) may
  // not block on vsync.
  //
  // On the web this is deliberately skipped. With no ASYNCIFY the renderer present
  // can't block, so SDL's vsync setter does nothing but rewrite the Emscripten
  // main-loop timing (vsync 0 → free-running EM_TIMING_SETTIMEOUT, vsync 1 → an
  // EM_TIMING_RAF cadence that measured at half the refresh rate). We own that
  // timing directly instead — see emscripten_set_main_loop_timing below.
  SDL_SetRenderVSync(r2d_window->sdl_renderer, capped ? 0 : 1);
  #endif

  // Logical (user-intended) viewport dimensions — the unscaled base sizes, from
  // which R2D_ApplyPixelScale derives the render dimensions. A non-positive
  // viewport dimension means "unset", so fall back to the window size.
  r2d_window->viewport.base_width  = viewport_width  > 0 ? viewport_width  : width;
  r2d_window->viewport.base_height = viewport_height > 0 ? viewport_height : height;

  r2d_window->viewport.mode = R2D_ParseViewportModeName(viewport_mode);
  r2d_window->render_mode   = R2D_ParseRenderModeName(render_mode);

  r2d_window->scale_mode    = R2D_ParseScaleModeName(scale_mode, SDL_SCALEMODE_LINEAR);

  // Logical (user-intended) window dimensions on the C struct
  r2d_window->orig_width  = width;
  r2d_window->orig_height = height;

  // Derive render (physical) dimensions from the logical sizes, scaling once
  // for pixel_scale on HiDPI so coordinates map 1:1 with physical pixels.
  r2d_window->pixel_scale = pixel_scale;
  R2D_ApplyPixelScale(r2d_window);

  // Apply viewport scaling mode (logical presentation)
  R2D_ApplyViewportMode(r2d_window);

  // An empty string means "no icon", not "load the file named ''". Callers that
  // flatten a Ruby object into positional arguments have no NULL to pass — the
  // Spinel FFI has no nil for a `:str` — so the empty string carries that here.
  if (icon && icon[0] != '\0') R2D_SetIcon(r2d_window, icon);

  // Reset first_poll so the initial gamepad scan runs on the first tick
  first_poll = true;

  // Set Main Loop Data ////////////////////////////////////////////////////////

  frames = 0;           // Total frames since start

  r2d_window->close = false;

  // Frame cap setup: always set a target_frame based on fps_cap. Without an
  // explicit user cap, this equals the display refresh rate (set above), acting
  // as a fallback when vsync is not blocking (e.g., window occluded).
  perf_freq = SDL_GetPerformanceFrequency();
  target_frame = r2d_window->fps_cap > 0
               ? 1.0 / (double)r2d_window->fps_cap
               : 0.0;

  // Center the window on the primary display and reveal it. It was created
  // hidden above, so this positions it before its first paint — no visible
  // jump. Explicit centering is honored on all native backends, unlike the
  // default undefined position (which lands top-left under many Linux WMs).
  // Skipped on the web, where the canvas has no OS-level position.
  #ifndef __EMSCRIPTEN__
  SDL_SetWindowPosition(r2d_window->sdl_window,
                        SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED);
  SDL_ShowWindow(r2d_window->sdl_window);
  #endif

  return true;
}


/*
 * Ruby2D::Window#ext_show
 *
 * Ruby bridge over R2D_ShowWindow: read the window's settings off its ivars,
 * create and reveal the window, then start whichever main loop this engine
 * uses. CRuby returns and lets Ruby own the loop; the Spinel build does the
 * same, calling R2D_ShowWindow directly.
 */
#ifndef RUBY2D_NO_RUBY
R_VAL ruby2d_ext_window_show(RUBY2D_METHOD_ARGS_VARIADIC) {
  RUBY2D_EXTRACT_VARIADIC;
  if (argc != 1) r_raise("Ruby2D::Ext.window_show expects 1 arg (window), got %d", (int)argc);
  R_VAL obj = argv[0];

  ruby2d_window = obj;

  // Re-read settings from Ruby: the user may have changed any of these via
  // set() between ext_create and show.
  R_VAL fps_cap_val = r_ivar_get(obj, id_fps_cap);
  R_VAL vw_val      = r_ivar_get(obj, id_viewport_width);
  R_VAL vh_val      = r_ivar_get(obj, id_viewport_height);
  R_VAL vm_val      = r_ivar_get(obj, id_viewport_mode);
  R_VAL rm_val      = r_ivar_get(obj, id_render_mode);
  R_VAL sm_val      = r_ivar_get(obj, id_scale_mode);
  R_VAL icon_val    = r_ivar_get(obj, id_icon);

  if (!R2D_ShowWindow(
    obj_str(obj, id_title), obj_int(obj, id_width), obj_int(obj, id_height),
    r_test(r_ivar_get(obj, id_resizable)),
    r_test(r_ivar_get(obj, id_highdpi)),
    obj_bool(obj, id_pixel_scale),
    // A negative cap tells the core none was set, so it falls back to the
    // display refresh rate — matching what nil meant here before.
    r_test(fps_cap_val) ? NUM2DBL(fps_cap_val) : -1.0,
    r_test(vw_val) ? NUM2INT(vw_val) : 0,
    r_test(vh_val) ? NUM2INT(vh_val) : 0,
    r_test(vm_val) ? r_sym_name(vm_val) : NULL,
    r_test(rm_val) ? r_sym_name(rm_val) : NULL,
    r_test(sm_val) ? r_sym_name(sm_val) : NULL,
    r_test(icon_val) ? RSTRING_PTR(icon_val) : NULL
  )) {
    r_raise("%s", R2D_LastError());
  }

  // On the web, pacing is applied by the tick trampoline instead of vsync or
  // frame delays — map the cap onto a pace mode for it.
  #ifdef __EMSCRIPTEN__
  wasm_set_pace_mode(fps_cap_val);
  #endif

  // Main Loop /////////////////////////////////////////////////////////////////
  // CRuby: return and let Ruby own the loop (Window#show calls tick in a loop).
  // mruby native: C drives the loop, calling Ruby's tick each frame.
  // WASM: emscripten_set_main_loop calls tick via a C trampoline.

  #ifdef __EMSCRIPTEN__
    emscripten_set_main_loop(wasm_tick_trampoline, 0, true);
  #elif defined(MRUBY)
    // Arena save/restore for the same reason as wasm_tick_trampoline: each
    // C-driven tick would otherwise pin its return value in the GC arena.
    while (!r2d_window->close) {
      int ai = r_gc_arena_save();
      r_funcall(ruby2d_window, "tick", 0);
      r_gc_arena_restore(ai);
    }
  #endif

  return R_TRUE;
}
#endif


// =============================================================================
// Window Operations
// =============================================================================

/*
 * Set the icon for the window
 */
void R2D_SetIcon(R2D_Window *window, const char *icon) {
  SDL_Surface *iconSurface = IMG_Load(icon);
  if (iconSurface) {
    window->icon = icon;
    SDL_SetWindowIcon(window->sdl_window, iconSurface);
    SDL_DestroySurface(iconSurface);
  } else {
    R2D_Log(R2D_WARN, "Could not set window icon: %s", SDL_GetError());
  }
}


/*
 * Take a screenshot of the window
 */
void R2D_Screenshot(R2D_Window *window, const char *path) {
  SDL_Surface *surface = SDL_RenderReadPixels(window->sdl_renderer, NULL);
  if (!surface) {
    R2D_Error("R2D_Screenshot", "%s", SDL_GetError());
    return;
  }

  if (!IMG_SavePNG(surface, path)) {
    R2D_Error("R2D_Screenshot", "%s", SDL_GetError());
  }

  SDL_DestroySurface(surface);
}


/*
 * Show the cursor over the window
 */
void R2D_ShowCursor() {
  SDL_ShowCursor();
}


/*
 * Hide the cursor over the window
 */
void R2D_HideCursor() {
  SDL_HideCursor();
}


/*
 * Check if the cursor is visible
 */
bool R2D_CursorVisible() {
  return SDL_CursorVisible();
}


/*
 * Set the system cursor by name
 */
bool R2D_SetSystemCursor(const char *name) {
  SDL_SystemCursor id;

  if      (strcmp(name, "default")     == 0) id = SDL_SYSTEM_CURSOR_DEFAULT;
  else if (strcmp(name, "text")        == 0) id = SDL_SYSTEM_CURSOR_TEXT;
  else if (strcmp(name, "wait")        == 0) id = SDL_SYSTEM_CURSOR_WAIT;
  else if (strcmp(name, "crosshair")   == 0) id = SDL_SYSTEM_CURSOR_CROSSHAIR;
  else if (strcmp(name, "progress")    == 0) id = SDL_SYSTEM_CURSOR_PROGRESS;
  else if (strcmp(name, "nwse_resize") == 0) id = SDL_SYSTEM_CURSOR_NWSE_RESIZE;
  else if (strcmp(name, "nesw_resize") == 0) id = SDL_SYSTEM_CURSOR_NESW_RESIZE;
  else if (strcmp(name, "ew_resize")   == 0) id = SDL_SYSTEM_CURSOR_EW_RESIZE;
  else if (strcmp(name, "ns_resize")   == 0) id = SDL_SYSTEM_CURSOR_NS_RESIZE;
  else if (strcmp(name, "move")        == 0) id = SDL_SYSTEM_CURSOR_MOVE;
  else if (strcmp(name, "not_allowed") == 0) id = SDL_SYSTEM_CURSOR_NOT_ALLOWED;
  else if (strcmp(name, "pointer")     == 0) id = SDL_SYSTEM_CURSOR_POINTER;
  else if (strcmp(name, "nw_resize")   == 0) id = SDL_SYSTEM_CURSOR_NW_RESIZE;
  else if (strcmp(name, "n_resize")    == 0) id = SDL_SYSTEM_CURSOR_N_RESIZE;
  else if (strcmp(name, "ne_resize")   == 0) id = SDL_SYSTEM_CURSOR_NE_RESIZE;
  else if (strcmp(name, "e_resize")    == 0) id = SDL_SYSTEM_CURSOR_E_RESIZE;
  else if (strcmp(name, "se_resize")   == 0) id = SDL_SYSTEM_CURSOR_SE_RESIZE;
  else if (strcmp(name, "s_resize")    == 0) id = SDL_SYSTEM_CURSOR_S_RESIZE;
  else if (strcmp(name, "sw_resize")   == 0) id = SDL_SYSTEM_CURSOR_SW_RESIZE;
  else if (strcmp(name, "w_resize")    == 0) id = SDL_SYSTEM_CURSOR_W_RESIZE;
  else {
    R2D_Error("R2D_SetSystemCursor", "Unknown cursor name: %s", name);
    return false;
  }

  // Cache one cursor per system-cursor id so repeated sets don't leak a fresh
  // SDL_Cursor each call (SDL_SetCursor doesn't take ownership). The cache lives
  // for the process — bounded by SDL_SYSTEM_CURSOR_COUNT, matching the
  // single-window/no-teardown design.
  static SDL_Cursor *cursor_cache[SDL_SYSTEM_CURSOR_COUNT] = { NULL };

  SDL_Cursor *cursor = cursor_cache[id];
  if (!cursor) {
    cursor = SDL_CreateSystemCursor(id);
    if (!cursor) {
      R2D_Error("R2D_SetSystemCursor", "Failed to create cursor: %s", SDL_GetError());
      return false;
    }
    cursor_cache[id] = cursor;
  }

  SDL_SetCursor(cursor);
  SDL_ShowCursor();
  return true;
}


/*
 * Close the window
 *
 * This only flags the loop to stop; it does NOT destroy the SDL window or
 * renderer. Those are torn down in R2D_FreeWindow, which runs from the GC
 * finalizer. The deferral is deliberate: the window object is pinned by
 * DSL.window for the life of the process, so a closed window can be re-shown,
 * and destroying SDL resources here would double-free when the finalizer later
 * runs over the same pointers.
 */
int R2D_Close(R2D_Window *window) {
  if (!window->close) {
    R2D_Log(R2D_INFO, "Closing window");
    window->close = true;
  }
  return 0;
}


/*
 * Whether the renderer is still alive. Texture finalizers consult this: at
 * interpreter shutdown Ruby may free the Window — destroying the renderer and,
 * with it, every texture created from it — before an Image/Text/Canvas/
 * BitmapText finalizer runs, so calling SDL_DestroyTexture afterward would
 * double-free. R2D_FreeWindow clears r2d_window, so a NULL window means gone.
 */
bool R2D_RendererAlive(void) {
  R2D_Window *w = R2D_GetWindow();
  return w && w->sdl_renderer;
}


/*
 * Free all resources
 */
int R2D_FreeWindow(R2D_Window *window) {
  R2D_Close(window);
  R2D_FreeFpsOverlay();
  if (window->sdl_renderer) {
    SDL_DestroyRenderer(window->sdl_renderer);
    window->sdl_renderer = NULL;
  }
  if (window->sdl_window) {
    SDL_DestroyWindow(window->sdl_window);
    window->sdl_window = NULL;
  }
  free(window->screenshot_path);
  if (r2d_window == window) r2d_window = NULL;
  free(window);
  return 0;
}


/*
 * Free callback for Ruby's typed data (matches R2D_DEFINE_DATA_TYPE)
 */
static void R2D_Window_free(void *p) {
  if (!p) return;
  R2D_FreeWindow((R2D_Window *)p);
}


// =============================================================================
// Ruby Method Bindings
// =============================================================================

/*
 * Ruby2D::Window#ext_get_display_dimensions
 */
#ifndef RUBY2D_NO_RUBY
R_VAL ruby2d_ext_window_get_display_dimensions(RUBY2D_METHOD_ARGS_VARIADIC) {
  RUBY2D_EXTRACT_VARIADIC;
  if (argc != 1) r_raise("Ruby2D::Ext.window_get_display_dimensions expects 1 arg (window), got %d", (int)argc);
  R_VAL obj = argv[0];
  int w; int h;
  R2D_GetDisplayDimensions(&w, &h);
  r_iv_set(obj, "@display_width",        INT2NUM(w));
  r_iv_set(obj, "@display_height",       INT2NUM(h));
  r_iv_set(obj, "@display_pixel_width",  INT2NUM(r2d_window->display_pixel_width));
  r_iv_set(obj, "@display_pixel_height", INT2NUM(r2d_window->display_pixel_height));
  return R_NIL;
}
#endif


/*
 * Ruby2D::Window#ext_set_viewport_mode
 *
 * Reads @viewport_mode, @viewport_width, @viewport_height from Ruby and
 * applies the new viewport mode at runtime.
 */
#ifndef RUBY2D_NO_RUBY
R_VAL ruby2d_ext_window_set_viewport_mode(RUBY2D_METHOD_ARGS_VARIADIC) {
  RUBY2D_EXTRACT_VARIADIC;
  if (argc != 1) r_raise("Ruby2D::Ext.window_set_viewport_mode expects 1 arg (window), got %d", (int)argc);
  R_VAL obj = argv[0];
  if (!r2d_window) return R_FALSE;

  // Detect an explicit viewport-dimension change from Ruby. @viewport_* is
  // synced to the current (possibly pixel-scaled) render viewport each frame, so
  // a value that differs means the user set a new size via set() — adopt it as
  // the logical base. A matching value (the common case) leaves the base alone,
  // which is what keeps repeated set() calls from compounding.
  R_VAL vw_val = r_ivar_get(obj, id_viewport_width);
  R_VAL vh_val = r_ivar_get(obj, id_viewport_height);
  int ruby_vw = r_test(vw_val) ? NUM2INT(vw_val) : r2d_window->width;
  int ruby_vh = r_test(vh_val) ? NUM2INT(vh_val) : r2d_window->height;

  if (ruby_vw != r2d_window->viewport.width ||
      ruby_vh != r2d_window->viewport.height) {
    r2d_window->viewport.base_width  = ruby_vw;
    r2d_window->viewport.base_height = ruby_vh;
  }

  // Parse the (possibly new) viewport mode
  r2d_window->viewport.mode = R2D_ParseViewportMode(r_ivar_get(obj, id_viewport_mode));

  // Re-derive the render dimensions from the logical base. Idempotent, so
  // toggling pixel_scale or changing viewport mode at runtime no longer doubles
  // the window/viewport size on each call.
  r2d_window->pixel_scale = obj_bool(obj, id_pixel_scale);
  R2D_ApplyPixelScale(r2d_window);

  R2D_ApplyViewportMode(r2d_window);

  return R_TRUE;
}
#endif


/*
 * Ruby2D::Window#ext_set_icon
 */
#ifndef RUBY2D_NO_RUBY
R_VAL ruby2d_ext_window_set_icon(RUBY2D_METHOD_ARGS_VARIADIC) {
  RUBY2D_EXTRACT_VARIADIC;
  if (argc != 1) r_raise("Ruby2D::Ext.window_set_icon expects 1 arg (window), got %d", (int)argc);
  R_VAL obj = argv[0];
  if (!r2d_window || !r2d_window->sdl_window) return R_FALSE;

  R_VAL icon_val = r_ivar_get(obj, id_icon);
  if (r_test(icon_val)) {
    R2D_SetIcon(r2d_window, RSTRING_PTR(icon_val));
  }
  return R_TRUE;
}
#endif


/*
 * Ruby2D::Window#ext_set_title — push @title to the live window's title bar
 */
#ifndef RUBY2D_NO_RUBY
R_VAL ruby2d_ext_window_set_title(RUBY2D_METHOD_ARGS_VARIADIC) {
  RUBY2D_EXTRACT_VARIADIC;
  if (argc != 1) r_raise("Ruby2D::Ext.window_set_title expects 1 arg (window), got %d", (int)argc);
  R_VAL obj = argv[0];
  if (!r2d_window || !r2d_window->sdl_window) return R_FALSE;

  SDL_SetWindowTitle(r2d_window->sdl_window, obj_str(obj, id_title));
  return R_TRUE;
}
#endif


/*
 * Ruby2D::Window#ext_set_resizable — toggle the live window's resizability
 */
#ifndef RUBY2D_NO_RUBY
R_VAL ruby2d_ext_window_set_resizable(RUBY2D_METHOD_ARGS_VARIADIC) {
  RUBY2D_EXTRACT_VARIADIC;
  if (argc != 1) r_raise("Ruby2D::Ext.window_set_resizable expects 1 arg (window), got %d", (int)argc);
  R_VAL obj = argv[0];
  if (!r2d_window || !r2d_window->sdl_window) return R_FALSE;

  bool resizable = r_test(r_ivar_get(obj, id_resizable));
  SDL_SetWindowResizable(r2d_window->sdl_window, resizable);
  if (resizable) r2d_window->flags |=  R2D_RESIZABLE;
  else           r2d_window->flags &= ~R2D_RESIZABLE;
  return R_TRUE;
}
#endif


/*
 * Ruby2D::Window#ext_set_size — resize the live window to the logical @width/
 * @height, then re-derive the render/viewport dimensions (mirrors the resize-
 * event path). The window manager may honor a different size; the resulting
 * SDL_EVENT_WINDOW_RESIZED reconciles orig_width/orig_height if so.
 */
#ifndef RUBY2D_NO_RUBY
R_VAL ruby2d_ext_window_set_size(RUBY2D_METHOD_ARGS_VARIADIC) {
  RUBY2D_EXTRACT_VARIADIC;
  if (argc != 1) r_raise("Ruby2D::Ext.window_set_size expects 1 arg (window), got %d", (int)argc);
  R_VAL obj = argv[0];
  if (!r2d_window || !r2d_window->sdl_window) return R_FALSE;

  r2d_window->orig_width  = obj_int(obj, id_width);
  r2d_window->orig_height = obj_int(obj, id_height);

  // In expand mode the viewport tracks the window size; fixed/scaled modes keep
  // their own logical canvas (viewport.base_*).
  if (r2d_window->viewport.mode == R2D_VIEWPORT_EXPAND) {
    r2d_window->viewport.base_width  = r2d_window->orig_width;
    r2d_window->viewport.base_height = r2d_window->orig_height;
  }

  // SDL_CreateWindowAndRenderer was given logical * content_scale at show time;
  // match that so the requested logical size maps to the same physical pixels.
  float cs = r2d_window->display_content_scale;
  if (!SDL_SetWindowSize(r2d_window->sdl_window,
                         (int)(r2d_window->orig_width  * cs),
                         (int)(r2d_window->orig_height * cs))) {
    R2D_Error("SDL_SetWindowSize", "%s", SDL_GetError());
  }

  R2D_ApplyPixelScale(r2d_window);
  R2D_ApplyViewportMode(r2d_window);
  return R_TRUE;
}
#endif


/*
 * Ruby2D::Window#ext_diagnostics
 */
#ifndef RUBY2D_NO_RUBY
R_VAL ruby2d_ext_window_diagnostics(RUBY2D_METHOD_ARGS_VARIADIC) {
  RUBY2D_EXTRACT_VARIADIC;
  if (argc != 2) r_raise("Ruby2D::Ext.window_diagnostics expects 2 args, got %d", (int)argc);
  R_VAL enable = argv[1];
  // Set Ruby 2D native diagnostics
  R2D_Diagnostics(r_test(enable));
  return R_TRUE;
}
#endif


/*
 * Ruby2D::Window#ext_set_fps_cap
 */
#ifndef RUBY2D_NO_RUBY
R_VAL ruby2d_ext_window_set_fps_cap(RUBY2D_METHOD_ARGS_VARIADIC) {
  RUBY2D_EXTRACT_VARIADIC;
  if (argc != 2) r_raise("Ruby2D::Ext.window_set_fps_cap expects 2 args, got %d", (int)argc);
  R_VAL fps_cap = argv[1];
  if (!r2d_window || !r2d_window->sdl_renderer) return R_FALSE;

  if (!r_test(fps_cap)) {
    // nil → no cap: restore vsync-driven pacing with the refresh-rate fallback.
    r2d_window->fps_cap = (int)r2d_window->display_refresh_rate;
    #ifndef __EMSCRIPTEN__
    SDL_SetRenderVSync(r2d_window->sdl_renderer, 1);
    #endif
  } else {
    // A finite cap paces via SDL_DelayPrecise; Float::INFINITY → uncapped.
    // (The Ruby side has already rejected 0/negative/NaN.)
    double cap = NUM2DBL(fps_cap);
    r2d_window->fps_cap = isinf(cap) ? 0 : (int)cap;
    #ifndef __EMSCRIPTEN__
    SDL_SetRenderVSync(r2d_window->sdl_renderer, 0);
    #endif
  }
  // On the web, vsync isn't touched: the requestAnimationFrame main loop owns the
  // cadence, and SDL's vsync setter would only rewrite that timing (and SDL_Delay-
  // Precise pacing is compiled out under Emscripten). Pacing is applied by the
  // tick trampoline instead — see wasm_set_pace_mode / wasm_tick_trampoline.
  #ifdef __EMSCRIPTEN__
  wasm_set_pace_mode(fps_cap);
  #endif
  target_frame = r2d_window->fps_cap > 0 ? 1.0 / (double)r2d_window->fps_cap : 0.0;
  return R_TRUE;
}
#endif


/*
 * Ruby2D::Window#ext_show_fps
 */
#ifndef RUBY2D_NO_RUBY
R_VAL ruby2d_ext_window_show_fps(RUBY2D_METHOD_ARGS_VARIADIC) {
  RUBY2D_EXTRACT_VARIADIC;
  if (argc != 2) r_raise("Ruby2D::Ext.window_show_fps expects 2 args, got %d", (int)argc);
  R_VAL enable = argv[1];
  R2D_ShowFPS(r_test(enable));
  return R_TRUE;
}
#endif


/*
 * Ruby2D::Window#ext_load_gamepad_mappings_file
 */
#ifndef RUBY2D_NO_RUBY
R_VAL ruby2d_ext_window_load_gamepad_mappings_file(RUBY2D_METHOD_ARGS_VARIADIC) {
  RUBY2D_EXTRACT_VARIADIC;
  if (argc != 2) r_raise("Ruby2D::Ext.window_load_gamepad_mappings_file expects 2 args, got %d", (int)argc);
  R_VAL path = argv[1];
  R2D_Log(R2D_INFO, "Loading gamepad mappings from `%s`", RSTRING_PTR(path));
  int n = R2D_AddGamepadMappingsFromFile(RSTRING_PTR(path));
  return INT2NUM(n);
}
#endif


/*
 * Ruby2D::Window#ext_add_gamepad_mapping
 */
#ifndef RUBY2D_NO_RUBY
R_VAL ruby2d_ext_window_add_gamepad_mapping(RUBY2D_METHOD_ARGS_VARIADIC) {
  RUBY2D_EXTRACT_VARIADIC;
  if (argc != 2) r_raise("Ruby2D::Ext.window_add_gamepad_mapping expects 2 args, got %d", (int)argc);
  R_VAL mapping = argv[1];
  int n = R2D_AddGamepadMapping(RSTRING_PTR(mapping));
  return INT2NUM(n);
}
#endif


/*
 * Ruby2D::Window#ext_gamepad_rumble
 */
#ifndef RUBY2D_NO_RUBY
R_VAL ruby2d_ext_window_gamepad_rumble(RUBY2D_METHOD_ARGS_VARIADIC) {
  RUBY2D_EXTRACT_VARIADIC;
  if (argc != 5) r_raise("Ruby2D::Ext.window_gamepad_rumble expects 5 args, got %d", (int)argc);
  R_VAL id = argv[1];
  R_VAL low = argv[2];
  R_VAL high = argv[3];
  R_VAL duration = argv[4];
  bool ok = R2D_RumbleGamepad(
    (SDL_JoystickID)NUM2INT(id),
    NUM2DBL(low), NUM2DBL(high), NUM2DBL(duration)
  );
  return ok ? R_TRUE : R_FALSE;
}
#endif


/*
 * Ruby2D::Window#ext_gamepad_rumble_triggers
 */
#ifndef RUBY2D_NO_RUBY
R_VAL ruby2d_ext_window_gamepad_rumble_triggers(RUBY2D_METHOD_ARGS_VARIADIC) {
  RUBY2D_EXTRACT_VARIADIC;
  if (argc != 5) r_raise("Ruby2D::Ext.window_gamepad_rumble_triggers expects 5 args, got %d", (int)argc);
  R_VAL id = argv[1];
  R_VAL left = argv[2];
  R_VAL right = argv[3];
  R_VAL duration = argv[4];
  bool ok = R2D_RumbleGamepadTriggers(
    (SDL_JoystickID)NUM2INT(id),
    NUM2DBL(left), NUM2DBL(right), NUM2DBL(duration)
  );
  return ok ? R_TRUE : R_FALSE;
}
#endif


/*
 * Ruby2D::Window#ext_gamepad_set_led
 */
#ifndef RUBY2D_NO_RUBY
R_VAL ruby2d_ext_window_gamepad_set_led(RUBY2D_METHOD_ARGS_VARIADIC) {
  RUBY2D_EXTRACT_VARIADIC;
  if (argc != 5) r_raise("Ruby2D::Ext.window_gamepad_set_led expects 5 args, got %d", (int)argc);
  R_VAL id = argv[1];
  R_VAL r = argv[2];
  R_VAL g = argv[3];
  R_VAL b = argv[4];
  bool ok = R2D_SetGamepadLED(
    (SDL_JoystickID)NUM2INT(id),
    NUM2INT(r), NUM2INT(g), NUM2INT(b)
  );
  return ok ? R_TRUE : R_FALSE;
}
#endif


/*
 * Map an SDL_GamepadType to one of the high-level Ruby symbols Gamepad
 * exposes (`:xbox`, `:playstation`, `:nintendo`, `:generic`, `:unknown`).
 * Used both for the cached `pad.type` and the `real_type` debug field.
 */
#ifndef RUBY2D_NO_RUBY
static R_VAL ruby2d_gamepad_type_to_sym(SDL_GamepadType t) {
  switch (t) {
    case SDL_GAMEPAD_TYPE_XBOX360:
    case SDL_GAMEPAD_TYPE_XBOXONE:
      return r_char_to_sym("xbox");
    case SDL_GAMEPAD_TYPE_PS3:
    case SDL_GAMEPAD_TYPE_PS4:
    case SDL_GAMEPAD_TYPE_PS5:
      return r_char_to_sym("playstation");
    case SDL_GAMEPAD_TYPE_NINTENDO_SWITCH_PRO:
    case SDL_GAMEPAD_TYPE_NINTENDO_SWITCH_JOYCON_LEFT:
    case SDL_GAMEPAD_TYPE_NINTENDO_SWITCH_JOYCON_RIGHT:
    case SDL_GAMEPAD_TYPE_NINTENDO_SWITCH_JOYCON_PAIR:
    case SDL_GAMEPAD_TYPE_GAMECUBE:
      return r_char_to_sym("nintendo");
    case SDL_GAMEPAD_TYPE_STANDARD:
      return r_char_to_sym("generic");
    default:
      return r_char_to_sym("unknown");
  }
}
#endif


/*
 * Ruby2D::Window#ext_gamepad_type
 */
#ifndef RUBY2D_NO_RUBY
R_VAL ruby2d_ext_window_gamepad_type(RUBY2D_METHOD_ARGS_VARIADIC) {
  RUBY2D_EXTRACT_VARIADIC;
  if (argc != 2) r_raise("Ruby2D::Ext.window_gamepad_type expects 2 args, got %d", (int)argc);
  R_VAL id = argv[1];
  SDL_Gamepad *pad = SDL_GetGamepadFromID((SDL_JoystickID)NUM2INT(id));
  if (!pad) return r_char_to_sym("unknown");
  return ruby2d_gamepad_type_to_sym(SDL_GetGamepadType(pad));
}
#endif


/*
 * Ruby2D::Window#ext_gamepad_battery
 *
 * Returns a 2-element array: [state_symbol, percent]. State is one of
 * :wired / :on_battery / :unknown; percent is an Integer 0..100 or -1
 * if SDL did not report one.
 */
#ifndef RUBY2D_NO_RUBY
R_VAL ruby2d_ext_window_gamepad_battery(RUBY2D_METHOD_ARGS_VARIADIC) {
  RUBY2D_EXTRACT_VARIADIC;
  if (argc != 2) r_raise("Ruby2D::Ext.window_gamepad_battery expects 2 args, got %d", (int)argc);
  R_VAL id = argv[1];
  int percent = -1;
  int state = R2D_GetGamepadBattery((SDL_JoystickID)NUM2INT(id), &percent);
  R_VAL state_sym;
  switch (state) {
    case R2D_GAMEPAD_BATTERY_WIRED:      state_sym = r_char_to_sym("wired"); break;
    case R2D_GAMEPAD_BATTERY_ON_BATTERY: state_sym = r_char_to_sym("on_battery"); break;
    default:                             state_sym = r_char_to_sym("unknown"); break;
  }
  R_VAL ary = r_ary_new();
  r_ary_push(ary, state_sym);
  r_ary_push(ary, INT2NUM(percent));
  return ary;
}
#endif


/*
 * Ruby2D::Window#ext_gamepad_has_button
 */
#ifndef RUBY2D_NO_RUBY
R_VAL ruby2d_ext_window_gamepad_has_button(RUBY2D_METHOD_ARGS_VARIADIC) {
  RUBY2D_EXTRACT_VARIADIC;
  if (argc != 3) r_raise("Ruby2D::Ext.window_gamepad_has_button expects 3 args, got %d", (int)argc);
  R_VAL id = argv[1];
  R_VAL button = argv[2];
  bool ok = R2D_GamepadHasButton(
    (SDL_JoystickID)NUM2INT(id), NUM2INT(button)
  );
  return ok ? R_TRUE : R_FALSE;
}
#endif


/*
 * Ruby2D::Window#ext_gamepad_has_axis
 */
#ifndef RUBY2D_NO_RUBY
R_VAL ruby2d_ext_window_gamepad_has_axis(RUBY2D_METHOD_ARGS_VARIADIC) {
  RUBY2D_EXTRACT_VARIADIC;
  if (argc != 3) r_raise("Ruby2D::Ext.window_gamepad_has_axis expects 3 args, got %d", (int)argc);
  R_VAL id = argv[1];
  R_VAL axis = argv[2];
  bool ok = R2D_GamepadHasAxis(
    (SDL_JoystickID)NUM2INT(id), NUM2INT(axis)
  );
  return ok ? R_TRUE : R_FALSE;
}
#endif


/*
 * Ruby2D::Window#ext_gamepad_caps
 */
#ifndef RUBY2D_NO_RUBY
R_VAL ruby2d_ext_window_gamepad_caps(RUBY2D_METHOD_ARGS_VARIADIC) {
  RUBY2D_EXTRACT_VARIADIC;
  if (argc != 2) r_raise("Ruby2D::Ext.window_gamepad_caps expects 2 args, got %d", (int)argc);
  R_VAL id = argv[1];
  int caps = R2D_GetGamepadCaps((SDL_JoystickID)NUM2INT(id));
  return INT2NUM(caps);
}
#endif


/*
 * Ruby2D::Window#ext_gamepad_debug_info
 *
 * Returns nil if the pad isn't open. Otherwise returns a fixed-shape
 * Array (positional) that `Gamepad#debug_info` reshapes into a Hash:
 *   [guid_str, vendor, product, version, serial_or_nil,
 *    connection_sym, real_type_sym, num_touchpads, mapping_or_nil]
 */
#ifndef RUBY2D_NO_RUBY
R_VAL ruby2d_ext_window_gamepad_debug_info(RUBY2D_METHOD_ARGS_VARIADIC) {
  RUBY2D_EXTRACT_VARIADIC;
  if (argc != 2) r_raise("Ruby2D::Ext.window_gamepad_debug_info expects 2 args, got %d", (int)argc);
  R_VAL id = argv[1];
  SDL_JoystickID jid = (SDL_JoystickID)NUM2INT(id);
  SDL_Gamepad *pad = SDL_GetGamepadFromID(jid);
  if (!pad) return R_NIL;

  R_VAL arr = r_ary_new();

  // GUID — 32-char hex string
  SDL_GUID guid = SDL_GetGamepadGUIDForID(jid);
  char guid_str[33] = {0};
  SDL_GUIDToString(guid, guid_str, sizeof(guid_str));
  r_ary_push(arr, r_str_new(guid_str));

  // Vendor / Product / Version (USB-style 16-bit IDs)
  r_ary_push(arr, INT2NUM(SDL_GetGamepadVendor(pad)));
  r_ary_push(arr, INT2NUM(SDL_GetGamepadProduct(pad)));
  r_ary_push(arr, INT2NUM(SDL_GetGamepadProductVersion(pad)));

  // Serial number — frequently NULL
  const char *serial = SDL_GetGamepadSerial(pad);
  r_ary_push(arr, serial ? r_str_new(serial) : R_NIL);

  // Connection state
  R_VAL conn_sym;
  switch (SDL_GetGamepadConnectionState(pad)) {
    case SDL_JOYSTICK_CONNECTION_WIRED:    conn_sym = r_char_to_sym("wired");    break;
    case SDL_JOYSTICK_CONNECTION_WIRELESS: conn_sym = r_char_to_sym("wireless"); break;
    default:                               conn_sym = r_char_to_sym("unknown");  break;
  }
  r_ary_push(arr, conn_sym);

  // Real (un-remapped) gamepad type — useful for spotting type overrides
  // applied by SDL_GameControllerDB or user mappings.
  r_ary_push(arr, ruby2d_gamepad_type_to_sym(SDL_GetRealGamepadType(pad)));

  // Touchpad count (PS4/PS5 = 1; most others = 0)
  r_ary_push(arr, INT2NUM(SDL_GetNumGamepadTouchpads(pad)));

  // Resolved mapping string. SDL_GetGamepadMapping returns malloc'd memory
  // that the caller must release via SDL_free.
  char *mapping = SDL_GetGamepadMapping(pad);
  if (mapping) {
    r_ary_push(arr, r_str_new(mapping));
    SDL_free(mapping);
  } else {
    r_ary_push(arr, R_NIL);
  }

  return arr;
}
#endif


/*
 * Ruby2D::Window#ext_gamepad_joystick_state
 */
#ifndef RUBY2D_NO_RUBY
R_VAL ruby2d_ext_window_gamepad_joystick_state(RUBY2D_METHOD_ARGS_VARIADIC) {
  RUBY2D_EXTRACT_VARIADIC;
  if (argc != 2) r_raise("Ruby2D::Ext.window_gamepad_joystick_state expects 2 args, got %d", (int)argc);
  R_VAL id = argv[1];
  SDL_Gamepad *pad = SDL_GetGamepadFromID((SDL_JoystickID)NUM2INT(id));
  if (!pad) return R_NIL;
  SDL_Joystick *joy = SDL_GetGamepadJoystick(pad);
  if (!joy) return R_NIL;

  R_VAL btns = r_ary_new();
  int n_btns = SDL_GetNumJoystickButtons(joy);
  for (int i = 0; i < n_btns; i++) {
    r_ary_push(btns, SDL_GetJoystickButton(joy, i) ? R_TRUE : R_FALSE);
  }

  R_VAL axes = r_ary_new();
  int n_axes = SDL_GetNumJoystickAxes(joy);
  for (int i = 0; i < n_axes; i++) {
    r_ary_push(axes, INT2NUM(SDL_GetJoystickAxis(joy, i)));
  }

  R_VAL hats = r_ary_new();
  int n_hats = SDL_GetNumJoystickHats(joy);
  for (int i = 0; i < n_hats; i++) {
    r_ary_push(hats, INT2NUM((int)SDL_GetJoystickHat(joy, i)));
  }

  R_VAL result = r_ary_new();
  r_ary_push(result, btns);
  r_ary_push(result, axes);
  r_ary_push(result, hats);
  return result;
}
#endif


/*
 * Ruby2D::Window#ext_screenshot
 *
 * Defers the screenshot to the end of the current frame, after rendering but
 * before SDL_RenderPresent, so the back buffer contains the fully drawn scene.
 */
#ifndef RUBY2D_NO_RUBY
R_VAL ruby2d_ext_window_screenshot(RUBY2D_METHOD_ARGS_VARIADIC) {
  RUBY2D_EXTRACT_VARIADIC;
  if (argc != 2) r_raise("Ruby2D::Ext.window_screenshot expects 2 args, got %d", (int)argc);
  R_VAL path = argv[1];
  if (r2d_window) {
    free(r2d_window->screenshot_path);
    r2d_window->screenshot_path = strdup(RSTRING_PTR(path));
    return path;
  } else {
    return R_FALSE;
  }
}
#endif


/*
 * Ruby2D::Window#ext_show_cursor
 */
#ifndef RUBY2D_NO_RUBY
R_VAL ruby2d_ext_window_show_cursor(RUBY2D_METHOD_ARGS_VARIADIC) {
  RUBY2D_EXTRACT_VARIADIC;
  if (argc != 1) r_raise("Ruby2D::Ext.window_show_cursor expects 1 arg (window), got %d", (int)argc);
  R2D_ShowCursor();
  return R_TRUE;
}
#endif


/*
 * Ruby2D::Window#ext_hide_cursor
 */
#ifndef RUBY2D_NO_RUBY
R_VAL ruby2d_ext_window_hide_cursor(RUBY2D_METHOD_ARGS_VARIADIC) {
  RUBY2D_EXTRACT_VARIADIC;
  if (argc != 1) r_raise("Ruby2D::Ext.window_hide_cursor expects 1 arg (window), got %d", (int)argc);
  R2D_HideCursor();
  return R_TRUE;
}
#endif


/*
 * Ruby2D::Window#ext_cursor_visible
 */
#ifndef RUBY2D_NO_RUBY
R_VAL ruby2d_ext_window_cursor_visible(RUBY2D_METHOD_ARGS_VARIADIC) {
  RUBY2D_EXTRACT_VARIADIC;
  if (argc != 1) r_raise("Ruby2D::Ext.window_cursor_visible expects 1 arg (window), got %d", (int)argc);
  return R2D_CursorVisible() ? R_TRUE : R_FALSE;
}
#endif


/*
 * Ruby2D::Window#ext_set_system_cursor
 */
#ifndef RUBY2D_NO_RUBY
R_VAL ruby2d_ext_window_set_system_cursor(RUBY2D_METHOD_ARGS_VARIADIC) {
  RUBY2D_EXTRACT_VARIADIC;
  if (argc != 2) r_raise("Ruby2D::Ext.window_set_system_cursor expects 2 args, got %d", (int)argc);
  R_VAL name = argv[1];
  return R2D_SetSystemCursor(RSTRING_PTR(name)) ? R_TRUE : R_FALSE;
}
#endif


// Close the current window. R2D_Close itself is already Ruby-free but takes the
// window pointer; the Spinel build has no handle to pass, so it calls this.
void R2D_CloseWindow(void) { R2D_Close(r2d_window); }


/*
 * Ruby2D::Window#ext_close
 */
#ifndef RUBY2D_NO_RUBY
R_VAL ruby2d_ext_window_close(RUBY2D_METHOD_ARGS_VARIADIC) {
  RUBY2D_EXTRACT_VARIADIC;
  if (argc != 1) r_raise("Ruby2D::Ext.window_close expects 1 arg (window), got %d", (int)argc);
  R2D_Close(r2d_window);
  return R_NIL;
}
#endif


/*
 * Ruby2D::Window#ext_set_render_mode
 *
 * Reads @render_mode from Ruby and updates the native render mode. Marks the
 * next frame pending so the app always sees at least one frame after switching
 * modes (particularly important when switching from on_demand → continuous or
 * changing modes mid-scene).
 */
#ifndef RUBY2D_NO_RUBY
R_VAL ruby2d_ext_window_set_render_mode(RUBY2D_METHOD_ARGS_VARIADIC) {
  RUBY2D_EXTRACT_VARIADIC;
  if (argc != 1) r_raise("Ruby2D::Ext.window_set_render_mode expects 1 arg (window), got %d", (int)argc);
  R_VAL obj = argv[0];
  if (!r2d_window) return R_FALSE;
  r2d_window->render_mode = R2D_ParseRenderMode(r_ivar_get(obj, id_render_mode));
  SDL_SetAtomicInt(&r2d_window->render_pending, 1);
  return R_TRUE;
}
#endif


/*
 * Ruby2D::Window#ext_set_scale_mode
 */
#ifndef RUBY2D_NO_RUBY
R_VAL ruby2d_ext_window_set_scale_mode(RUBY2D_METHOD_ARGS_VARIADIC) {
  RUBY2D_EXTRACT_VARIADIC;
  if (argc != 1) r_raise("Ruby2D::Ext.window_set_scale_mode expects 1 arg (window), got %d", (int)argc);
  R_VAL obj = argv[0];
  if (!r2d_window) return R_FALSE;
  r2d_window->scale_mode = R2D_ParseScaleMode(r_ivar_get(obj, id_scale_mode), SDL_SCALEMODE_LINEAR);
  SDL_SetAtomicInt(&r2d_window->render_pending, 1);
  return R_TRUE;
}
#endif


/*
 * Ruby2D::Window#ext_request_render
 *
 * Marks the next tick as needing a rendered frame. Safe to call from any
 * thread (the dirty flag is an SDL atomic int).
 */
#ifndef RUBY2D_NO_RUBY
R_VAL ruby2d_ext_window_request_render(RUBY2D_METHOD_ARGS_VARIADIC) {
  RUBY2D_EXTRACT_VARIADIC;
  if (argc != 1) r_raise("Ruby2D::Ext.window_request_render expects 1 arg (window), got %d", (int)argc);
  if (!r2d_window) return R_FALSE;
  SDL_SetAtomicInt(&r2d_window->render_pending, 1);
  return R_TRUE;
}
#endif
