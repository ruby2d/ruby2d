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
  #define R_VAL  mrb_value
  #define R_NIL  (mrb_nil_value())
  #define R_TRUE  (mrb_true_value())
  #define R_FALSE  (mrb_false_value())
  #define R_CLASS  struct RClass *
  #define r_iv_get(self, var)  mrb_iv_get(mrb, self, mrb_intern_lit(mrb, var))
  #define r_iv_set(self, var, val)  mrb_iv_set(mrb, self, mrb_intern_lit(mrb, var), val)
  #define r_funcall(self, method, num_args, ...)  mrb_funcall(mrb, self, method, num_args, ##__VA_ARGS__)
  #define r_str_new(str)  mrb_str_new(mrb, str, strlen(str))
  #define r_test(val)  (mrb_test(val) == true)
  #define r_ary_entry(ary, pos)  mrb_ary_entry(ary, pos)
  #define r_data_wrap_struct(name, data)  mrb_obj_value(Data_Wrap_Struct(mrb, mrb->object_class, &name##_data_type, data))
  #define r_data_get_struct(self, var, mrb_type, rb_type, data)  Data_Get_Struct(mrb, r_iv_get(self, var), mrb_type, data)
  #define r_define_module(name)  mrb_module_get(mrb, name)
  #define r_define_class(module, name)  mrb_class_get_under(mrb, module, name);
  #define r_define_method(class, name, function, args)  mrb_define_method(mrb, class, name, function, args)
  #define r_args_none  (MRB_ARGS_NONE())
  #define r_args_req(n)  MRB_ARGS_REQ(n)
#else
  // Ruby
  #define R_VAL  VALUE
  #define R_NIL  Qnil
  #define R_TRUE  Qtrue
  #define R_FALSE  Qfalse
  #define R_CLASS  R_VAL
  #define r_iv_get(self, var)  rb_iv_get(self, var)
  #define r_iv_set(self, var, val)  rb_iv_set(self, var, val)
  #define r_funcall(self, method, num_args, ...)  rb_funcall(self, rb_intern(method), num_args, ##__VA_ARGS__)
  #define r_str_new(str)  rb_str_new2(str)
  #define r_test(val)  (val != Qfalse && val != Qnil)
  #define r_ary_entry(ary, pos)  rb_ary_entry(ary, pos)
  #define r_data_wrap_struct(name, data)  Data_Wrap_Struct(rb_cObject, NULL, (free_##name), data)
  #define r_data_get_struct(self, var, mrb_type, rb_type, data)  Data_Get_Struct(r_iv_get(self, var), rb_type, data)
  #define r_define_module(name)  rb_define_module(name)
  #define r_define_class(module, name)  rb_define_class_under(module, name, rb_cObject);
  #define r_define_method(class, name, function, args)  rb_define_method(class, name, function, args)
  #define r_args_none  0
  #define r_args_req(n)  n
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
static R_VAL ruby2d_window;

// Simple 2D window
static S2D_Window *window;


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
  static void free_sound(mrb_state *mrb, void *p_);
  static const struct mrb_data_type sound_data_type = {
    "sound", free_sound
  };
  static void free_music(mrb_state *mrb, void *p_);
  static const struct mrb_data_type music_data_type = {
    "music", free_music
  };
#else
  static void free_image(S2D_Image *img);
  static void free_sprite(S2D_Sprite *spr);
  static void free_text(S2D_Text *txt);
  static void free_sound(S2D_Sound *snd);
  static void free_music(S2D_Music *mus);
#endif


/*
 * Function pointer to free the Simple 2D window
 */
static void free_window() {
  S2D_FreeWindow(window);
}


/*
 * Ruby2D::Image#init
 * Initialize image structure data
 */
#if MRUBY
static R_VAL ruby2d_image_init(mrb_state* mrb, R_VAL self) {
  mrb_value path;
  mrb_get_args(mrb, "o", &path);
#else
static R_VAL ruby2d_image_init(R_VAL self, R_VAL path) {
#endif
  sprintf(S2D_msg, "Init image: %s", RSTRING_PTR(path));
  S2D_Log(S2D_msg, S2D_INFO);
  S2D_Image *img = S2D_CreateImage(RSTRING_PTR(path));
  r_iv_set(self, "@data", r_data_wrap_struct(image, img));
  return R_NIL;
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
  sprintf(S2D_msg, "Free image: %i, %i", img->x, img->y);
  S2D_Log(S2D_msg, S2D_INFO);
  S2D_FreeImage(img);
}


/*
 * Ruby2D::Sprite#init
 * Initialize sprite structure data
 */
#if MRUBY
static R_VAL ruby2d_sprite_init(mrb_state* mrb, R_VAL self) {
  mrb_value path;
  mrb_get_args(mrb, "o", &path);
#else
static R_VAL ruby2d_sprite_init(R_VAL self, R_VAL path) {
#endif
  sprintf(S2D_msg, "Init sprite: %s", RSTRING_PTR(path));
  S2D_Log(S2D_msg, S2D_INFO);
  S2D_Sprite *spr = S2D_CreateSprite(RSTRING_PTR(path));
  r_iv_set(self, "@data", r_data_wrap_struct(sprite, spr));
  return R_NIL;
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
  sprintf(S2D_msg, "Free sprite: %i, %i", spr->x, spr->y);
  S2D_Log(S2D_msg, S2D_INFO);
  S2D_FreeSprite(spr);
}


/*
 * Ruby2D::Text#init
 * Initialize text structure data
 */
#if MRUBY
static R_VAL ruby2d_text_init(mrb_state* mrb, R_VAL self) {
#else
static R_VAL ruby2d_text_init(R_VAL self) {
#endif
  sprintf(S2D_msg, "Init text: %s", RSTRING_PTR(r_iv_get(self, "@text")));
  S2D_Log(S2D_msg, S2D_INFO);
  
  S2D_Text *txt = S2D_CreateText(
    RSTRING_PTR(r_iv_get(self, "@font")),
    RSTRING_PTR(r_iv_get(self, "@text")),
    NUM2DBL(r_iv_get(self, "@size"))
  );
  
  r_iv_set(self, "@width", INT2NUM(txt->width));
  r_iv_set(self, "@height", INT2NUM(txt->height));
  
  r_iv_set(self, "@data", r_data_wrap_struct(text, txt));
  return R_NIL;
}


/*
 * Ruby2D::Text#ext_text_set
 */
#if MRUBY
static R_VAL ruby2d_ext_text_set(mrb_state* mrb, R_VAL self) {
  mrb_value text;
  mrb_get_args(mrb, "o", &text);
#else
static R_VAL ruby2d_ext_text_set(R_VAL self, R_VAL text) {
#endif
  S2D_Text *txt;
  r_data_get_struct(self, "@data", &text_data_type, S2D_Text, txt);
  
  S2D_SetText(txt, RSTRING_PTR(text));
  
  r_iv_set(self, "@width", INT2NUM(txt->width));
  r_iv_set(self, "@height", INT2NUM(txt->height));
  
  return R_NIL;
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
  sprintf(S2D_msg, "Free text: %s", txt->msg);
  S2D_Log(S2D_msg, S2D_INFO);
  S2D_FreeText(txt);
}


/*
 * Ruby2D::Sound#init
 * Initialize sound structure data
 */
#if MRUBY
static R_VAL ruby2d_sound_init(mrb_state* mrb, R_VAL self) {
  mrb_value path;
  mrb_get_args(mrb, "o", &path);
#else
static R_VAL ruby2d_sound_init(R_VAL self, R_VAL path) {
#endif
  sprintf(S2D_msg, "Init sound: %s", RSTRING_PTR(path));
  S2D_Log(S2D_msg, S2D_INFO);
  S2D_Sound *snd = S2D_CreateSound(RSTRING_PTR(path));
  r_iv_set(self, "@data", r_data_wrap_struct(sound, snd));
  return R_NIL;
}


/*
 * Ruby2D::Sound#play
 */
#if MRUBY
static R_VAL ruby2d_sound_play(mrb_state* mrb, R_VAL self) {
#else
static R_VAL ruby2d_sound_play(R_VAL self) {
#endif
  S2D_Sound *snd;
  r_data_get_struct(self, "@data", &sound_data_type, S2D_Sound, snd);
  S2D_PlaySound(snd);
  return R_NIL;
}


/*
 * Free sound structure attached to Ruby 2D `Sound` class
 */
#if MRUBY
static void free_sound(mrb_state *mrb, void *p_) {
  S2D_Sound *snd = (S2D_Sound *)p_;
#else
static void free_sound(S2D_Sound *snd) {
#endif
  sprintf(S2D_msg, "Free sound");
  S2D_Log(S2D_msg, S2D_INFO);
  S2D_FreeSound(snd);
}


/*
 * Ruby2D::Music#init
 * Initialize music structure data
 */
#if MRUBY
static R_VAL ruby2d_music_init(mrb_state* mrb, R_VAL self) {
  mrb_value path;
  mrb_get_args(mrb, "o", &path);
#else
static R_VAL ruby2d_music_init(R_VAL self, R_VAL path) {
#endif
  sprintf(S2D_msg, "Init music: %s", RSTRING_PTR(path));
  S2D_Log(S2D_msg, S2D_INFO);
  S2D_Music *mus = S2D_CreateMusic(RSTRING_PTR(path));
  r_iv_set(self, "@data", r_data_wrap_struct(music, mus));
  return R_NIL;
}


/*
 * Ruby2D::Music#play
 */
#if MRUBY
static R_VAL ruby2d_music_play(mrb_state* mrb, R_VAL self) {
#else
static R_VAL ruby2d_music_play(R_VAL self) {
#endif
  S2D_Music *mus;
  r_data_get_struct(self, "@data", &music_data_type, S2D_Music, mus);
  S2D_PlayMusic(mus, r_test(r_iv_get(self, "@loop")));
  return R_NIL;
}


/*
 * Ruby2D::Music#pause
 */
#if MRUBY
static R_VAL ruby2d_music_pause(mrb_state* mrb, R_VAL self) {
#else
static R_VAL ruby2d_music_pause(R_VAL self) {
#endif
  S2D_PauseMusic();
  return R_NIL;
}


/*
 * Ruby2D::Music#resume
 */
#if MRUBY
static R_VAL ruby2d_music_resume(mrb_state* mrb, R_VAL self) {
#else
static R_VAL ruby2d_music_resume(R_VAL self) {
#endif
  S2D_ResumeMusic();
  return R_NIL;
}


/*
 * Ruby2D::Music#stop
 */
#if MRUBY
static R_VAL ruby2d_music_stop(mrb_state* mrb, R_VAL self) {
#else
static R_VAL ruby2d_music_stop(R_VAL self) {
#endif
  S2D_StopMusic();
  return R_NIL;
}


/*
 * Ruby2D::Music#fadeout
 */
#if MRUBY
static R_VAL ruby2d_music_fadeout(mrb_state* mrb, R_VAL self) {
  mrb_value ms;
  mrb_get_args(mrb, "o", &ms);
#else
static R_VAL ruby2d_music_fadeout(R_VAL self, R_VAL ms) {
#endif
  S2D_FadeOutMusic(NUM2INT(ms));
  return R_NIL;
}


/*
 * Free sound structure attached to Ruby 2D `Sound` class
 */
#if MRUBY
static void free_music(mrb_state *mrb, void *p_) {
  S2D_Music *mus = (S2D_Music *)p_;
#else
static void free_music(S2D_Music *mus) {
#endif
  sprintf(S2D_msg, "Free music");
  S2D_Log(S2D_msg, S2D_INFO);
  S2D_FreeMusic(mus);
}


/*
 * Simple 2D `on_key` input callback function
 */
static void on_key(S2D_Event e, const char *key) {
  switch (e) {
    case S2D_KEYDOWN:
      r_funcall(ruby2d_window, "key_down_callback", 1, r_str_new(key));
      break;
    
    case S2D_KEY:
      r_funcall(ruby2d_window, "key_callback", 1, r_str_new(key));
      break;
    
    case S2D_KEYUP:
      r_funcall(ruby2d_window, "key_up_callback", 1, r_str_new(key));
      break;
  }
}


/*
 * Simple 2D `on_mouse` input callback function
 */
void on_mouse(int x, int y) {
  r_funcall(ruby2d_window, "mouse_callback", 3, r_str_new("any"), INT2NUM(x), INT2NUM(y));
}


/*
 * Simple 2D `on_controller` input callback function
 */
static void on_controller(int which, bool is_axis, int axis, int val, bool is_btn, int btn, bool pressed) {
  r_funcall(ruby2d_window, "controller_callback", 7,
    INT2NUM(which),
    is_axis ? R_TRUE : R_FALSE, INT2NUM(axis), INT2NUM(val),
    is_btn  ? R_TRUE : R_FALSE, INT2NUM(btn), pressed ? R_TRUE : R_FALSE
  );
}


/*
 * Simple 2D `update` callback function
 */
static void update() {
  
  // Set the cursor
  r_iv_set(ruby2d_window, "@mouse_x", INT2NUM(window->mouse.x));
  r_iv_set(ruby2d_window, "@mouse_y", INT2NUM(window->mouse.y));
  
  // Store frames
  r_iv_set(ruby2d_window, "@frames", DBL2NUM(window->frames));
  
  // Store frame rate
  r_iv_set(ruby2d_window, "@fps", DBL2NUM(window->fps));
  
  // Call update proc, `window.update`
  r_funcall(ruby2d_window, "update_callback", 0);
}


/*
 * Simple 2D `render` callback function
 */
static void render() {
  
  // Set background color
  R_VAL bc = r_iv_get(ruby2d_window, "@background");
  window->background.r = NUM2DBL(r_iv_get(bc, "@r"));
  window->background.g = NUM2DBL(r_iv_get(bc, "@g"));
  window->background.b = NUM2DBL(r_iv_get(bc, "@b"));
  window->background.a = NUM2DBL(r_iv_get(bc, "@a"));
  
  // Read window objects
  R_VAL objects = r_iv_get(ruby2d_window, "@objects");
  int num_objects = NUM2INT(r_funcall(objects, "length", 0));
  
  // Switch on each object type
  for (int i = 0; i < num_objects; ++i) {
    
    R_VAL el = r_ary_entry(objects, i);
    int type_id = NUM2INT(r_iv_get(el, "@type_id"));
    
    // Switch on the object's type_id
    switch(type_id) {
      
      case R2D_TRIANGLE: {
        R_VAL c1 = r_iv_get(el, "@c1");
        R_VAL c2 = r_iv_get(el, "@c2");
        R_VAL c3 = r_iv_get(el, "@c3");
        
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
        R_VAL c1 = r_iv_get(el, "@c1");
        R_VAL c2 = r_iv_get(el, "@c2");
        R_VAL c3 = r_iv_get(el, "@c3");
        R_VAL c4 = r_iv_get(el, "@c4");
        
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
        S2D_Image *img;
        r_data_get_struct(el, "@data", &image_data_type, S2D_Image, img);
        
        img->x = NUM2DBL(r_iv_get(el, "@x"));
        img->y = NUM2DBL(r_iv_get(el, "@y"));
        
        R_VAL w = r_iv_get(el, "@width");
        R_VAL h = r_iv_get(el, "@height");
        if (r_test(w)) img->width  = NUM2INT(w);
        if (r_test(h)) img->height = NUM2INT(h);
        
        R_VAL c = r_iv_get(el, "@color");
        img->color.r = NUM2DBL(r_iv_get(c, "@r"));
        img->color.g = NUM2DBL(r_iv_get(c, "@g"));
        img->color.b = NUM2DBL(r_iv_get(c, "@b"));
        img->color.a = NUM2DBL(r_iv_get(c, "@a"));
        
        S2D_DrawImage(img);
      }
      break;
      
      case R2D_SPRITE: {
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
        S2D_Text *txt;
        r_data_get_struct(el, "@data", &text_data_type, S2D_Text, txt);
        
        txt->x = NUM2DBL(r_iv_get(el, "@x"));
        txt->y = NUM2DBL(r_iv_get(el, "@y"));
        
        R_VAL c = r_iv_get(el, "@color");
        txt->color.r = NUM2DBL(r_iv_get(c, "@r"));
        txt->color.g = NUM2DBL(r_iv_get(c, "@g"));
        txt->color.b = NUM2DBL(r_iv_get(c, "@b"));
        txt->color.a = NUM2DBL(r_iv_get(c, "@a"));
        
        S2D_DrawText(txt);
      }
      break;
    }
  }
}


/*
 * Ruby2D::Window#show
 */
#if MRUBY
static R_VAL ruby2d_show(mrb_state* mrb, R_VAL self) {
#else
static R_VAL ruby2d_show(R_VAL self) {
#endif
  ruby2d_window = self;
  
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
  
  R_VAL vp_w = r_iv_get(self, "@viewport_width");
  int viewport_width = r_test(vp_w) ? NUM2INT(vp_w) : width;
  
  R_VAL vp_h = r_iv_get(self, "@viewport_height");
  int viewport_height = r_test(vp_h) ? NUM2INT(vp_h) : height;
  
  // Create and show window
  
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
  return R_NIL;
}


/*
 * Ruby2D::Window#close
 */
static R_VAL ruby2d_close() {
  S2D_Close(window);
  return R_NIL;
}


#if MRUBY
/*
 * MRuby entry point
 */
int main(void) {
  // Open the MRuby environment
  mrb = mrb_open();
  if (!mrb) { /* handle error */ }
  
  // Load the Ruby 2D library
  mrb_load_irep(mrb, ruby2d_lib);
#else
/*
 * Ruby C extension init
 */
void Init_ruby2d() {
#endif
  
  // Ruby2D
  R_CLASS ruby2d_module = r_define_module("Ruby2D");
  
  // Ruby2D::Image
  R_CLASS ruby2d_image_class = r_define_class(ruby2d_module, "Image");
  
  // Ruby2D::Image#init
  r_define_method(ruby2d_image_class, "init", ruby2d_image_init, r_args_req(1));
  
  // Ruby2D::Sprite
  R_CLASS ruby2d_sprite_class = r_define_class(ruby2d_module, "Sprite");
  
  // Ruby2D::Sprite#init
  r_define_method(ruby2d_sprite_class, "init", ruby2d_sprite_init, r_args_req(1));
  
  // Ruby2D::Text
  R_CLASS ruby2d_text_class = r_define_class(ruby2d_module, "Text");
  
  // Ruby2D::Text#init
  r_define_method(ruby2d_text_class, "init", ruby2d_text_init, r_args_none);
  
  // Ruby2D::Text#ext_text_set
  r_define_method(ruby2d_text_class, "ext_text_set", ruby2d_ext_text_set, r_args_req(1));
  
  // Ruby2D::Sound
  R_CLASS ruby2d_sound_class = r_define_class(ruby2d_module, "Sound");
  
  // Ruby2D::Sound#init
  r_define_method(ruby2d_sound_class, "init", ruby2d_sound_init, r_args_req(1));
  
  // Ruby2D::Sound#play
  r_define_method(ruby2d_sound_class, "play", ruby2d_sound_play, r_args_none);
  
  // Ruby2D::Music
  R_CLASS ruby2d_music_class = r_define_class(ruby2d_module, "Music");
  
  // Ruby2D::Music#init
  r_define_method(ruby2d_music_class, "init", ruby2d_music_init, r_args_req(1));
  
  // Ruby2D::Music#play
  r_define_method(ruby2d_music_class, "play", ruby2d_music_play, r_args_none);
  
  // Ruby2D::Music#pause
  r_define_method(ruby2d_music_class, "pause", ruby2d_music_pause, r_args_none);
  
  // Ruby2D::Music#resume
  r_define_method(ruby2d_music_class, "resume", ruby2d_music_resume, r_args_none);
  
  // Ruby2D::Music#stop
  r_define_method(ruby2d_music_class, "stop", ruby2d_music_stop, r_args_none);
  
  // Ruby2D::Music#fadeout
  r_define_method(ruby2d_music_class, "fadeout", ruby2d_music_fadeout, r_args_req(1));
  
  // Ruby2D::Window
  R_CLASS ruby2d_window_class = r_define_class(ruby2d_module, "Window");
  
  // Ruby2D::Window#show
  r_define_method(ruby2d_window_class, "show", ruby2d_show, r_args_none);
  
  // Ruby2D::Window#close
  r_define_method(ruby2d_window_class, "close", ruby2d_close, r_args_none);
  
#if MRUBY
  // Load the Ruby 2D app
  mrb_load_irep(mrb, ruby2d_app);
  
  // Close the MRuby environment
  mrb_close(mrb);
#endif
}
