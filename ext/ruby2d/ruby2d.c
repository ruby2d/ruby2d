// ruby2d.c – Native C extension for Ruby and MRuby

// Simple 2D includes
#include <simple2d.h>

// Ruby includes
#if MRUBY
  #include <mruby.h>
  #include <mruby/array.h>
  #include <mruby/string.h>
  #include <mruby/variable.h>
  #include <mruby/numeric.h>
  #include <mruby/data.h>
  #include <mruby/irep.h>
#else
  #include <ruby.h>
#endif

// Define Ruby type conversions in MRuby
#if MRUBY
  // C to MRuby types
  #define INT2FIX(val)   (mrb_fixnum_value(val))
  #define INT2NUM(val)   (mrb_fixnum_value((mrb_int)(val)))
  #define UINT2NUM(val)  (INT2NUM((unsigned mrb_int)(val)))
  #define LL2NUM(val)    (INT2NUM(val))
  #define ULL2NUM(val)   (INT2NUM((unsigned __int64)(val)))
  #define DBL2NUM(val)   (mrb_float_value(mrb, (mrb_float)(val)))
  // MRuby to C types
  #define TO_PDT(val)    ((mrb_type(val) == MRB_TT_FLOAT) ? mrb_float(val) : mrb_int(mrb, (val)))
  #define FIX2INT(val)   (mrb_fixnum(val))
  #define NUM2INT(val)   ((mrb_int)TO_PDT(val))
  #define NUM2UINT(val)  ((unsigned mrb_int)TO_PDT(val))
  #define NUM2LONG(val)  (mrb_int(mrb, (val)))
  #define NUM2LL(val)    ((__int64)(TO_PDT(val)))
  #define NUM2ULL(val)   ((unsigned __int64)(TO_PDT(val)))
  #define NUM2DBL(val)   (mrb_to_flo(mrb, (val)))
  #define NUM2CHR(val)   ((mrb_string_p(val) && (RSTRING_LEN(val)>=1)) ? RSTRING_PTR(val)[0] : (char)(NUM2INT(val) & 0xff))
  // Memory management
  #define ALLOC(type)        ((type *)mrb_malloc(mrb, sizeof(type)))
  #define ALLOC_N(type, n)   ((type *)mrb_malloc(mrb, sizeof(type) * (n)))
  #define ALLOCA_N(type, n)  ((type *)alloca(sizeof(type) * (n)))
  #define MEMCMP(p1, p2, type, n)  (memcmp((p1), (p2), sizeof(type)*(n)))
#endif

// Define common types and API calls, mapping to both Ruby and MRuby APIs
#if MRUBY
  // MRuby
  #define RVAL  mrb_value
  #define RNIL  (mrb_nil_value())
  #define RTRUE  (mrb_true_value())
  #define RFALSE  (mrb_false_value())
  #define r_iv_get(self, var)  mrb_iv_get(mrb, self, mrb_intern_lit(mrb, var))
  #define r_iv_set(self, var, val)  mrb_iv_set(mrb, self, mrb_intern_lit(mrb, var), val)
  #define r_funcall(self, method, num_args, ...)  mrb_funcall(mrb, self, method, num_args, ##__VA_ARGS__)
  #define r_str_new(str)  mrb_str_new(mrb, str, strlen(str))
  #define r_test(val)  (mrb_test(val) == true)
  #define r_ary_entry(ary, pos)  mrb_ary_entry(ary, pos)
  #define r_data_wrap_struct(name, data)  mrb_obj_value(Data_Wrap_Struct(mrb, mrb->object_class, &name##_data_type, data))
  #define r_data_get_struct(self, var, mrb_type, rb_type, data)  Data_Get_Struct(mrb, r_iv_get(self, var), mrb_type, data)
#else
  // Ruby
  #define RVAL  VALUE
  #define RNIL  Qnil
  #define RTRUE  Qtrue
  #define RFALSE  Qfalse
  #define r_iv_get(self, var)  rb_iv_get(self, var)
  #define r_iv_set(self, var, val)  rb_iv_set(self, var, val)
  #define r_funcall(self, method, num_args, ...)  rb_funcall(self, rb_intern(method), num_args, ##__VA_ARGS__)
  #define r_str_new(str)  rb_str_new2(str)
  #define r_test(val)  (val != Qfalse && val != Qnil)
  #define r_ary_entry(ary, pos)  rb_ary_entry(ary, pos)
  #define r_data_wrap_struct(name, data)  Data_Wrap_Struct(rb_cObject, NULL, (free_##name), data)
  #define r_data_get_struct(self, var, mrb_type, rb_type, data)  Data_Get_Struct(r_iv_get(self, var), rb_type, data)
#endif

// @type_id values for rendering
#define R2D_TRIANGLE 1
#define R2D_QUAD     2
#define R2D_IMAGE    3
#define R2D_SPRITE   4
#define R2D_TEXT     5

// Create the MRuby context
#if MRUBY
  static mrb_state *mrb;
#endif

// Ruby 2D window
static RVAL self;

// Simple 2D window
static S2D_Window *window;

// Ruby data types
static RVAL ruby2d_module;
static RVAL ruby2d_window_class;

#if MRUBY
  #define ruby2d_show(self)  ruby2d_show(mrb_state* mrb, self)
#else
  #define ruby2d_show(self)  ruby2d_show(self)
#endif


// Method signatures and structures for Ruby 2D classes
#if MRUBY
  static void free_image(mrb_state *mrb, void *p_);
  static const struct mrb_data_type image_data_type = {
    "image", free_image
  };
  static void free_sprite(mrb_state *mrb, void *p_);
  static const struct mrb_data_type sprite_data_type = {
    "sprite", free_sprite
  };
  static void free_text(mrb_state *mrb, void *p_);
  static const struct mrb_data_type text_data_type = {
    "text", free_text
  };
#else
  static void free_image(S2D_Image *img);
  static void free_sprite(S2D_Sprite *spr);
  static void free_text(S2D_Text *txt);
#endif


/*
 * Function pointer to free the Simple 2D window
 */
static void free_window() {
  S2D_FreeWindow(window);
}


/*
* Initialize image structure data
*/
static RVAL init_image(char *path) {
  sprintf(S2D_msg, "init image: %s", path);
  S2D_Log(S2D_msg, S2D_INFO);
  S2D_Image *img = S2D_CreateImage(path);
  return r_data_wrap_struct(image, img);
}


/*
 * Free image structure attached to Ruby 2D `Image` class
 */
#if MRUBY
static void free_image(mrb_state *mrb, void *p_) {
  S2D_Image *img = (S2D_Image *)p_;
#else
static void free_image(S2D_Image *img) {
#endif
  sprintf(S2D_msg, "free image: %i, %i", img->x, img->y);
  S2D_Log(S2D_msg, S2D_INFO);
  S2D_FreeImage(img);
}


/*
 * Initialize sprite structure data
 */
static RVAL init_sprite(char *path) {
  sprintf(S2D_msg, "init sprite: %s", path);
  S2D_Log(S2D_msg, S2D_INFO);
  S2D_Sprite *spr = S2D_CreateSprite(path);
  return r_data_wrap_struct(sprite, spr);
}


/*
 * Free sprite structure attached to Ruby 2D `Sprite` class
 */
#if MRUBY
static void free_sprite(mrb_state *mrb, void *p_) {
  S2D_Sprite *spr = (S2D_Sprite *)p_;
#else
static void free_sprite(S2D_Sprite *spr) {
#endif
  sprintf(S2D_msg, "free sprite: %i, %i", spr->x, spr->y);
  S2D_Log(S2D_msg, S2D_INFO);
  S2D_FreeSprite(spr);
}


/*
 * Initialize text structure data
 */
static RVAL init_text(char *font, char *msg, int size) {
  sprintf(S2D_msg, "init text: %s", msg);
  S2D_Log(S2D_msg, S2D_INFO);
  S2D_Text *txt = S2D_CreateText(font, msg, size);
  return r_data_wrap_struct(text, txt);
}


/*
 * Free text structure attached to Ruby 2D `Text` class
 */
#if MRUBY
static void free_text(mrb_state *mrb, void *p_) {
  S2D_Text *txt = (S2D_Text *)p_;
#else
static void free_text(S2D_Text *txt) {
#endif
  sprintf(S2D_msg, "free text: %s", txt->msg);
  S2D_Log(S2D_msg, S2D_INFO);
  S2D_FreeText(txt);
}


/*
 * Simple 2D `on_key` input callback function
 */
static void on_key(S2D_Event e, const char *key) {
  switch (e) {
    case S2D_KEYDOWN:
      r_funcall(self, "key_down_callback", 1, r_str_new(key));
      break;
    
    case S2D_KEY:
      r_funcall(self, "key_callback", 1, r_str_new(key));
      break;
    
    case S2D_KEYUP:
      r_funcall(self, "key_up_callback", 1, r_str_new(key));
      break;
  }
}


/*
 * Simple 2D `on_mouse` input callback function
 */
void on_mouse(int x, int y) {
  printf("Mouse down at: %i, %i\n", x, y);
}


/*
 * Simple 2D `on_controller` input callback function
 */
static void on_controller(int which, bool is_axis, int axis, int val, bool is_btn, int btn, bool pressed) {
  r_funcall(self, "controller_callback", 6,
    INT2NUM(which),
    is_axis ? RTRUE : RFALSE, INT2NUM(axis), INT2NUM(val),
    is_btn  ? RTRUE : RFALSE, INT2NUM(btn)
  );
}


/*
 * Simple 2D `update` callback function
 */
static void update() {
  
  // Set the cursor
  r_iv_set(self, "@mouse_x", INT2NUM(window->mouse.x));
  r_iv_set(self, "@mouse_y", INT2NUM(window->mouse.y));
  
  // Store frame rate
  r_iv_set(self, "@fps", DBL2NUM(window->fps));
  
  // Call update proc, `window.update`
  r_funcall(self, "update_callback", 0);
}


/*
 * Simple 2D `render` callback function
 */
static void render() {
  
  // Set background color
  RVAL bc = r_iv_get(self, "@background");
  window->background.r = NUM2DBL(r_iv_get(bc, "@r"));
  window->background.g = NUM2DBL(r_iv_get(bc, "@g"));
  window->background.b = NUM2DBL(r_iv_get(bc, "@b"));
  window->background.a = NUM2DBL(r_iv_get(bc, "@a"));
  
  // Read window objects
  RVAL objects = r_iv_get(self, "@objects");
  int num_objects = NUM2INT(r_funcall(objects, "length", 0));
  
  // Switch on each object type
  for (int i = 0; i < num_objects; ++i) {
    
    RVAL el = r_ary_entry(objects, i);
    int type_id = NUM2INT(r_iv_get(el, "@type_id"));
    
    // Switch on the object's type_id
    switch(type_id) {
      
      case R2D_TRIANGLE: {
        RVAL c1 = r_iv_get(el, "@c1");
        RVAL c2 = r_iv_get(el, "@c2");
        RVAL c3 = r_iv_get(el, "@c3");
        
        S2D_DrawTriangle(
          NUM2DBL(r_iv_get(el, "@x1")),
          NUM2DBL(r_iv_get(el, "@y1")),
          NUM2DBL(r_iv_get(c1, "@r")),
          NUM2DBL(r_iv_get(c1, "@g")),
          NUM2DBL(r_iv_get(c1, "@b")),
          NUM2DBL(r_iv_get(c1, "@a")),
          
          NUM2DBL(r_iv_get(el, "@x2")),
          NUM2DBL(r_iv_get(el, "@y2")),
          NUM2DBL(r_iv_get(c2, "@r")),
          NUM2DBL(r_iv_get(c2, "@g")),
          NUM2DBL(r_iv_get(c2, "@b")),
          NUM2DBL(r_iv_get(c2, "@a")),
          
          NUM2DBL(r_iv_get(el, "@x3")),
          NUM2DBL(r_iv_get(el, "@y3")),
          NUM2DBL(r_iv_get(c3, "@r")),
          NUM2DBL(r_iv_get(c3, "@g")),
          NUM2DBL(r_iv_get(c3, "@b")),
          NUM2DBL(r_iv_get(c3, "@a"))
        );
      }
      break;
      
      case R2D_QUAD: {
        RVAL c1 = r_iv_get(el, "@c1");
        RVAL c2 = r_iv_get(el, "@c2");
        RVAL c3 = r_iv_get(el, "@c3");
        RVAL c4 = r_iv_get(el, "@c4");
        
        S2D_DrawQuad(
          NUM2DBL(r_iv_get(el, "@x1")),
          NUM2DBL(r_iv_get(el, "@y1")),
          NUM2DBL(r_iv_get(c1, "@r")),
          NUM2DBL(r_iv_get(c1, "@g")),
          NUM2DBL(r_iv_get(c1, "@b")),
          NUM2DBL(r_iv_get(c1, "@a")),
          
          NUM2DBL(r_iv_get(el, "@x2")),
          NUM2DBL(r_iv_get(el, "@y2")),
          NUM2DBL(r_iv_get(c2, "@r")),
          NUM2DBL(r_iv_get(c2, "@g")),
          NUM2DBL(r_iv_get(c2, "@b")),
          NUM2DBL(r_iv_get(c2, "@a")),
          
          NUM2DBL(r_iv_get(el, "@x3")),
          NUM2DBL(r_iv_get(el, "@y3")),
          NUM2DBL(r_iv_get(c3, "@r")),
          NUM2DBL(r_iv_get(c3, "@g")),
          NUM2DBL(r_iv_get(c3, "@b")),
          NUM2DBL(r_iv_get(c3, "@a")),
          
          NUM2DBL(r_iv_get(el, "@x4")),
          NUM2DBL(r_iv_get(el, "@y4")),
          NUM2DBL(r_iv_get(c4, "@r")),
          NUM2DBL(r_iv_get(c4, "@g")),
          NUM2DBL(r_iv_get(c4, "@b")),
          NUM2DBL(r_iv_get(c4, "@a"))
        );
      }
      break;
      
      case R2D_IMAGE: {
        if (!r_test(r_iv_get(el, "@data"))) {
          r_iv_set(el, "@data", init_image(RSTRING_PTR(r_iv_get(el, "@path"))));
        }
        
        S2D_Image *img;
        r_data_get_struct(el, "@data", &image_data_type, S2D_Image, img);
        
        img->x = NUM2DBL(r_iv_get(el, "@x"));
        img->y = NUM2DBL(r_iv_get(el, "@y"));
        
        RVAL w = r_iv_get(el, "@width");
        RVAL h = r_iv_get(el, "@height");
        if (r_test(w)) img->width  = NUM2INT(w);
        if (r_test(h)) img->height = NUM2INT(h);
        
        S2D_DrawImage(img);
      }
      break;
      
      case R2D_SPRITE: {
        if (!r_test(r_iv_get(el, "@data"))) {
          r_iv_set(el, "@data", init_sprite(RSTRING_PTR(r_iv_get(el, "@path"))));
        }
        
        S2D_Sprite *spr;
        r_data_get_struct(el, "@data", &sprite_data_type, S2D_Sprite, spr);
        
        spr->x = NUM2DBL(r_iv_get(el, "@x"));
        spr->y = NUM2DBL(r_iv_get(el, "@y"));
        
        S2D_ClipSprite(
          spr,
          NUM2INT(r_iv_get(el, "@clip_x")),
          NUM2INT(r_iv_get(el, "@clip_y")),
          NUM2INT(r_iv_get(el, "@clip_w")),
          NUM2INT(r_iv_get(el, "@clip_h"))
        );
        
        S2D_DrawSprite(spr);
      }
      break;
      
      case R2D_TEXT: {
        if (!r_test(r_iv_get(el, "@data"))) {
          r_iv_set(el, "@data", init_text(
            RSTRING_PTR(r_iv_get(el, "@font")),
            RSTRING_PTR(r_iv_get(el, "@text")),
            NUM2DBL(r_iv_get(el, "@size"))
          ));
        }
        
        S2D_Text *txt;
        r_data_get_struct(el, "@data", &text_data_type, S2D_Text, txt);
        
        txt->x = NUM2DBL(r_iv_get(el, "@x"));
        txt->y = NUM2DBL(r_iv_get(el, "@y"));
        
        S2D_SetText(txt, RSTRING_PTR(r_iv_get(el, "@text")));
        S2D_DrawText(txt);
      }
      break;
    }
  }
}


/*
 * Ruby2D::Window#show
 */
static RVAL ruby2d_show(RVAL s) {
  self = s;
  
  if (r_test(r_iv_get(self, "@diagnostics"))) {
    S2D_Diagnostics(true);
  }
  
  // Get window attributes
  char *title = RSTRING_PTR(r_iv_get(self, "@title"));
  int width   = NUM2INT(r_iv_get(self, "@width"));
  int height  = NUM2INT(r_iv_get(self, "@height"));
  int flags   = 0;
  
  // Get window flags
  if (r_test(r_iv_get(self, "@resizable"))) {
    flags = flags | S2D_RESIZABLE;
  }
  if (r_test(r_iv_get(self, "@borderless"))) {
    flags = flags | S2D_BORDERLESS;
  }
  if (r_test(r_iv_get(self, "@fullscreen"))) {
    flags = flags | S2D_FULLSCREEN;
  }
  if (r_test(r_iv_get(self, "@highdpi"))) {
    flags = flags | S2D_HIGHDPI;
  }
  
  // Check viewport size and set
  
  int viewport_width;
  RVAL vp_w = r_iv_get(self, "@viewport_width");
  if (r_test(vp_w)) {
    viewport_width = NUM2INT(vp_w);
  } else {
    viewport_width = width;
  }
  
  int viewport_height;
  RVAL vp_h = r_iv_get(self, "@viewport_height");
  if (r_test(vp_h)) {
    viewport_height = NUM2INT(vp_h);
  } else {
    viewport_height = height;
  }
  
  window = S2D_CreateWindow(
    title, width, height, update, render, flags
  );
  
  window->viewport.width  = viewport_width;
  window->viewport.height = viewport_height;
  window->on_key          = on_key;
  window->on_mouse        = on_mouse;
  window->on_controller   = on_controller;
  
  S2D_Show(window);
  
  atexit(free_window);
  return RNIL;
}


/*
 * Ruby2D::Window#close
 */
static RVAL ruby2d_close() {
  S2D_Close(window);
  return RNIL;
}


/*
* MRuby entry point
*/
#if MRUBY
int main(void) {
  
  // Open the MRuby environment
  mrb = mrb_open();
  if (!mrb) { /* handle error */ }
  
  // Load the Ruby 2D library
  mrb_load_irep(mrb, ruby2d_lib);
  
  // Ruby2D
  struct RClass *ruby2d_module = mrb_module_get(mrb, "Ruby2D");
  
  // Ruby2D::Window
  struct RClass *ruby2d_window_class = mrb_class_get_under(mrb, ruby2d_module, "Window");
  
  // Ruby2D::Window#show
  mrb_define_method(mrb, ruby2d_window_class, "show", ruby2d_show, MRB_ARGS_NONE());
  
  // Ruby2D::Window#close
  mrb_define_method(mrb, ruby2d_window_class, "close", ruby2d_close, MRB_ARGS_NONE());
  
  // Load the Ruby 2D app
  mrb_load_irep(mrb, ruby2d_app);
  
  // Close the MRuby environment
  mrb_close(mrb);
}


/*
* Ruby C extension init
*/
#else
void Init_ruby2d() {
  
  // Ruby2D
  ruby2d_module = rb_define_module("Ruby2D");
  
  // Ruby2D::Window
  ruby2d_window_class = rb_define_class_under(ruby2d_module, "Window", rb_cObject);
  
  // Ruby2D::Window#show
  rb_define_method(ruby2d_window_class, "show", ruby2d_show, 0);
  
  // Ruby2D::Window#close
  rb_define_method(ruby2d_window_class, "close", ruby2d_close, 0);
}
#endif
