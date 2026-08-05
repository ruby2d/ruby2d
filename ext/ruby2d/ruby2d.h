// ruby2d.h

#ifndef RUBY2D_H
#define RUBY2D_H


// Ruby Engine and Includes ////////////////////////////////////////////////////

#ifdef MRUBY
  #include <mruby.h>
  #include <mruby/array.h>
  #include <mruby/string.h>
  #include <mruby/variable.h>
  #include <mruby/numeric.h>
  #include <mruby/data.h>
  #include <mruby/irep.h>
  #include <mruby/error.h>
#else
  #include <ruby.h>
#endif

#ifdef __cplusplus
extern "C" {
#endif

#include <stdlib.h>
#include <math.h>

#include <SDL3/SDL.h>
#include <SDL3_image/SDL_image.h>
#include <SDL3_mixer/SDL_mixer.h>
#include <SDL3_ttf/SDL_ttf.h>


// Platform Specifics //////////////////////////////////////////////////////////

#ifdef _WIN32
  #include <io.h>
  #define  F_OK 0  // for testing file existence
#else
  #include <unistd.h>
#endif

#ifdef __EMSCRIPTEN__
  #include <emscripten.h>
#endif


// Ruby/MRuby Abstraction Macros ///////////////////////////////////////////////
//
// These macros provide a unified C API across CRuby and mruby so that
// extension code never calls rb_* or mrb_* directly. Grouped by functionality,
// with both implementations shown side-by-side for easy comparison.

// --- MRuby Type Conversions (mruby only) -------------------------------------
// CRuby provides these natively; mruby needs shims to match the CRuby API.
// The full set is kept for parity even if a given macro is currently unused.
#ifdef MRUBY
  // C to Ruby value
  #define INT2FIX(val)   (mrb_fixnum_value(val))
  #define INT2NUM(val)   (mrb_fixnum_value((mrb_int)(val)))
  #define UINT2NUM(val)  (INT2NUM((unsigned mrb_int)(val)))
  #define LL2NUM(val)    (INT2NUM(val))
  #define ULL2NUM(val)   (INT2NUM((uint64_t)(val)))
  #define DBL2NUM(val)   (mrb_float_value(mrb, (mrb_float)(val)))
  // Ruby value to C
  #define TO_PDT(val)    ((mrb_type(val) == MRB_TT_FLOAT) ? mrb_float(val) : mrb_int(mrb, (val)))
  #define FIX2INT(val)   (mrb_fixnum(val))
  #define NUM2INT(val)   ((mrb_int)TO_PDT(val))
  #define NUM2UINT(val)  ((unsigned mrb_int)TO_PDT(val))
  #define NUM2LONG(val)  (mrb_int(mrb, (val)))
  #define NUM2LL(val)    ((int64_t)(TO_PDT(val)))
  #define NUM2ULL(val)   ((uint64_t)(TO_PDT(val)))
  #define NUM2DBL(val)   (mrb_as_float(mrb, (val)))
  #define NUM2CHR(val)   ((mrb_string_p(val) && (RSTRING_LEN(val)>=1)) ? RSTRING_PTR(val)[0] : (char)(NUM2INT(val) & 0xff))
  // Memory management
  #define ALLOC(type)        ((type *)mrb_malloc(mrb, sizeof(type)))
  #define ALLOC_N(type, n)   ((type *)mrb_malloc(mrb, sizeof(type) * (n)))
  #define ALLOCA_N(type, n)  ((type *)alloca(sizeof(type) * (n)))
  #define MEMCMP(p1, p2, type, n)  (memcmp((p1), (p2), sizeof(type)*(n)))
  #define xfree(ptr)         mrb_free(mrb, ptr)
#endif

// --- Core Value Types --------------------------------------------------------
// Fundamental type aliases used everywhere in the abstraction layer.
#ifdef MRUBY
  #define R_VAL    mrb_value
  #define R_NIL    (mrb_nil_value())
  #define R_TRUE   (mrb_true_value())
  #define R_FALSE  (mrb_false_value())
  #define R_CLASS  struct RClass *
  #define R_ID     mrb_sym
#else
  #define R_VAL    VALUE
  #define R_NIL    Qnil
  #define R_TRUE   Qtrue
  #define R_FALSE  Qfalse
  #define R_CLASS  R_VAL
  #define R_ID     ID
#endif

// --- Instance Variable Access ------------------------------------------------
// r_iv_get/set: access by string name (e.g. "@width") — interns on each call.
// r_ivar_get/set: access by pre-interned R_ID — faster in hot paths.
#ifdef MRUBY
  #define r_iv_get(self, var)         mrb_iv_get(mrb, self, mrb_intern_lit(mrb, var))
  #define r_iv_set(self, var, val)    mrb_iv_set(mrb, self, mrb_intern_lit(mrb, var), val)
  #define r_ivar_get(obj, id)         mrb_iv_get(mrb, (obj), (id))
  #define r_ivar_set(obj, id, val)    mrb_iv_set(mrb, (obj), (id), (val))
#else
  #define r_iv_get(self, var)         rb_iv_get(self, var)
  #define r_iv_set(self, var, val)    rb_iv_set(self, var, val)
  #define r_ivar_get(obj, id)         rb_ivar_get((obj), (id))
  #define r_ivar_set(obj, id, val)    rb_ivar_set((obj), (id), (val))
#endif

// --- Function Calls, Strings, Truthiness -------------------------------------
// r_funcall: call a Ruby method by name on an object.
// r_str_new: create a Ruby string from a C string.
// r_test: check if a Ruby value is truthy (not nil/false).
#ifdef MRUBY
  #define r_funcall(self, method, n, ...)  mrb_funcall(mrb, self, method, n, ##__VA_ARGS__)
  #define r_str_new(str)                   mrb_str_new(mrb, str, strlen(str))
  #define r_test(val)                      (mrb_test(val) == true)
#else
  #define r_funcall(self, method, n, ...)  rb_funcall(self, rb_intern(method), n, ##__VA_ARGS__)
  #define r_str_new(str)                   rb_str_new2(str)
  #define r_test(val)                      (val != Qfalse && val != Qnil)
#endif

// --- GC Arena ----------------------------------------------------------------
// r_gc_arena_save / r_gc_arena_restore: bracket C-driven calls into Ruby so
// values they pin in mruby's GC arena are released. mruby's mrb_funcall keeps
// its return value arena-protected for the C caller; a call site that runs once
// per frame outside the VM (the main-loop tick) would otherwise grow the arena
// unboundedly whenever the called method returns a heap object. No-ops on
// CRuby, which has no arena.
#ifdef MRUBY
  #define r_gc_arena_save()         mrb_gc_arena_save(mrb)
  #define r_gc_arena_restore(idx)   mrb_gc_arena_restore(mrb, idx)
#else
  #define r_gc_arena_save()         0
  #define r_gc_arena_restore(idx)   ((void)(idx))
#endif

// --- Symbols & IDs -----------------------------------------------------------
// r_char_to_sym: C string → Ruby symbol value.
// r_id: C string → interned ID for fast repeated lookups.
// r_sym_to_id: Ruby symbol value → interned ID.
#ifdef MRUBY
  #define r_char_to_sym(str)  mrb_symbol_value(mrb_intern_cstr(mrb, str))
  #define r_id(str)           mrb_intern_cstr(mrb, str)
  #define r_sym_to_id(val)    mrb_symbol(val)
#else
  #define r_char_to_sym(str)  ID2SYM(rb_intern(str))
  #define r_id(str)           rb_intern(str)
  #define r_sym_to_id(val)    rb_sym2id(val)
#endif

// --- Arrays ------------------------------------------------------------------
// Create, access, and push to Ruby arrays.
#ifdef MRUBY
  #define r_ary_new()             mrb_ary_new(mrb)
  #define r_ary_push(self, val)   mrb_ary_push(mrb, self, val)
  #define r_ary_entry(ary, pos)   mrb_ary_entry(ary, pos)
  #define r_ary_len(self)         RARRAY_LEN(self)
#else
  #define r_ary_new()             rb_ary_new()
  #define r_ary_push(self, val)   rb_ary_push(self, val)
  #define r_ary_entry(ary, pos)   rb_ary_entry(ary, pos)
  #define r_ary_len(self)         RARRAY_LEN(self)
#endif

// --- Data Wrapping -----------------------------------------------------------
// Wrap/unwrap C structs as Ruby objects for the GC to manage.
// r_wrap_struct / r_unwrap_struct: wrap a C pointer into a Ruby object / get
//   the pointer back. Used by Ruby2D::Ext bindings that receive opaque handles
//   as method arguments.
// r_data_ptr: get the raw C pointer from a wrapped Ruby object (untyped form
//   used for opaque ext_* ivar handles when the type is known from context).
#ifdef MRUBY
  #define r_wrap_struct(type, ptr) \
    mrb_obj_value(Data_Wrap_Struct(mrb, mrb->object_class, &type##_data_type, ptr))
  #define r_unwrap_struct(val, type)  ((type *)DATA_PTR(val))
  #define r_data_ptr(val)             DATA_PTR(val)
#else
  #define r_wrap_struct(type, ptr) \
    TypedData_Wrap_Struct(rb_cObject, &type##_data_type, ptr)
  #define r_unwrap_struct(val, type)  ((type *)RTYPEDDATA_DATA(val))
  #define r_data_ptr(val)             RTYPEDDATA_DATA(val)
#endif

// --- Module and Method Definition --------------------------------------------
// Define the Ruby2D module and Ruby2D::Ext class methods from C. User-facing
// Ruby classes (Triangle, Window, ...) are defined in Ruby, not here.
// r_args_variadic: marks Ext bindings as variable-arity (args via argv).
#ifdef MRUBY
  #define r_define_module(name)                          mrb_define_module(mrb, name)
  #define r_define_module_under(parent, name)            mrb_define_module_under(mrb, parent, name)
  #define r_define_class_method(klass, name, fn, args)   mrb_define_class_method(mrb, klass, name, fn, args)
  #define r_args_variadic  (MRB_ARGS_ANY())
#else
  #define r_define_module(name)                          rb_define_module(name)
  #define r_define_module_under(parent, name)            rb_define_module_under(parent, name)
  #define r_define_class_method(klass, name, fn, args)   rb_define_singleton_method(klass, name, fn, args)
  #define r_args_variadic  (-1)
#endif

// --- Error Handling ----------------------------------------------------------
// Raise a RuntimeError with a formatted message. Use for internal/unexpected
// failures (programmer errors, SDL calls that shouldn't fail).
#ifdef MRUBY
  #define r_raise(...)  mrb_raisef(mrb, mrb_class_get(mrb, "RuntimeError"), __VA_ARGS__)
#else
  #define r_raise(...)  rb_raise(rb_eRuntimeError, __VA_ARGS__)
#endif

// Raise a Ruby2D::Error with a formatted message. Use for user-facing failures
// (missing/corrupt/invalid assets) so they share one rescuable exception class
// with the Ruby-side raises. `ruby2d_module` is set in R2D_Init and Ruby2D::Error
// is defined before the extension loads, so the lookup is always valid here.
#ifdef MRUBY
  #define r_error(...)  mrb_raisef(mrb, mrb_class_get_under(mrb, ruby2d_module, "Error"), __VA_ARGS__)
#else
  #define r_error(...)  rb_raise(rb_const_get(ruby2d_module, rb_intern("Error")), __VA_ARGS__)
#endif

// --- Data Type Definition ----------------------------------------------------
// Declare a GC-friendly data type for wrapping C structs as Ruby objects.
// Each TYPE must provide a TYPE_free(void *ptr) function. The macro generates
// the glue needed by each runtime's data-wrapping API.
#ifdef MRUBY
  #define R2D_DEFINE_DATA_TYPE(TYPE) \
    static void TYPE##_free(void *ptr); \
    static void TYPE##_mrb_free(mrb_state *mrb, void *ptr) { \
      (void)mrb; TYPE##_free(ptr); \
    } \
    static const struct mrb_data_type TYPE##_data_type = { \
      #TYPE, \
      TYPE##_mrb_free \
    }
#else
  #define R2D_DEFINE_DATA_TYPE(TYPE) \
    static size_t TYPE##_memsize(const void *ptr) { \
      return ptr ? sizeof(TYPE) : 0; \
    } \
    static void TYPE##_free(void *ptr); \
    static const rb_data_type_t TYPE##_data_type = { \
      #TYPE, \
      { \
        0, /* dmark: no Ruby VALUEs inside, so no mark needed */ \
        TYPE##_free, /* dfree */ \
        TYPE##_memsize /* dsize */ \
      }, \
      0, 0, \
      RUBY_TYPED_FREE_IMMEDIATELY \
    }
#endif

// --- Instance Variable Attribute Macros --------------------------------------
// Convenience get/set wrappers for common scalar and struct types stored as
// instance variables on a Ruby object passed in via argv. Used by Ruby2D::Ext
// bindings; the `obj` argument names which Ruby object to read/write.
//
// Usage:
//   int w = obj_int(img, id_width);
//   obj_set_int(img, id_width, w * 2);
//   const char *title = obj_str(win, id_title);
//   R2D_Image *p; obj_struct(img, id_ext_image, R2D_Image, p);

#define obj_int(obj, id)                NUM2INT(r_ivar_get((obj), (id)))
#define obj_set_int(obj, id, val)       r_ivar_set((obj), (id), INT2NUM(val))
#define obj_float(obj, id)              NUM2DBL(r_ivar_get((obj), (id)))
#define obj_set_float(obj, id, val)     r_ivar_set((obj), (id), DBL2NUM(val))
#define obj_bool(obj, id)               r_test(r_ivar_get((obj), (id)))
#define obj_set_bool(obj, id, val)      r_ivar_set((obj), (id), (val) ? R_TRUE : R_FALSE)
#define obj_str(obj, id)                RSTRING_PTR(r_ivar_get((obj), (id)))
// Byte length of the string ivar — the exact count obj_str's pointer spans,
// including any embedded NULs. Use alongside obj_str when a length-terminated
// API is needed (e.g. TTF_RenderText_*) instead of relying on NUL-termination.
#define obj_str_len(obj, id)            ((size_t)RSTRING_LEN(r_ivar_get((obj), (id))))
#define obj_set_str(obj, id, val)       r_ivar_set((obj), (id), r_str_new(val))

#ifdef MRUBY
  #define obj_struct(obj, id, type, ptr_var) \
    Data_Get_Struct(mrb, r_ivar_get((obj), (id)), &type##_data_type, ptr_var)
#else
  #define obj_struct(obj, id, type, ptr_var) \
    TypedData_Get_Struct(r_ivar_get((obj), (id)), type, &type##_data_type, ptr_var)
#endif

// Wrap `ptr` as a Ruby data object and store it in ivar `id`. The wrap form is
// identical for CRuby and mruby once routed through r_wrap_struct.
#define obj_set_struct(obj, id, type, ptr) \
  r_ivar_set((obj), (id), r_wrap_struct(type, ptr))

// --- Method Signature / Argument Extraction ----------------------------------
// Every Ruby2D::Ext binding uses the VARIADIC form (variable arity, args
// unpacked from argv). The first arg is conventionally the Ruby object the
// binding operates on; remaining args are method-specific.
#ifdef MRUBY
  #define RUBY2D_METHOD_ARGS_VARIADIC        mrb_state* mrb, R_VAL self
  #define RUBY2D_EXTRACT_VARIADIC            \
    mrb_value *argv;                         \
    mrb_int argc;                            \
    mrb_get_args(mrb, "*", &argv, &argc)
#else
  #define RUBY2D_METHOD_ARGS_VARIADIC        int argc, R_VAL *argv, R_VAL self
  #define RUBY2D_EXTRACT_VARIADIC            ((void)0)
#endif


// Constants ///////////////////////////////////////////////////////////////////

// Messages
#define R2D_INFO  1
#define R2D_WARN  2
#define R2D_ERROR 3

// Window attributes
#define R2D_RESIZABLE  SDL_WINDOW_RESIZABLE
#define R2D_HIGHDPI    SDL_WINDOW_HIGH_PIXEL_DENSITY
#define R2D_DISPLAY_WIDTH  0
#define R2D_DISPLAY_HEIGHT 0

// Viewport scaling modes — control how the logical viewport maps to the window
// when the window is resized.
//
//   LETTERBOX  Scales the viewport uniformly to fit the window, adding black
//              bars on the sides or top/bottom to preserve the aspect ratio.
//   STRETCH    Stretches the viewport to fill the entire window, which may
//              distort the aspect ratio.
//   INTEGER    Scales using the largest integer multiplier that fits within the
//              window, keeping pixels crisp (useful for pixel art).
//   OVERSCAN   Scales the viewport uniformly to cover the entire window,
//              cropping any content that extends beyond the window edges.
//   EXPAND     Grows or shrinks the viewport coordinate space to match the
//              window size. Content is not scaled — more or less of the world
//              becomes visible as the window resizes.
//   FIXED      The viewport is not scaled or adjusted. Content is drawn 1:1 at
//              its original size regardless of the window dimensions.
#define R2D_VIEWPORT_LETTERBOX 1
#define R2D_VIEWPORT_STRETCH   2
#define R2D_VIEWPORT_INTEGER   3
#define R2D_VIEWPORT_OVERSCAN  4
#define R2D_VIEWPORT_EXPAND    5
#define R2D_VIEWPORT_FIXED     6

// Render modes — control when the window presents frames.
//
//   CONTINUOUS  Render every tick up to fps_cap. Default; right for games and
//               anything with continuous animation.
//   ON_DEMAND   Only render when Window#request_render is called, or when SDL
//               signals the window must be redrawn (expose, resize, display
//               change). Input, update, and frame pacing still run every tick.
//               Right for apps whose contents change only in response to input:
//               charts, IDEs, dashboards, most non-game GUIs.
#define R2D_RENDER_CONTINUOUS  1
#define R2D_RENDER_ON_DEMAND   2

// Keyboard events
#define R2D_KEY_DOWN 1  // key is pressed
#define R2D_KEY_HELD 2  // key is held down
#define R2D_KEY_UP   3  // key is released

// Mouse events
#define R2D_MOUSE_DOWN   1  // mouse button pressed
#define R2D_MOUSE_UP     2  // mouse button released
#define R2D_MOUSE_SCROLL 3  // mouse scrolling or wheel movement
#define R2D_MOUSE_MOVE   4  // mouse movement
#define R2D_MOUSE_HELD   5  // mouse button is held down
#define R2D_MOUSE_ENTER  6  // cursor entered the window
#define R2D_MOUSE_LEAVE  7  // cursor left the window

// Mouse buttons
#define R2D_MOUSE_LEFT   SDL_BUTTON_LEFT
#define R2D_MOUSE_MIDDLE SDL_BUTTON_MIDDLE
#define R2D_MOUSE_RIGHT  SDL_BUTTON_RIGHT
#define R2D_MOUSE_X1     SDL_BUTTON_X1
#define R2D_MOUSE_X2     SDL_BUTTON_X2
#define R2D_MOUSE_SCROLL_NORMAL   SDL_MOUSEWHEEL_NORMAL
#define R2D_MOUSE_SCROLL_INVERTED SDL_MOUSEWHEEL_FLIPPED

// Gamepad events
#define R2D_GAMEPAD_CONNECT      1
#define R2D_GAMEPAD_DISCONNECT   2
#define R2D_GAMEPAD_AXIS         3
#define R2D_GAMEPAD_BUTTON_DOWN  4
#define R2D_GAMEPAD_BUTTON_UP    5
#define R2D_GAMEPAD_BUTTON_HELD  6

// Gamepad axis labels
#define R2D_AXIS_INVALID       SDL_GAMEPAD_AXIS_INVALID
#define R2D_AXIS_LEFTX         SDL_GAMEPAD_AXIS_LEFTX
#define R2D_AXIS_LEFTY         SDL_GAMEPAD_AXIS_LEFTY
#define R2D_AXIS_RIGHTX        SDL_GAMEPAD_AXIS_RIGHTX
#define R2D_AXIS_RIGHTY        SDL_GAMEPAD_AXIS_RIGHTY
#define R2D_AXIS_LEFT_TRIGGER  SDL_GAMEPAD_AXIS_LEFT_TRIGGER
#define R2D_AXIS_RIGHT_TRIGGER SDL_GAMEPAD_AXIS_RIGHT_TRIGGER
#define R2D_AXIS_COUNT         SDL_GAMEPAD_AXIS_COUNT

// Bitmap font
#define R2D_FONT_GLYPH_WIDTH   5
#define R2D_FONT_GLYPH_HEIGHT  7
#define R2D_FONT_FIRST_CHAR    0x20
#define R2D_FONT_LAST_CHAR     0x7E
#define R2D_FONT_NUM_GLYPHS    95

// Gamepad button labels
#define R2D_BUTTON_INVALID        SDL_GAMEPAD_BUTTON_INVALID
#define R2D_BUTTON_SOUTH          SDL_GAMEPAD_BUTTON_SOUTH
#define R2D_BUTTON_EAST           SDL_GAMEPAD_BUTTON_EAST
#define R2D_BUTTON_WEST           SDL_GAMEPAD_BUTTON_WEST
#define R2D_BUTTON_NORTH          SDL_GAMEPAD_BUTTON_NORTH
#define R2D_BUTTON_BACK           SDL_GAMEPAD_BUTTON_BACK
#define R2D_BUTTON_GUIDE          SDL_GAMEPAD_BUTTON_GUIDE
#define R2D_BUTTON_START          SDL_GAMEPAD_BUTTON_START
#define R2D_BUTTON_LEFT_STICK     SDL_GAMEPAD_BUTTON_LEFT_STICK
#define R2D_BUTTON_RIGHT_STICK    SDL_GAMEPAD_BUTTON_RIGHT_STICK
#define R2D_BUTTON_LEFT_SHOULDER  SDL_GAMEPAD_BUTTON_LEFT_SHOULDER
#define R2D_BUTTON_RIGHT_SHOULDER SDL_GAMEPAD_BUTTON_RIGHT_SHOULDER
#define R2D_BUTTON_DPAD_UP        SDL_GAMEPAD_BUTTON_DPAD_UP
#define R2D_BUTTON_DPAD_DOWN      SDL_GAMEPAD_BUTTON_DPAD_DOWN
#define R2D_BUTTON_DPAD_LEFT      SDL_GAMEPAD_BUTTON_DPAD_LEFT
#define R2D_BUTTON_DPAD_RIGHT     SDL_GAMEPAD_BUTTON_DPAD_RIGHT
#define R2D_BUTTON_MISC1          SDL_GAMEPAD_BUTTON_MISC1
#define R2D_BUTTON_PADDLE1        SDL_GAMEPAD_BUTTON_RIGHT_PADDLE1
#define R2D_BUTTON_PADDLE2        SDL_GAMEPAD_BUTTON_LEFT_PADDLE1
#define R2D_BUTTON_PADDLE3        SDL_GAMEPAD_BUTTON_RIGHT_PADDLE2
#define R2D_BUTTON_PADDLE4        SDL_GAMEPAD_BUTTON_LEFT_PADDLE2
#define R2D_BUTTON_TOUCHPAD       SDL_GAMEPAD_BUTTON_TOUCHPAD
#define R2D_BUTTON_MISC2          SDL_GAMEPAD_BUTTON_MISC2
#define R2D_BUTTON_MISC3          SDL_GAMEPAD_BUTTON_MISC3
#define R2D_BUTTON_MISC4          SDL_GAMEPAD_BUTTON_MISC4
#define R2D_BUTTON_MISC5          SDL_GAMEPAD_BUTTON_MISC5
#define R2D_BUTTON_MISC6          SDL_GAMEPAD_BUTTON_MISC6
#define R2D_BUTTON_COUNT          SDL_GAMEPAD_BUTTON_COUNT

// Gamepad battery state
#define R2D_GAMEPAD_BATTERY_UNKNOWN     0
#define R2D_GAMEPAD_BATTERY_WIRED       1
#define R2D_GAMEPAD_BATTERY_ON_BATTERY  2

// Gamepad capability bits (returned by R2D_GetGamepadCaps)
#define R2D_GAMEPAD_CAP_RUMBLE          (1 << 0)
#define R2D_GAMEPAD_CAP_RUMBLE_TRIGGERS (1 << 1)
#define R2D_GAMEPAD_CAP_RGB_LED         (1 << 2)


// Structs /////////////////////////////////////////////////////////////////////

// Pull-model event buffer — poll_events queues events into a C-side buffer;
// drain_events returns them to Ruby as a flat array with R2D_EVT_STRIDE
// elements per event.
#define R2D_EVT_KEY     1
#define R2D_EVT_MOUSE   2
#define R2D_EVT_GAMEPAD 3
#define R2D_EVT_CLOSE   4
#define R2D_EVT_STRIDE  12

typedef struct {
  int category;
  int type;
  int id;
  int button;
  int direction;
  int axis;
  int x;
  int y;
  float delta_x;
  float delta_y;
  int value;
  const char *str;
} R2D_QueuedEvent;

// R2D_Color
typedef struct {
  float r;
  float g;
  float b;
  float a;
} R2D_Color;

// R2D_Mouse
typedef struct {
  int x;
  int y;
} R2D_Mouse;

// R2D_Viewport
typedef struct {
  int width;
  int height;
  int base_width;   // User-intended viewport width (not modified by expand resize)
  int base_height;  // User-intended viewport height (not modified by expand resize)
  int mode;
  SDL_Rect fixed_rect;  // Pixel-space rect for fixed mode (centered in output)
} R2D_Viewport;

// R2D_Window
typedef struct {
  SDL_Window *sdl_window;
  SDL_Renderer *sdl_renderer;
  const char *title;
  int width;
  int height;
  int orig_width;
  int orig_height;
  int display_width;
  int display_height;
  float display_content_scale;
  float display_scale;
  float display_refresh_rate;
  R2D_Viewport viewport;
  int flags;
  R2D_Color background;
  R2D_Mouse mouse;
  int fps_cap;
  const char *icon;
  uint64_t frames;
  double fps;
  bool close;
  bool pixel_scale;
  int render_mode;              // R2D_RENDER_CONTINUOUS or R2D_RENDER_ON_DEMAND
  SDL_AtomicInt render_pending; // Set by request_render, cleared each rendered frame
  float asset_scale;            // DPI-aware coordinate multiplier for canvas/text
  int display_pixel_width;
  int display_pixel_height;
  bool diagnostics;
  bool show_fps;
  char *screenshot_path;        // deferred screenshot request (consumed once per frame)
} R2D_Window;

// R2D_Image
typedef struct {
  SDL_Surface *surface;
  SDL_Texture *texture;
} R2D_Image;

// R2D_FontCacheEntry (defined in text.c)
typedef struct R2D_FontCacheEntry R2D_FontCacheEntry;

// R2D_Text
typedef struct {
  SDL_Surface *surface;
  SDL_Texture *texture;
  R2D_FontCacheEntry *font_entry;
  // When non-NULL, `surface` is a shared handle owned by the text surface cache
  // and must be released via R2D_TextSurfaceCacheRelease, not SDL_DestroySurface.
  // When NULL, `surface` is owned by this R2D_Text (the cache-full degraded path).
  char *cached_text;
  // Byte length of `cached_text` (the content may contain embedded NULs, so the
  // cache key is compared by length + memcmp, not strcmp). Valid when
  // cached_text != NULL.
  size_t cached_text_len;
  // The asset scale the surface was rasterized at. When this differs from the
  // current scale (e.g. the Text was built before the window opened, at scale
  // 1.0), the surface is re-rasterized at draw time so HiDPI text stays crisp.
  float rendered_scale;
  // Content is empty (""). No surface is built; width is reported as 0
  // (height stays the font's line height). The draw paths treat this as
  // "nothing to draw" rather than a rasterization failure.
  bool empty;
  // GPU texture refresh state. texture_stale marks a freshly rasterized
  // surface not yet reflected in the texture; text_draw refreshes with a
  // platform-split strategy (see its comment): the web build keeps a
  // persistent grow-only texture of tex_w x tex_h capacity, updated in place
  // and drawn via a src rect; native recreates the texture per change
  // (tex_w/tex_h unused there).
  bool texture_stale;
  int tex_w;
  int tex_h;
} R2D_Text;

// R2D_Canvas
typedef struct {
  SDL_Surface *surface;
  SDL_Texture *texture;
  // The asset scale the surface was allocated at. Every draw uses this cached
  // value rather than the live window scale, so a Canvas built before the
  // window opens still draws into the correct sub-rect afterward.
  float scale;
  // Region of `surface` mutated since the last GPU upload, in surface pixel
  // coordinates. When `dirty` is false the texture matches the surface and
  // ext_draw skips the upload entirely.
  bool dirty;
  SDL_Rect dirty_rect;
} R2D_Canvas;

// R2D_BitmapText
typedef struct {
  SDL_Texture *texture;
  char *text;
  int scale;
  bool background;
  float logical_w;
  float logical_h;
  // GPU texture refresh state, platform-split like R2D_Text: the web build
  // keeps a persistent grow-only texture of tex_w x tex_h capacity (unused on
  // native, which recreates per change). The current string occupies the
  // top-left content_w x content_h and draws via a src rect (zero when the
  // string is empty).
  int tex_w;
  int tex_h;
  int content_w;
  int content_h;
} R2D_BitmapText;

// R2D_Audio
typedef struct {
  MIX_Audio *mix_audio;
  MIX_Track *mix_track;
} R2D_Audio;

// State Access ////////////////////////////////////////////////////////////////
//
// Each subsystem owns its state as a file-static and exposes it through
// getter/setter functions. No extern mutable globals for runtime state.

// Window state — owned by window.c
R2D_Window *R2D_GetWindow(void);

// Whether the renderer is still alive; texture finalizers check this before
// SDL_DestroyTexture so they no-op safely after the window/renderer is freed.
bool R2D_RendererAlive(void);
SDL_Renderer *R2D_GetRenderer(void);
float R2D_GetAssetScale(void);
float R2D_GetDisplayScale(void);
void R2D_SetWindow(R2D_Window *window);

// Mixer — owned by audio.c
void R2D_SetMixer(MIX_Mixer *mixer);
MIX_Mixer *R2D_GetMixer(void);

// Lazily open the audio mixer device. Kept out of R2D_Init so graphics can
// initialize on a machine with no/blocked playback device; audio entry points
// call this and surface a clear error only when audio is actually used.
bool R2D_InitAudio(void);

// Pre-window display info — populated by R2D_Init(), consumed by window_create.
// After window creation the R2D_Window fields are the canonical source.
float R2D_GetInitDisplayScale(void);
float R2D_GetInitContentScale(void);
float R2D_GetInitRefreshRate(void);
int   R2D_GetInitDisplayWidth(void);
int   R2D_GetInitDisplayHeight(void);
int   R2D_GetInitDisplayPixelWidth(void);
int   R2D_GetInitDisplayPixelHeight(void);


// Globals /////////////////////////////////////////////////////////////////////

// Ruby 2D module
extern R_CLASS ruby2d_module;


// Utility /////////////////////////////////////////////////////////////////////

/*
 * Checks if a file exists and can be accessed
 */
bool R2D_FileExists(const char *path);

/*
 * Logs standard messages to the console
 */
void R2D_Log(int type, const char *msg, ...);

/*
 * Warn once per process if an SDL render call reported failure (avoids
 * per-frame log flooding on a persistent GPU/driver fault)
 */
void R2D_CheckSDL(bool ok, const char *what);

/*
 * Logs Ruby 2D errors to the console, with caller and message body
 */
void R2D_Error(const char *caller, const char *msg, ...);

/*
 * Enable/disable logging of diagnostics
 */
void R2D_Diagnostics(bool status);

/*
 * Enable/disable FPS display
 */
void R2D_ShowFPS(bool status);

/*
 * Calculate rolling average frame rate
 */
double R2D_GetFrameRate(void);

/*
 * Draw FPS counter overlay on the window
 */
void R2D_DrawFrameRate(R2D_Window *window);

/*
 * Free the cached FPS overlay resources
 */
void R2D_FreeFpsOverlay(void);

/*
 * Allocate a new bitmap text handle
 */
R2D_BitmapText *R2D_CreateBitmapText(void);

/*
 * Free a bitmap text handle and its cached resources
 */
void R2D_FreeBitmapText(R2D_BitmapText *bt);

/*
 * Render a string to a cached texture (no-op if string unchanged)
 */
void R2D_UpdateBitmapText(R2D_BitmapText *bt, SDL_Renderer *renderer,
                          const char *text, int scale);

/*
 * Draw cached bitmap text texture at (x, y) in logical coordinates
 */
void R2D_DrawBitmapText(R2D_BitmapText *bt, SDL_Renderer *renderer,
                        float x, float y);

/*
 * Initialize Ruby 2D subsystems
 */
bool R2D_Init(void);

/*
 * Gets the primary display's dimensions
 */
void R2D_GetDisplayDimensions(int *w, int *h);

/*
 * Add gamepad mappings from a file. Returns the number of mappings added,
 * or -1 on error.
 */
int R2D_AddGamepadMappingsFromFile(const char *path);

/*
 * Add a single gamepad mapping from a string. Returns 1 if added, 0 if it
 * updated an existing mapping, or -1 on error.
 */
int R2D_AddGamepadMapping(const char *mapping);

/*
 * Trigger whole-gamepad rumble. Strengths are 0.0..1.0; duration is in
 * seconds. Returns true on success.
 */
bool R2D_RumbleGamepad(SDL_JoystickID id, double low, double high, double duration);

/*
 * Trigger trigger-only rumble (PS5/DualSense, Xbox Series with adaptive
 * triggers, etc). Strengths are 0.0..1.0; duration is in seconds.
 * Returns true on success.
 */
bool R2D_RumbleGamepadTriggers(SDL_JoystickID id, double left, double right, double duration);

/*
 * Set the gamepad's LED color (PS4/PS5). Components are 0..255.
 * Returns true on success.
 */
bool R2D_SetGamepadLED(SDL_JoystickID id, int r, int g, int b);

/*
 * Look up the gamepad's battery status. Writes a percent (0..100, or -1
 * if unknown) to *out_percent and returns one of the R2D_GAMEPAD_BATTERY_*
 * constants.
 */
int R2D_GetGamepadBattery(SDL_JoystickID id, int *out_percent);

/*
 * Capability checks. Return true if the connected gamepad reports the
 * given button or axis.
 */
bool R2D_GamepadHasButton(SDL_JoystickID id, int button);
bool R2D_GamepadHasAxis(SDL_JoystickID id, int axis);

/*
 * Returns a bitfield of R2D_GAMEPAD_CAP_* flags describing which feedback
 * capabilities the gamepad reports.
 */
int R2D_GetGamepadCaps(SDL_JoystickID id);


// Ext /////////////////////////////////////////////////////////////////////////

/*
 * The Ruby2D::Ext module — Ruby-callable bindings to libruby2d C primitives.
 * Subsystem .c files (audio, image, text, etc.) register their own bindings
 * on this module in their R2D_*_Init functions.
 */
extern R_CLASS ruby2d_ext_module;

/*
 * Shared ivar ID cache. Subsystem .c files reference these instead of
 * caching their own per-file copies. Defined and interned in R2D_Ext_Init
 * (ext.c). Subsystem-specific ivars (e.g. @clip_x, @fps_cap, @ext_audio)
 * stay as static R_IDs in the subsystem that owns them.
 */
extern R_ID id_x, id_y, id_width, id_height, id_rotate;
extern R_ID id_color, id_r, id_g, id_b, id_a;
extern R_ID id_ext_image, id_ext_text;
extern R_ID id_path, id_content;
extern R_ID id_viewport_width, id_viewport_height;

/*
 * Initialize Ruby2D::Ext — creates the module and registers shape bindings.
 * Must run before any other R2D_*_Init so the module exists for them.
 */
void R2D_Ext_Init(void);


// Shapes //////////////////////////////////////////////////////////////////////
//
// Pure C primitives. Ruby-callable wrappers live in ext.c (Ruby2D::Ext).

/*
 * Draw a triangle
 */
void R2D_DrawTriangle(
  float x1, float y1,
  float r1, float g1, float b1, float a1,
  float x2, float y2,
  float r2, float g2, float b2, float a2,
  float x3, float y3,
  float r3, float g3, float b3, float a3
);

/*
 * Draw a quad, using two triangles
 */
void R2D_DrawQuad(
  float x1, float y1,
  float r1, float g1, float b1, float a1,
  float x2, float y2,
  float r2, float g2, float b2, float a2,
  float x3, float y3,
  float r3, float g3, float b3, float a3,
  float x4, float y4,
  float r4, float g4, float b4, float a4
);

/*
 * Draw a line from a quad
 */
void R2D_DrawLine(
  float x1, float y1, float x2, float y2,
  float width,
  float r1, float g1, float b1, float a1,
  float r2, float g2, float b2, float a2,
  float r3, float g3, float b3, float a3,
  float r4, float g4, float b4, float a4
);

/*
 * Draw a circle from triangles
 */
void R2D_DrawCircle(
  float x, float y, float radius, int sectors,
  float r, float g, float b, float a
);

/*
 * Compute the outer and inner outline points for a polyline or polygon stroke.
 * `verts` is a flat array of `n` (x, y) pairs. `closed` treats the polyline as
 * a closed polygon (corners computed for every vertex); otherwise endpoints get
 * butt caps. `stroke_width` is the total stroke thickness. `miter_limit` clamps
 * sharp corners (SVG default: 4.0). `outer` and `inner` must be preallocated
 * with `n * 2` floats each.
 */
void R2D_ComputeStrokeOutline(
  const float *verts, int n, int closed,
  float stroke_width, float miter_limit,
  float *outer, float *inner
);

// SVG default miter-limit (miter switches to clamped past this ratio)
#define R2D_MITER_LIMIT 4.0f

// Vertex-count threshold below which the stroke/geometry helpers serve their
// scratch buffers from the stack. Covers triangles (n=3), quads (n=4), default
// 30-sector circles/ellipses, and all but the largest polygons/polylines;
// larger paths fall back to the heap. Avoids per-frame malloc/free churn.
#define R2D_STROKE_STACK_N 64

/*
 * Stroke a polyline or closed polygon via SDL_RenderGeometry. Miter-joined
 * corners clamped at `miter_limit` (SVG default 4.0). When `closed` is non-zero
 * the last vertex connects back to the first; otherwise endpoints get butt caps.
 */
void R2D_StrokePath(
  const float *verts, int n, int closed,
  float stroke_width, float miter_limit,
  const float *colors
);

/*
 * Stroke an ellipse outline as a ring of triangles via SDL_RenderGeometry.
 * `angle` (radians) tilts the ellipse off-axis; pass 0 for axis-aligned.
 */
void R2D_StrokeEllipse(
  float cx, float cy, float rx, float ry, float angle,
  int sectors, float stroke_width,
  float r, float g, float b, float a
);

/*
 * Draw a filled ellipse via a triangle fan.
 * `angle` (radians) tilts the ellipse off-axis; pass 0 for axis-aligned.
 */
void R2D_DrawEllipse(
  float cx, float cy, float rx, float ry, float angle, int sectors,
  float r, float g, float b, float a
);

/*
 * Triangulate a simple polygon by ear clipping.
 * `verts` is n pairs of (x, y). On success returns a malloc'd array of
 * (n - 2) * 3 vertex indices (caller must free) and writes the triangle
 * count to *out_tri_count. Returns NULL on failure (n < 3, allocation,
 * or degenerate input). Self-intersecting input is out of scope: output
 * is defined but may not be visually faithful.
 */
int *R2D_TriangulatePolygon(const float *verts, int n, int *out_tri_count);

/*
 * Draw a filled polygon. Triangulated via ear clipping so concave
 * polygons fill correctly. `verts` is n pairs of (x, y). When
 * `per_vertex_colors` is non-NULL it is n × 4 floats (rgba per vertex)
 * and overrides the single r,g,b,a color.
 */
void R2D_DrawPolygon(
  const float *verts, int n,
  const float *per_vertex_colors,
  float r, float g, float b, float a
);

/*
 * Draw a dashed line from (x1,y1) to (x2,y2) as repeated thick quads.
 * Each of the 4 input colors maps to a corner of the full line quad
 * (c1=start+perp, c2=start-perp, c3=end-perp, c4=end+perp). Per-segment
 * endpoint colors are linearly interpolated along the length.
 */
void R2D_DrawDashedLine(
  float x1, float y1, float x2, float y2,
  float stroke_width, float dash, float gap,
  float r1, float g1, float b1, float a1,
  float r2, float g2, float b2, float a2,
  float r3, float g3, float b3, float a3,
  float r4, float g4, float b4, float a4
);

// Image ///////////////////////////////////////////////////////////////////////
//
// SDL_image-backed textures. Ruby-callable bindings live as Ruby2D::Ext class
// methods (image_create, image_draw, image_draw_quads, image_resize). Bindings
// take the Image Ruby object as their first argument and read its ivars.

/*
 * Initialize Ruby2D::Ext image bindings.
 */
void R2D_Image_Init(void);

R_VAL ruby2d_ext_image_create(RUBY2D_METHOD_ARGS_VARIADIC);
R_VAL ruby2d_ext_image_draw(RUBY2D_METHOD_ARGS_VARIADIC);
R_VAL ruby2d_ext_image_draw_quads(RUBY2D_METHOD_ARGS_VARIADIC);
R_VAL ruby2d_ext_image_resize(RUBY2D_METHOD_ARGS_VARIADIC);


// Text ////////////////////////////////////////////////////////////////////////

/*
 * Initialize Ruby2D::Ext text bindings (TTF-backed text).
 */
void R2D_Text_Init(void);

R_VAL ruby2d_ext_text_create(RUBY2D_METHOD_ARGS_VARIADIC);
R_VAL ruby2d_ext_text_draw(RUBY2D_METHOD_ARGS_VARIADIC);


// BitmapText //////////////////////////////////////////////////////////////////

/*
 * Initialize Ruby2D::Ext bitmap-text bindings (built-in 5x7 font for overlays).
 */
void R2D_BitmapText_Init(void);

R_VAL ruby2d_ext_bitmap_text_create(RUBY2D_METHOD_ARGS_VARIADIC);
R_VAL ruby2d_ext_bitmap_text_draw(RUBY2D_METHOD_ARGS_VARIADIC);


// Canvas //////////////////////////////////////////////////////////////////////
//
// SDL_Surface-backed off-screen drawing target. Ruby-callable bindings live
// as Ruby2D::Ext class methods; bindings take the Canvas Ruby object as
// argv[0] and read ivars off it. Per-pixel kernels remain in C.

/*
 * Initialize Ruby2D::Ext canvas bindings.
 */
void R2D_Canvas_Init(void);

R_VAL ruby2d_ext_canvas_create(RUBY2D_METHOD_ARGS_VARIADIC);
R_VAL ruby2d_ext_canvas_draw(RUBY2D_METHOD_ARGS_VARIADIC);
R_VAL ruby2d_ext_canvas_clear(RUBY2D_METHOD_ARGS_VARIADIC);
R_VAL ruby2d_ext_canvas_fill_triangle(RUBY2D_METHOD_ARGS_VARIADIC);
R_VAL ruby2d_ext_canvas_fill_triangle_lerp(RUBY2D_METHOD_ARGS_VARIADIC);
R_VAL ruby2d_ext_canvas_fill_rectangle(RUBY2D_METHOD_ARGS_VARIADIC);
R_VAL ruby2d_ext_canvas_fill_rectangles(RUBY2D_METHOD_ARGS_VARIADIC);
R_VAL ruby2d_ext_canvas_fill_pixel_grid(RUBY2D_METHOD_ARGS_VARIADIC);
R_VAL ruby2d_ext_canvas_fill_ellipse(RUBY2D_METHOD_ARGS_VARIADIC);
R_VAL ruby2d_ext_canvas_fill_polygon(RUBY2D_METHOD_ARGS_VARIADIC);
R_VAL ruby2d_ext_canvas_fill_polygon_lerp(RUBY2D_METHOD_ARGS_VARIADIC);
R_VAL ruby2d_ext_canvas_draw_line(RUBY2D_METHOD_ARGS_VARIADIC);
R_VAL ruby2d_ext_canvas_draw_line_lerp(RUBY2D_METHOD_ARGS_VARIADIC);
R_VAL ruby2d_ext_canvas_draw_lines(RUBY2D_METHOD_ARGS_VARIADIC);
R_VAL ruby2d_ext_canvas_stroke_polygon(RUBY2D_METHOD_ARGS_VARIADIC);
R_VAL ruby2d_ext_canvas_stroke_polyline(RUBY2D_METHOD_ARGS_VARIADIC);
R_VAL ruby2d_ext_canvas_draw_image(RUBY2D_METHOD_ARGS_VARIADIC);
R_VAL ruby2d_ext_canvas_draw_text(RUBY2D_METHOD_ARGS_VARIADIC);


// Audio ///////////////////////////////////////////////////////////////////////
//
// SDL_mixer-backed audio. Ruby-callable bindings live as Ruby2D::Ext class
// methods registered in audio.c (audio_load, audio_play, audio_pause, ...).

/*
 * Initialize Ruby2D::Ext audio bindings.
 */
void R2D_Audio_Init(void);


// Window //////////////////////////////////////////////////////////////////////

/*
 * Initialize Ruby2D::Window native bindings
 */
void R2D_Window_Init(void);

/*
 * Apply viewport scaling mode via SDL3 logical presentation
 */
void R2D_ApplyViewportMode(R2D_Window *window);

/*
 * Set the icon for the window
 */
void R2D_SetIcon(R2D_Window *window, const char *icon);

/*
 * Take a screenshot of the window
 */
void R2D_Screenshot(R2D_Window *window, const char *path);

/*
 * Show the cursor over the window
 */
void R2D_ShowCursor(void);

/*
 * Hide the cursor over the window
 */
void R2D_HideCursor(void);

/*
 * Check if the cursor is visible
 */
bool R2D_CursorVisible(void);

/*
 * Set the system cursor by name. Returns true on success, false on failure.
 * Valid names: "default", "text", "wait", "crosshair", "progress",
 *   "nwse_resize", "nesw_resize", "ew_resize", "ns_resize", "move",
 *   "not_allowed", "pointer", "nw_resize", "n_resize", "ne_resize",
 *   "e_resize", "se_resize", "s_resize", "sw_resize", "w_resize"
 */
bool R2D_SetSystemCursor(const char *name);

/*
 * Close the window
 */
int R2D_Close(R2D_Window *window);

/*
 * Free all resources
 */
int R2D_FreeWindow(R2D_Window *window);

// Ruby2D::Ext window bindings — Ruby owns frame sequencing via its `tick`
// method: poll_events → drain_events → begin_frame → end_frame. Events are
// queued into a C-side buffer and returned to Ruby as a flat array; no
// C-to-Ruby callbacks. CRuby drives the loop from Ruby; mruby/WASM use a
// C-driven loop that calls Ruby's tick.
R_VAL ruby2d_ext_window_create(RUBY2D_METHOD_ARGS_VARIADIC);
R_VAL ruby2d_ext_window_show(RUBY2D_METHOD_ARGS_VARIADIC);
R_VAL ruby2d_ext_window_poll_events(RUBY2D_METHOD_ARGS_VARIADIC);
R_VAL ruby2d_ext_window_drain_events(RUBY2D_METHOD_ARGS_VARIADIC);
R_VAL ruby2d_ext_window_scancode_name(RUBY2D_METHOD_ARGS_VARIADIC);
R_VAL ruby2d_ext_window_begin_frame(RUBY2D_METHOD_ARGS_VARIADIC);
R_VAL ruby2d_ext_window_end_frame(RUBY2D_METHOD_ARGS_VARIADIC);
R_VAL ruby2d_ext_now(RUBY2D_METHOD_ARGS_VARIADIC);
R_VAL ruby2d_ext_window_get_display_dimensions(RUBY2D_METHOD_ARGS_VARIADIC);
R_VAL ruby2d_ext_window_set_viewport_mode(RUBY2D_METHOD_ARGS_VARIADIC);
R_VAL ruby2d_ext_window_set_icon(RUBY2D_METHOD_ARGS_VARIADIC);
R_VAL ruby2d_ext_window_set_title(RUBY2D_METHOD_ARGS_VARIADIC);
R_VAL ruby2d_ext_window_set_resizable(RUBY2D_METHOD_ARGS_VARIADIC);
R_VAL ruby2d_ext_window_set_size(RUBY2D_METHOD_ARGS_VARIADIC);
R_VAL ruby2d_ext_window_diagnostics(RUBY2D_METHOD_ARGS_VARIADIC);
R_VAL ruby2d_ext_window_set_fps_cap(RUBY2D_METHOD_ARGS_VARIADIC);
R_VAL ruby2d_ext_window_show_fps(RUBY2D_METHOD_ARGS_VARIADIC);
R_VAL ruby2d_ext_window_load_gamepad_mappings_file(RUBY2D_METHOD_ARGS_VARIADIC);
R_VAL ruby2d_ext_window_add_gamepad_mapping(RUBY2D_METHOD_ARGS_VARIADIC);
R_VAL ruby2d_ext_window_gamepad_rumble(RUBY2D_METHOD_ARGS_VARIADIC);
R_VAL ruby2d_ext_window_gamepad_rumble_triggers(RUBY2D_METHOD_ARGS_VARIADIC);
R_VAL ruby2d_ext_window_gamepad_set_led(RUBY2D_METHOD_ARGS_VARIADIC);
R_VAL ruby2d_ext_window_gamepad_type(RUBY2D_METHOD_ARGS_VARIADIC);
R_VAL ruby2d_ext_window_gamepad_battery(RUBY2D_METHOD_ARGS_VARIADIC);
R_VAL ruby2d_ext_window_gamepad_has_button(RUBY2D_METHOD_ARGS_VARIADIC);
R_VAL ruby2d_ext_window_gamepad_has_axis(RUBY2D_METHOD_ARGS_VARIADIC);
R_VAL ruby2d_ext_window_gamepad_caps(RUBY2D_METHOD_ARGS_VARIADIC);
R_VAL ruby2d_ext_window_gamepad_debug_info(RUBY2D_METHOD_ARGS_VARIADIC);
R_VAL ruby2d_ext_window_gamepad_joystick_state(RUBY2D_METHOD_ARGS_VARIADIC);
R_VAL ruby2d_ext_window_screenshot(RUBY2D_METHOD_ARGS_VARIADIC);
R_VAL ruby2d_ext_window_show_cursor(RUBY2D_METHOD_ARGS_VARIADIC);
R_VAL ruby2d_ext_window_hide_cursor(RUBY2D_METHOD_ARGS_VARIADIC);
R_VAL ruby2d_ext_window_cursor_visible(RUBY2D_METHOD_ARGS_VARIADIC);
R_VAL ruby2d_ext_window_set_system_cursor(RUBY2D_METHOD_ARGS_VARIADIC);
R_VAL ruby2d_ext_window_close(RUBY2D_METHOD_ARGS_VARIADIC);
R_VAL ruby2d_ext_window_set_render_mode(RUBY2D_METHOD_ARGS_VARIADIC);
R_VAL ruby2d_ext_window_request_render(RUBY2D_METHOD_ARGS_VARIADIC);


#ifdef __cplusplus
}
#endif

#endif /* RUBY2D_H */
