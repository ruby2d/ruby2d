// Native C extension for Ruby and MRuby

// Ruby 2D includes
#if RUBY2D_IOS_TVOS
#else
  #include <ruby2d.h>
#endif

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
  #define r_define_module(name)  mrb_define_module(mrb, name)
  #define r_define_class(module, name)  mrb_define_class_under(mrb, module, name, mrb->object_class)
  #define r_define_method(class, name, function, args)  mrb_define_method(mrb, class, name, function, args)
  #define r_define_class_method(class, name, function, args)  mrb_define_class_method(mrb, class, name, function, args)
  #define r_args_none  (MRB_ARGS_NONE())
  #define r_args_req(n)  MRB_ARGS_REQ(n)
  // Helpers
  #define r_char_to_sym(str)  mrb_symbol_value(mrb_intern_cstr(mrb, str))
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
  #define r_define_class(module, name)  rb_define_class_under(module, name, rb_cObject)
  #define r_define_method(class, name, function, args)  rb_define_method(class, name, function, args)
  #define r_define_class_method(class, name, function, args)  rb_define_singleton_method(class, name, function, args)
  #define r_args_none  0
  #define r_args_req(n)  n
  // Helpers
  #define r_char_to_sym(str)  ID2SYM(rb_intern(str))
#endif

// Create the MRuby context
#if MRUBY
  static mrb_state *mrb;
#endif

// Ruby 2D interpreter window
static R_VAL ruby2d_window;

// Ruby 2D native window
static R2D_Window *window;


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
  static void free_image(R2D_Image *img);
  static void free_sprite(R2D_Sprite *spr);
  static void free_text(R2D_Text *txt);
  static void free_sound(R2D_Sound *snd);
  static void free_music(R2D_Music *mus);
#endif


/*
 * Function pointer to free the Ruby 2D native window
 */
static void free_window() {
  R2D_FreeWindow(window);
}


/*
 * Normalize controller axis values to 0.0...1.0
 */
double normalize_controller_axis(int val) {
  return val > 0 ? val / 32767.0 : val / 32768.0;
}


/*
 * Ruby2D#self.ext_base_path
 */
#if MRUBY
static R_VAL ruby2d_ext_base_path(mrb_state* mrb, R_VAL self) {
#else
static R_VAL ruby2d_ext_base_path(R_VAL self) {
#endif
  return r_str_new(SDL_GetBasePath());
}


/*
 * Ruby2D::Pixel#self.ext_draw
 */
#if MRUBY
static R_VAL ruby2d_pixel_ext_draw(mrb_state* mrb, R_VAL self) {
  mrb_value a;
  mrb_get_args(mrb, "o", &a);
#else
static R_VAL ruby2d_pixel_ext_draw(R_VAL self, R_VAL a) {
#endif
  // `a` is the array representing the pixel

  R2D_DrawQuad(
    NUM2DBL(r_ary_entry(a,  0)),  // x1
    NUM2DBL(r_ary_entry(a,  1)),  // y1
    NUM2DBL(r_ary_entry(a,  8)),  // color
    NUM2DBL(r_ary_entry(a,  9)),  // color
    NUM2DBL(r_ary_entry(a, 10)),  // color
    NUM2DBL(r_ary_entry(a, 11)),  // color

    NUM2DBL(r_ary_entry(a,  2)),  // x2
    NUM2DBL(r_ary_entry(a,  3)),  // y2
    NUM2DBL(r_ary_entry(a,  8)),  // color
    NUM2DBL(r_ary_entry(a,  9)),  // color
    NUM2DBL(r_ary_entry(a, 10)),  // color
    NUM2DBL(r_ary_entry(a, 11)),  // color

    NUM2DBL(r_ary_entry(a,  4)),  // x3
    NUM2DBL(r_ary_entry(a,  5)),  // y3
    NUM2DBL(r_ary_entry(a,  8)),  // color
    NUM2DBL(r_ary_entry(a,  9)),  // color
    NUM2DBL(r_ary_entry(a, 10)),  // color
    NUM2DBL(r_ary_entry(a, 11)),  // color

    NUM2DBL(r_ary_entry(a,  6)),  // x4
    NUM2DBL(r_ary_entry(a,  7)),  // y4
    NUM2DBL(r_ary_entry(a,  8)),  // color
    NUM2DBL(r_ary_entry(a,  9)),  // color
    NUM2DBL(r_ary_entry(a, 10)),  // color
    NUM2DBL(r_ary_entry(a, 11))   // color
  );

  return R_NIL;
}


/*
 * Ruby2D::Triangle#self.ext_draw
 */
#if MRUBY
static R_VAL ruby2d_triangle_ext_draw(mrb_state* mrb, R_VAL self) {
  mrb_value a;
  mrb_get_args(mrb, "o", &a);
#else
static R_VAL ruby2d_triangle_ext_draw(R_VAL self, R_VAL a) {
#endif
  // `a` is the array representing the triangle

  R2D_DrawTriangle(
    NUM2DBL(r_ary_entry(a,  0)),  // x1
    NUM2DBL(r_ary_entry(a,  1)),  // y1
    NUM2DBL(r_ary_entry(a,  2)),  // c1 red
    NUM2DBL(r_ary_entry(a,  3)),  // c1 green
    NUM2DBL(r_ary_entry(a,  4)),  // c1 blue
    NUM2DBL(r_ary_entry(a,  5)),  // c1 alpha

    NUM2DBL(r_ary_entry(a,  6)),  // x2
    NUM2DBL(r_ary_entry(a,  7)),  // y2
    NUM2DBL(r_ary_entry(a,  8)),  // c2 red
    NUM2DBL(r_ary_entry(a,  9)),  // c2 green
    NUM2DBL(r_ary_entry(a, 10)),  // c2 blue
    NUM2DBL(r_ary_entry(a, 11)),  // c2 alpha

    NUM2DBL(r_ary_entry(a, 12)),  // x3
    NUM2DBL(r_ary_entry(a, 13)),  // y3
    NUM2DBL(r_ary_entry(a, 14)),  // c3 red
    NUM2DBL(r_ary_entry(a, 15)),  // c3 green
    NUM2DBL(r_ary_entry(a, 16)),  // c3 blue
    NUM2DBL(r_ary_entry(a, 17))  // c3 alpha
  );

  return R_NIL;
}


/*
 * Ruby2D::Quad#self.ext_draw
 */
#if MRUBY
static R_VAL ruby2d_quad_ext_draw(mrb_state* mrb, R_VAL self) {
  mrb_value a;
  mrb_get_args(mrb, "o", &a);
#else
static R_VAL ruby2d_quad_ext_draw(R_VAL self, R_VAL a) {
#endif
  // `a` is the array representing the quad

  R2D_DrawQuad(
    NUM2DBL(r_ary_entry(a,  0)),  // x1
    NUM2DBL(r_ary_entry(a,  1)),  // y1
    NUM2DBL(r_ary_entry(a,  2)),  // c1 red
    NUM2DBL(r_ary_entry(a,  3)),  // c1 green
    NUM2DBL(r_ary_entry(a,  4)),  // c1 blue
    NUM2DBL(r_ary_entry(a,  5)),  // c1 alpha

    NUM2DBL(r_ary_entry(a,  6)),  // x2
    NUM2DBL(r_ary_entry(a,  7)),  // y2
    NUM2DBL(r_ary_entry(a,  8)),  // c2 red
    NUM2DBL(r_ary_entry(a,  9)),  // c2 green
    NUM2DBL(r_ary_entry(a, 10)),  // c2 blue
    NUM2DBL(r_ary_entry(a, 11)),  // c2 alpha

    NUM2DBL(r_ary_entry(a, 12)),  // x3
    NUM2DBL(r_ary_entry(a, 13)),  // y3
    NUM2DBL(r_ary_entry(a, 14)),  // c3 red
    NUM2DBL(r_ary_entry(a, 15)),  // c3 green
    NUM2DBL(r_ary_entry(a, 16)),  // c3 blue
    NUM2DBL(r_ary_entry(a, 17)),  // c3 alpha

    NUM2DBL(r_ary_entry(a, 18)),  // x4
    NUM2DBL(r_ary_entry(a, 19)),  // y4
    NUM2DBL(r_ary_entry(a, 20)),  // c4 red
    NUM2DBL(r_ary_entry(a, 21)),  // c4 green
    NUM2DBL(r_ary_entry(a, 22)),  // c4 blue
    NUM2DBL(r_ary_entry(a, 23))   // c4 alpha
  );

  return R_NIL;
}


/*
 * Ruby2D::Line#self.ext_draw
 */
#if MRUBY
static R_VAL ruby2d_line_ext_draw(mrb_state* mrb, R_VAL self) {
  mrb_value a;
  mrb_get_args(mrb, "o", &a);
#else
static R_VAL ruby2d_line_ext_draw(R_VAL self, R_VAL a) {
#endif
  // `a` is the array representing the line

  R2D_DrawLine(
    NUM2DBL(r_ary_entry(a,  0)),  // x1
    NUM2DBL(r_ary_entry(a,  1)),  // y1
    NUM2DBL(r_ary_entry(a,  2)),  // x2
    NUM2DBL(r_ary_entry(a,  3)),  // y2
    NUM2DBL(r_ary_entry(a,  4)),  // width

    NUM2DBL(r_ary_entry(a,  5)),  // c1 red
    NUM2DBL(r_ary_entry(a,  6)),  // c1 green
    NUM2DBL(r_ary_entry(a,  7)),  // c1 blue
    NUM2DBL(r_ary_entry(a,  8)),  // c1 alpha

    NUM2DBL(r_ary_entry(a,  9)),  // c2 red
    NUM2DBL(r_ary_entry(a, 10)),  // c2 green
    NUM2DBL(r_ary_entry(a, 11)),  // c2 blue
    NUM2DBL(r_ary_entry(a, 12)),  // c2 alpha

    NUM2DBL(r_ary_entry(a, 13)),  // c3 red
    NUM2DBL(r_ary_entry(a, 14)),  // c3 green
    NUM2DBL(r_ary_entry(a, 15)),  // c3 blue
    NUM2DBL(r_ary_entry(a, 16)),  // c3 alpha

    NUM2DBL(r_ary_entry(a, 17)),  // c4 red
    NUM2DBL(r_ary_entry(a, 18)),  // c4 green
    NUM2DBL(r_ary_entry(a, 19)),  // c4 blue
    NUM2DBL(r_ary_entry(a, 20))   // c4 alpha
  );

  return R_NIL;
}


/*
 * Ruby2D::Circle#self.ext_draw
 */
#if MRUBY
static R_VAL ruby2d_circle_ext_draw(mrb_state* mrb, R_VAL self) {
  mrb_value a;
  mrb_get_args(mrb, "o", &a);
#else
static R_VAL ruby2d_circle_ext_draw(R_VAL self, R_VAL a) {
#endif
  // `a` is the array representing the circle

  R2D_DrawCircle(
    NUM2DBL(r_ary_entry(a, 0)),  // x
    NUM2DBL(r_ary_entry(a, 1)),  // y
    NUM2DBL(r_ary_entry(a, 2)),  // radius
    NUM2DBL(r_ary_entry(a, 3)),  // sectors
    NUM2DBL(r_ary_entry(a, 4)),  // red
    NUM2DBL(r_ary_entry(a, 5)),  // green
    NUM2DBL(r_ary_entry(a, 6)),  // blue
    NUM2DBL(r_ary_entry(a, 7))   // alpha
  );

  return R_NIL;
}


/*
 * Ruby2D::Image#ext_init
 * Initialize image structure data
 */
#if MRUBY
static R_VAL ruby2d_image_ext_init(mrb_state* mrb, R_VAL self) {
  mrb_value path;
  mrb_get_args(mrb, "o", &path);
#else
static R_VAL ruby2d_image_ext_init(R_VAL self, R_VAL path) {
#endif
  R2D_Image *img = R2D_CreateImage(RSTRING_PTR(path));
  if (!img) return R_FALSE;

  // Get width and height from Ruby class. If set, use it, else choose the
  // native dimensions of the image.
  R_VAL w = r_iv_get(self, "@width");
  R_VAL h = r_iv_get(self, "@height");
  r_iv_set(self, "@width" , r_test(w) ? w : INT2NUM(img->width));
  r_iv_set(self, "@height", r_test(h) ? h : INT2NUM(img->height));
  r_iv_set(self, "@data", r_data_wrap_struct(image, img));

  return R_TRUE;
}


/*
 * Ruby2D::Image#self.ext_draw
 */
#if MRUBY
static R_VAL ruby2d_image_ext_draw(mrb_state* mrb, R_VAL self) {
  mrb_value a;
  mrb_get_args(mrb, "o", &a);
#else
static R_VAL ruby2d_image_ext_draw(R_VAL self, R_VAL a) {
#endif
  // `a` is the array representing the image

  R2D_Image *img;
  r_data_get_struct(r_ary_entry(a, 0), "@data", &image_data_type, R2D_Image, img);

  img->x = NUM2DBL(r_ary_entry(a, 1));
  img->y = NUM2DBL(r_ary_entry(a, 2));

  R_VAL w = r_ary_entry(a, 3);
  R_VAL h = r_ary_entry(a, 4);
  if (r_test(w)) img->width  = NUM2INT(w);
  if (r_test(h)) img->height = NUM2INT(h);

  R2D_RotateImage(img, NUM2DBL(r_ary_entry(a, 5)), R2D_CENTER);

  img->color.r = NUM2DBL(r_ary_entry(a, 6));
  img->color.g = NUM2DBL(r_ary_entry(a, 7));
  img->color.b = NUM2DBL(r_ary_entry(a, 8));
  img->color.a = NUM2DBL(r_ary_entry(a, 9));

  R2D_DrawImage(img);
  return R_NIL;
}


/*
 * Free image structure attached to Ruby 2D `Image` class
 */
#if MRUBY
static void free_image(mrb_state *mrb, void *p_) {
  R2D_Image *img = (R2D_Image *)p_;
#else
static void free_image(R2D_Image *img) {
#endif
  R2D_FreeImage(img);
}


/*
 * Ruby2D::Sprite#ext_init
 * Initialize sprite structure data
 */
#if MRUBY
static R_VAL ruby2d_sprite_ext_init(mrb_state* mrb, R_VAL self) {
  mrb_value path;
  mrb_get_args(mrb, "o", &path);
#else
static R_VAL ruby2d_sprite_ext_init(R_VAL self, R_VAL path) {
#endif
  R2D_Sprite *spr = R2D_CreateSprite(RSTRING_PTR(path));
  if (!spr) return R_FALSE;

  r_iv_set(self, "@img_width" , INT2NUM(spr->width));
  r_iv_set(self, "@img_height", INT2NUM(spr->height));
  r_iv_set(self, "@data", r_data_wrap_struct(sprite, spr));

  return R_TRUE;
}


/*
 * Ruby2D::Sprite#ext_draw
 */
#if MRUBY
static R_VAL ruby2d_sprite_ext_draw(mrb_state* mrb, R_VAL self) {
  mrb_value a;
  mrb_get_args(mrb, "o", &a);
#else
static R_VAL ruby2d_sprite_ext_draw(R_VAL self, R_VAL a) {
#endif
  // `a` is the array representing the sprite

  R2D_Sprite *spr;
  r_data_get_struct(r_ary_entry(a, 0), "@data", &sprite_data_type, R2D_Sprite, spr);

  spr->x = NUM2DBL(r_ary_entry(a, 1));
  spr->y = NUM2DBL(r_ary_entry(a, 2));

  R_VAL w = r_ary_entry(a, 3);
  if (r_test(w)) spr->width = NUM2DBL(w);

  R_VAL h = r_ary_entry(a, 4);
  if (r_test(h)) spr->height = NUM2DBL(h);

  R2D_RotateSprite(spr, NUM2DBL(r_ary_entry(a, 5)), R2D_CENTER);

  R2D_ClipSprite(
    spr,
    NUM2INT(r_ary_entry(a, 6)),
    NUM2INT(r_ary_entry(a, 7)),
    NUM2INT(r_ary_entry(a, 8)),
    NUM2INT(r_ary_entry(a, 9))
  );

  spr->color.r = NUM2DBL(r_ary_entry(a, 10));
  spr->color.g = NUM2DBL(r_ary_entry(a, 11));
  spr->color.b = NUM2DBL(r_ary_entry(a, 12));
  spr->color.a = NUM2DBL(r_ary_entry(a, 13));

  R2D_DrawSprite(spr);
  return R_NIL;
}


/*
 * Free sprite structure attached to Ruby 2D `Sprite` class
 */
#if MRUBY
static void free_sprite(mrb_state *mrb, void *p_) {
  R2D_Sprite *spr = (R2D_Sprite *)p_;
#else
static void free_sprite(R2D_Sprite *spr) {
#endif
  R2D_FreeSprite(spr);
}


/*
 * Ruby2D::Tileset#ext_init
 * Initialize tileset data
 */
static R_VAL ruby2d_tileset_ext_init(R_VAL self, R_VAL path) {
  R2D_Image *img = R2D_CreateImage(RSTRING_PTR(path));
  if (!img) return R_FALSE;

  // Get width and height from Ruby class. If set, use it, else choose the
  // native dimensions of the image.
  R_VAL w = r_iv_get(self, "@width");
  R_VAL h = r_iv_get(self, "@height");
  r_iv_set(self, "@width" , r_test(w) ? w : INT2NUM(img->width));
  r_iv_set(self, "@height", r_test(h) ? h : INT2NUM(img->height));
  r_iv_set(self, "@data", r_data_wrap_struct(image, img));

  return R_TRUE;
}


/*
 * Ruby2D::Tileset#ext_draw
 * Draws a single tile, will be called once per individual tile to draw
 */
static R_VAL ruby2d_tileset_ext_draw(R_VAL self, R_VAL a) {
  // `a` is the array representing the tileset

  R2D_Image *img;
  r_data_get_struct(r_ary_entry(a, 0), "@data", &image_data_type, R2D_Image, img);

  int tw = NUM2INT(r_ary_entry(a, 1));
  int th = NUM2INT(r_ary_entry(a, 2));
  int padding = NUM2INT(r_ary_entry(a, 3));
  int spacing = NUM2INT(r_ary_entry(a, 4));
  int tx = NUM2INT(r_ary_entry(a, 5));
  int ty = NUM2INT(r_ary_entry(a, 6));
  int x = NUM2INT(r_ary_entry(a, 7));
  int y = NUM2INT(r_ary_entry(a, 8));

  R2D_DrawTile(img, tw, th, padding, spacing, tx, ty, x, y);
  return R_NIL;
}


/*
 * Ruby2D::Text#ext_init
 * Initialize text structure data
 */
#if MRUBY
static R_VAL ruby2d_text_ext_init(mrb_state* mrb, R_VAL self) {
#else
static R_VAL ruby2d_text_ext_init(R_VAL self) {
#endif
  // Trim the font file string to its actual length on MRuby
  #if MRUBY
    mrb_value s = r_iv_get(self, "@font");
    mrb_str_resize(mrb, s, RSTRING_LEN(s));
  #endif

  R2D_Text *txt = R2D_CreateText(
    RSTRING_PTR(r_iv_get(self, "@font")),
    RSTRING_PTR(r_iv_get(self, "@text")),
    NUM2DBL(r_iv_get(self, "@size"))
  );
  if (!txt) return R_FALSE;

  r_iv_set(self, "@width", INT2NUM(txt->width));
  r_iv_set(self, "@height", INT2NUM(txt->height));
  r_iv_set(self, "@data", r_data_wrap_struct(text, txt));

  return R_TRUE;
}


/*
 * Ruby2D::Text#ext_set
 */
#if MRUBY
static R_VAL ruby2d_text_ext_set(mrb_state* mrb, R_VAL self) {
  mrb_value text;
  mrb_get_args(mrb, "o", &text);
#else
static R_VAL ruby2d_text_ext_set(R_VAL self, R_VAL text) {
#endif
  R2D_Text *txt;
  r_data_get_struct(self, "@data", &text_data_type, R2D_Text, txt);

  R2D_SetText(txt, RSTRING_PTR(text));

  r_iv_set(self, "@width", INT2NUM(txt->width));
  r_iv_set(self, "@height", INT2NUM(txt->height));

  return R_NIL;
}


/*
 * Ruby2D::Text#self.ext_draw
 */
#if MRUBY
static R_VAL ruby2d_text_ext_draw(mrb_state* mrb, R_VAL self) {
  mrb_value a;
  mrb_get_args(mrb, "o", &a);
#else
static R_VAL ruby2d_text_ext_draw(R_VAL self, R_VAL a) {
#endif
  // `a` is the array representing the text

  R2D_Text *txt;
  r_data_get_struct(r_ary_entry(a, 0), "@data", &text_data_type, R2D_Text, txt);

  txt->x = NUM2DBL(r_ary_entry(a, 1));
  txt->y = NUM2DBL(r_ary_entry(a, 2));

  R2D_RotateText(txt, NUM2DBL(r_ary_entry(a, 3)), R2D_CENTER);

  txt->color.r = NUM2DBL(r_ary_entry(a, 4));
  txt->color.g = NUM2DBL(r_ary_entry(a, 5));
  txt->color.b = NUM2DBL(r_ary_entry(a, 6));
  txt->color.a = NUM2DBL(r_ary_entry(a, 7));

  R2D_DrawText(txt);
  return R_NIL;
}


/*
 * Free text structure attached to Ruby 2D `Text` class
 */
#if MRUBY
static void free_text(mrb_state *mrb, void *p_) {
  R2D_Text *txt = (R2D_Text *)p_;
#else
static void free_text(R2D_Text *txt) {
#endif
  R2D_FreeText(txt);
}


/*
 * Ruby2D::Sound#ext_init
 * Initialize sound structure data
 */
#if MRUBY
static R_VAL ruby2d_sound_ext_init(mrb_state* mrb, R_VAL self) {
  mrb_value path;
  mrb_get_args(mrb, "o", &path);
#else
static R_VAL ruby2d_sound_ext_init(R_VAL self, R_VAL path) {
#endif
  R2D_Sound *snd = R2D_CreateSound(RSTRING_PTR(path));
  if (!snd) return R_FALSE;
  r_iv_set(self, "@data", r_data_wrap_struct(sound, snd));
  return R_TRUE;
}


/*
 * Ruby2D::Sound#ext_play
 */
#if MRUBY
static R_VAL ruby2d_sound_ext_play(mrb_state* mrb, R_VAL self) {
#else
static R_VAL ruby2d_sound_ext_play(R_VAL self) {
#endif
  R2D_Sound *snd;
  r_data_get_struct(self, "@data", &sound_data_type, R2D_Sound, snd);
  R2D_PlaySound(snd);
  return R_NIL;
}


/*
 * Ruby2D::Sound#ext_length
 */
static R_VAL ruby2d_sound_ext_length(R_VAL self) {
  R2D_Sound *snd;
  r_data_get_struct(self, "@data", &sound_data_type, R2D_Sound, snd);
  return INT2NUM(R2D_GetSoundLength(snd));
}


/*
 * Free sound structure attached to Ruby 2D `Sound` class
 */
#if MRUBY
static void free_sound(mrb_state *mrb, void *p_) {
  R2D_Sound *snd = (R2D_Sound *)p_;
#else
static void free_sound(R2D_Sound *snd) {
#endif
  R2D_FreeSound(snd);
}


/*
 * Ruby2D::Music#ext_init
 * Initialize music structure data
 */
#if MRUBY
static R_VAL ruby2d_music_ext_init(mrb_state* mrb, R_VAL self) {
  mrb_value path;
  mrb_get_args(mrb, "o", &path);
#else
static R_VAL ruby2d_music_ext_init(R_VAL self, R_VAL path) {
#endif
  R2D_Music *mus = R2D_CreateMusic(RSTRING_PTR(path));
  if (!mus) return R_FALSE;
  r_iv_set(self, "@data", r_data_wrap_struct(music, mus));
  return R_TRUE;
}


/*
 * Ruby2D::Music#ext_play
 */
#if MRUBY
static R_VAL ruby2d_music_ext_play(mrb_state* mrb, R_VAL self) {
#else
static R_VAL ruby2d_music_ext_play(R_VAL self) {
#endif
  R2D_Music *mus;
  r_data_get_struct(self, "@data", &music_data_type, R2D_Music, mus);
  R2D_PlayMusic(mus, r_test(r_iv_get(self, "@loop")));
  return R_NIL;
}


/*
 * Ruby2D::Music#ext_pause
 */
#if MRUBY
static R_VAL ruby2d_music_ext_pause(mrb_state* mrb, R_VAL self) {
#else
static R_VAL ruby2d_music_ext_pause(R_VAL self) {
#endif
  R2D_PauseMusic();
  return R_NIL;
}


/*
 * Ruby2D::Music#ext_resume
 */
#if MRUBY
static R_VAL ruby2d_music_ext_resume(mrb_state* mrb, R_VAL self) {
#else
static R_VAL ruby2d_music_ext_resume(R_VAL self) {
#endif
  R2D_ResumeMusic();
  return R_NIL;
}


/*
 * Ruby2D::Music#ext_stop
 */
#if MRUBY
static R_VAL ruby2d_music_ext_stop(mrb_state* mrb, R_VAL self) {
#else
static R_VAL ruby2d_music_ext_stop(R_VAL self) {
#endif
  R2D_StopMusic();
  return R_NIL;
}


/*
 * Ruby2D::Music#ext_get_volume
 */
#if MRUBY
static R_VAL ruby2d_music_ext_get_volume(mrb_state* mrb, R_VAL self) {
#else
static R_VAL ruby2d_music_ext_get_volume(R_VAL self) {
#endif
  return INT2NUM(R2D_GetMusicVolume());
}


/*
 * Ruby2D::Music#ext_set_volume
 */
#if MRUBY
static R_VAL ruby2d_music_ext_set_volume(mrb_state* mrb, R_VAL self) {
  mrb_value volume;
  mrb_get_args(mrb, "o", &volume);
#else
static R_VAL ruby2d_music_ext_set_volume(R_VAL self, R_VAL volume) {
#endif
  R2D_SetMusicVolume(NUM2INT(volume));
  return R_NIL;
}


/*
 * Ruby2D::Music#ext_fadeout
 */
#if MRUBY
static R_VAL ruby2d_music_ext_fadeout(mrb_state* mrb, R_VAL self) {
  mrb_value ms;
  mrb_get_args(mrb, "o", &ms);
#else
static R_VAL ruby2d_music_ext_fadeout(R_VAL self, R_VAL ms) {
#endif
  R2D_FadeOutMusic(NUM2INT(ms));
  return R_NIL;
}


/*
 * Ruby2D::Music#ext_length
 */
static R_VAL ruby2d_music_ext_length(R_VAL self) {
  R2D_Music *ms;
  r_data_get_struct(self, "@data", &music_data_type, R2D_Music, ms);
  return INT2NUM(R2D_GetMusicLength(ms));
}


/*
 * Free music structure attached to Ruby 2D `Music` class
 */
#if MRUBY
static void free_music(mrb_state *mrb, void *p_) {
  R2D_Music *mus = (R2D_Music *)p_;
#else
static void free_music(R2D_Music *mus) {
#endif
  R2D_FreeMusic(mus);
}


/*
 * Ruby 2D native `on_key` input callback function
 */
static void on_key(R2D_Event e) {

  R_VAL type;

  switch (e.type) {
    case R2D_KEY_DOWN:
      type = r_char_to_sym("down");
      break;
    case R2D_KEY_HELD:
      type = r_char_to_sym("held");
      break;
    case R2D_KEY_UP:
      type = r_char_to_sym("up");
      break;
  }

  r_funcall(ruby2d_window, "key_callback", 2, type, r_str_new(e.key));
}


/*
 * Ruby 2D native `on_mouse` input callback function
 */
void on_mouse(R2D_Event e) {

  R_VAL type = R_NIL; R_VAL button = R_NIL; R_VAL direction = R_NIL;

  switch (e.type) {
    case R2D_MOUSE_DOWN:
      // type, button, x, y
      type = r_char_to_sym("down");
      break;
    case R2D_MOUSE_UP:
      // type, button, x, y
      type = r_char_to_sym("up");
      break;
    case R2D_MOUSE_SCROLL:
      // type, direction, delta_x, delta_y
      type = r_char_to_sym("scroll");
      direction = e.direction == R2D_MOUSE_SCROLL_NORMAL ?
        r_char_to_sym("normal") : r_char_to_sym("inverted");
      break;
    case R2D_MOUSE_MOVE:
      // type, x, y, delta_x, delta_y
      type = r_char_to_sym("move");
      break;
  }

  if (e.type == R2D_MOUSE_DOWN || e.type == R2D_MOUSE_UP) {
    switch (e.button) {
      case R2D_MOUSE_LEFT:
        button = r_char_to_sym("left");
        break;
      case R2D_MOUSE_MIDDLE:
        button = r_char_to_sym("middle");
        break;
      case R2D_MOUSE_RIGHT:
        button = r_char_to_sym("right");
        break;
      case R2D_MOUSE_X1:
        button = r_char_to_sym("x1");
        break;
      case R2D_MOUSE_X2:
        button = r_char_to_sym("x2");
        break;
    }
  }

  r_funcall(
    ruby2d_window, "mouse_callback", 7, type, button, direction,
    INT2NUM(e.x), INT2NUM(e.y), INT2NUM(e.delta_x), INT2NUM(e.delta_y)
  );
}


/*
 * Ruby 2D native `on_controller` input callback function
 */
static void on_controller(R2D_Event e) {

  R_VAL type = R_NIL; R_VAL axis = R_NIL; R_VAL button = R_NIL;

  switch (e.type) {
    case R2D_AXIS:
      type = r_char_to_sym("axis");
      switch (e.axis) {
        case R2D_AXIS_LEFTX:
          axis = r_char_to_sym("left_x");
          break;
        case R2D_AXIS_LEFTY:
          axis = r_char_to_sym("left_y");
          break;
        case R2D_AXIS_RIGHTX:
          axis = r_char_to_sym("right_x");
          break;
        case R2D_AXIS_RIGHTY:
          axis = r_char_to_sym("right_y");
          break;
        case R2D_AXIS_TRIGGERLEFT:
          axis = r_char_to_sym("trigger_left");
          break;
        case R2D_AXIS_TRIGGERRIGHT:
          axis = r_char_to_sym("trigger_right");
          break;
        case R2D_AXIS_INVALID:
          axis = r_char_to_sym("invalid");
          break;
      }
      break;
    case R2D_BUTTON_DOWN: case R2D_BUTTON_UP:
      type = e.type == R2D_BUTTON_DOWN ? r_char_to_sym("button_down") : r_char_to_sym("button_up");
      switch (e.button) {
        case R2D_BUTTON_A:
          button = r_char_to_sym("a");
          break;
        case R2D_BUTTON_B:
          button = r_char_to_sym("b");
          break;
        case R2D_BUTTON_X:
          button = r_char_to_sym("x");
          break;
        case R2D_BUTTON_Y:
          button = r_char_to_sym("y");
          break;
        case R2D_BUTTON_BACK:
          button = r_char_to_sym("back");
          break;
        case R2D_BUTTON_GUIDE:
          button = r_char_to_sym("guide");
          break;
        case R2D_BUTTON_START:
          button = r_char_to_sym("start");
          break;
        case R2D_BUTTON_LEFTSTICK:
          button = r_char_to_sym("left_stick");
          break;
        case R2D_BUTTON_RIGHTSTICK:
          button = r_char_to_sym("right_stick");
          break;
        case R2D_BUTTON_LEFTSHOULDER:
          button = r_char_to_sym("left_shoulder");
          break;
        case R2D_BUTTON_RIGHTSHOULDER:
          button = r_char_to_sym("right_shoulder");
          break;
        case R2D_BUTTON_DPAD_UP:
          button = r_char_to_sym("up");
          break;
        case R2D_BUTTON_DPAD_DOWN:
          button = r_char_to_sym("down");
          break;
        case R2D_BUTTON_DPAD_LEFT:
          button = r_char_to_sym("left");
          break;
        case R2D_BUTTON_DPAD_RIGHT:
          button = r_char_to_sym("right");
          break;
        case R2D_BUTTON_INVALID:
          button = r_char_to_sym("invalid");
          break;
      }
      break;
  }

  r_funcall(
    ruby2d_window, "controller_callback", 5, INT2NUM(e.which),
    type, axis, DBL2NUM(normalize_controller_axis(e.value)), button
  );
}


/*
 * Ruby 2D native `update` callback function
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
 * Ruby 2D native `render` callback function
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
    r_funcall(el, "render", 0);  // call the object's `render` function
  }

  // Call render proc, `window.render`
  r_funcall(ruby2d_window, "render_callback", 0);
}


/*
 * Ruby2D::Window#ext_diagnostics
 */
#if MRUBY
static R_VAL ruby2d_ext_diagnostics(mrb_state* mrb, R_VAL self) {
  mrb_value enable;
  mrb_get_args(mrb, "o", &enable);
#else
static R_VAL ruby2d_ext_diagnostics(R_VAL self, R_VAL enable) {
#endif
  // Set Ruby 2D native diagnostics
  R2D_Diagnostics(r_test(enable));
  return R_TRUE;
}


/*
 * Ruby2D::Window#ext_get_display_dimensions
 */
#if MRUBY
static R_VAL ruby2d_window_ext_get_display_dimensions(mrb_state* mrb, R_VAL self) {
#else
static R_VAL ruby2d_window_ext_get_display_dimensions(R_VAL self) {
#endif
  int w; int h;
  R2D_GetDisplayDimensions(&w, &h);
  r_iv_set(self, "@display_width" , INT2NUM(w));
  r_iv_set(self, "@display_height", INT2NUM(h));
  return R_NIL;
}


/*
 * Ruby2D::Window#ext_add_controller_mappings
 */
#if MRUBY
static R_VAL ruby2d_window_ext_add_controller_mappings(mrb_state* mrb, R_VAL self) {
  mrb_value path;
  mrb_get_args(mrb, "o", &path);
#else
static R_VAL ruby2d_window_ext_add_controller_mappings(R_VAL self, R_VAL path) {
#endif
  R2D_Log(R2D_INFO, "Adding controller mappings from `%s`", RSTRING_PTR(path));
  R2D_AddControllerMappingsFromFile(RSTRING_PTR(path));
  return R_NIL;
}


/*
 * Ruby2D::Window#ext_show
 */
#if MRUBY
static R_VAL ruby2d_window_ext_show(mrb_state* mrb, R_VAL self) {
#else
static R_VAL ruby2d_window_ext_show(R_VAL self) {
#endif
  ruby2d_window = self;

  // Add controller mappings from file
  r_funcall(self, "add_controller_mappings", 0);

  // Get window attributes
  char *title = RSTRING_PTR(r_iv_get(self, "@title"));
  int width   = NUM2INT(r_iv_get(self, "@width"));
  int height  = NUM2INT(r_iv_get(self, "@height"));
  int fps_cap = NUM2INT(r_iv_get(self, "@fps_cap"));

  // Get the window icon
  char *icon = NULL;
  R_VAL iv_icon = r_iv_get(self, "@icon");
  if (r_test(iv_icon)) icon = RSTRING_PTR(iv_icon);

  // Get window flags
  int flags = 0;
  if (r_test(r_iv_get(self, "@resizable"))) {
    flags = flags | R2D_RESIZABLE;
  }
  if (r_test(r_iv_get(self, "@borderless"))) {
    flags = flags | R2D_BORDERLESS;
  }
  if (r_test(r_iv_get(self, "@fullscreen"))) {
    flags = flags | R2D_FULLSCREEN;
  }
  if (r_test(r_iv_get(self, "@highdpi"))) {
    flags = flags | R2D_HIGHDPI;
  }

  // Check viewport size and set

  R_VAL vp_w = r_iv_get(self, "@viewport_width");
  int viewport_width = r_test(vp_w) ? NUM2INT(vp_w) : width;

  R_VAL vp_h = r_iv_get(self, "@viewport_height");
  int viewport_height = r_test(vp_h) ? NUM2INT(vp_h) : height;

  // Create and show window

  window = R2D_CreateWindow(
    title, width, height, update, render, flags
  );

  window->viewport.width  = viewport_width;
  window->viewport.height = viewport_height;
  window->fps_cap         = fps_cap;
  window->icon            = icon;
  window->on_key          = on_key;
  window->on_mouse        = on_mouse;
  window->on_controller   = on_controller;

  R2D_Show(window);

  atexit(free_window);
  return R_NIL;
}


/*
 * Ruby2D::Window#ext_screenshot
 */
#if MRUBY
static R_VAL ruby2d_ext_screenshot(mrb_state* mrb, R_VAL self) {
  mrb_value path;
  mrb_get_args(mrb, "o", &path);
#else
static R_VAL ruby2d_ext_screenshot(R_VAL self, R_VAL path) {
#endif
  if (window) {
    R2D_Screenshot(window, RSTRING_PTR(path));
    return path;
  } else {
    return R_FALSE;
  }
}


/*
 * Ruby2D::Window#ext_close
 */
static R_VAL ruby2d_window_ext_close() {
  R2D_Close(window);
  return R_NIL;
}


#if MRUBY
/*
 * MRuby entry point
 */
int main() {
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

  // Ruby2D#self.ext_base_path
  r_define_class_method(ruby2d_module, "ext_base_path", ruby2d_ext_base_path, r_args_none);

  // Ruby2D::Pixel
  R_CLASS ruby2d_pixel_class = r_define_class(ruby2d_module, "Pixel");

  // Ruby2D::Pixel#self.ext_draw
  r_define_class_method(ruby2d_pixel_class, "ext_draw", ruby2d_pixel_ext_draw, r_args_req(1));

  // Ruby2D::Triangle
  R_CLASS ruby2d_triangle_class = r_define_class(ruby2d_module, "Triangle");

  // Ruby2D::Triangle#self.ext_draw
  r_define_class_method(ruby2d_triangle_class, "ext_draw", ruby2d_triangle_ext_draw, r_args_req(1));

  // Ruby2D::Quad
  R_CLASS ruby2d_quad_class = r_define_class(ruby2d_module, "Quad");

  // Ruby2D::Quad#self.ext_draw
  r_define_class_method(ruby2d_quad_class, "ext_draw", ruby2d_quad_ext_draw, r_args_req(1));

  // Ruby2D::Line
  R_CLASS ruby2d_line_class = r_define_class(ruby2d_module, "Line");

  // Ruby2D::Line#self.ext_draw
  r_define_class_method(ruby2d_line_class, "ext_draw", ruby2d_line_ext_draw, r_args_req(1));

  // Ruby2D::Circle
  R_CLASS ruby2d_circle_class = r_define_class(ruby2d_module, "Circle");

  // Ruby2D::Circle#self.ext_draw
  r_define_class_method(ruby2d_circle_class, "ext_draw", ruby2d_circle_ext_draw, r_args_req(1));

  // Ruby2D::Image
  R_CLASS ruby2d_image_class = r_define_class(ruby2d_module, "Image");

  // Ruby2D::Image#ext_init
  r_define_method(ruby2d_image_class, "ext_init", ruby2d_image_ext_init, r_args_req(1));

  // Ruby2D::Image#self.ext_draw
  r_define_class_method(ruby2d_image_class, "ext_draw", ruby2d_image_ext_draw, r_args_req(1));

  // Ruby2D::Sprite
  R_CLASS ruby2d_sprite_class = r_define_class(ruby2d_module, "Sprite");

  // Ruby2D::Sprite#ext_init
  r_define_method(ruby2d_sprite_class, "ext_init", ruby2d_sprite_ext_init, r_args_req(1));

  // Ruby2D::Sprite#self.ext_draw
  r_define_class_method(ruby2d_sprite_class, "ext_draw", ruby2d_sprite_ext_draw, r_args_req(1));

  // Ruby2D::Tileset
  R_CLASS ruby2d_tileset_class = r_define_class(ruby2d_module, "Tileset");

  // Ruby2D::Tileset#ext_init
  r_define_method(ruby2d_tileset_class, "ext_init", ruby2d_tileset_ext_init, r_args_req(1));

  // Ruby2D::Tileset#self.ext_draw
  r_define_class_method(ruby2d_tileset_class, "ext_draw", ruby2d_tileset_ext_draw, r_args_req(1));

  // Ruby2D::Text
  R_CLASS ruby2d_text_class = r_define_class(ruby2d_module, "Text");

  // Ruby2D::Text#ext_init
  r_define_method(ruby2d_text_class, "ext_init", ruby2d_text_ext_init, r_args_none);

  // Ruby2D::Text#ext_set
  r_define_method(ruby2d_text_class, "ext_set", ruby2d_text_ext_set, r_args_req(1));

  // Ruby2D::Text#self.ext_draw
  r_define_class_method(ruby2d_text_class, "ext_draw", ruby2d_text_ext_draw, r_args_req(1));

  // Ruby2D::Sound
  R_CLASS ruby2d_sound_class = r_define_class(ruby2d_module, "Sound");

  // Ruby2D::Sound#ext_init
  r_define_method(ruby2d_sound_class, "ext_init", ruby2d_sound_ext_init, r_args_req(1));

  // Ruby2D::Sound#ext_play
  r_define_method(ruby2d_sound_class, "ext_play", ruby2d_sound_ext_play, r_args_none);

  // Ruby2D::Sound#ext_length
  r_define_method(ruby2d_sound_class, "ext_length", ruby2d_sound_ext_length, r_args_none);

  // Ruby2D::Music
  R_CLASS ruby2d_music_class = r_define_class(ruby2d_module, "Music");

  // Ruby2D::Music#ext_init
  r_define_method(ruby2d_music_class, "ext_init", ruby2d_music_ext_init, r_args_req(1));

  // Ruby2D::Music#ext_play
  r_define_method(ruby2d_music_class, "ext_play", ruby2d_music_ext_play, r_args_none);

  // Ruby2D::Music#ext_pause
  r_define_method(ruby2d_music_class, "ext_pause", ruby2d_music_ext_pause, r_args_none);

  // Ruby2D::Music#ext_resume
  r_define_method(ruby2d_music_class, "ext_resume", ruby2d_music_ext_resume, r_args_none);

  // Ruby2D::Music#ext_stop
  r_define_method(ruby2d_music_class, "ext_stop", ruby2d_music_ext_stop, r_args_none);

  // Ruby2D::Music#self.ext_get_volume
  r_define_class_method(ruby2d_music_class, "ext_get_volume", ruby2d_music_ext_get_volume, r_args_none);

  // Ruby2D::Music#self.ext_set_volume
  r_define_class_method(ruby2d_music_class, "ext_set_volume", ruby2d_music_ext_set_volume, r_args_req(1));

  // Ruby2D::Music#ext_fadeout
  r_define_method(ruby2d_music_class, "ext_fadeout", ruby2d_music_ext_fadeout, r_args_req(1));

  // Ruby2D::Music#ext_length
  r_define_method(ruby2d_music_class, "ext_length", ruby2d_music_ext_length, r_args_none);

  // Ruby2D::Window
  R_CLASS ruby2d_window_class = r_define_class(ruby2d_module, "Window");

  // Ruby2D::Window#ext_diagnostics
  r_define_method(ruby2d_window_class, "ext_diagnostics", ruby2d_ext_diagnostics, r_args_req(1));

  // Ruby2D::Window#ext_get_display_dimensions
  r_define_method(ruby2d_window_class, "ext_get_display_dimensions", ruby2d_window_ext_get_display_dimensions, r_args_none);

  // Ruby2D::Window#ext_add_controller_mappings
  r_define_method(ruby2d_window_class, "ext_add_controller_mappings", ruby2d_window_ext_add_controller_mappings, r_args_req(1));

  // Ruby2D::Window#ext_show
  r_define_method(ruby2d_window_class, "ext_show", ruby2d_window_ext_show, r_args_none);

  // Ruby2D::Window#ext_screenshot
  r_define_method(ruby2d_window_class, "ext_screenshot", ruby2d_ext_screenshot, r_args_req(1));

  // Ruby2D::Window#ext_close
  r_define_method(ruby2d_window_class, "ext_close", ruby2d_window_ext_close, r_args_none);

#if MRUBY
  // Load the Ruby 2D app
  mrb_load_irep(mrb, ruby2d_app);

  // If an exception, print error
  if (mrb->exc) mrb_print_error(mrb);

  // Close the MRuby environment
  mrb_close(mrb);

  return 0;
#endif
}
