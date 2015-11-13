#include <ruby.h>
#include <simple2d.h>

// @type_id values for rendering
#define TRIANGLE 1
#define QUAD     2
#define IMAGE    3
#define TEXT     4

// Ruby 2D window
VALUE self;

// Simple 2D window
Window *window;

// Ruby data types
static VALUE ruby2d_module;
static VALUE ruby2d_window_klass;
static VALUE c_data_klass;

// Structures for Ruby 2D classes
struct image_data {
  Image img;
};
struct text_data {
  Text txt;
};
struct sound_data {
  Sound snd;
};


/*
 * Function pointer to close the Simple 2D window
 */
static void close_window() {
  S2D_Close(window);
}


/*
 * Free image structure attached to Ruby 2D `Image` class
 */
static void free_image(struct image_data *data) {
  S2D_FreeImage(data->img);
  xfree(data);
}


/*
 * Initialize image structure data
 */
static VALUE init_image(char *path) {
  struct image_data *data = ALLOC(struct image_data);
  data->img = S2D_CreateImage(path);
  return Data_Wrap_Struct(c_data_klass, NULL, free_image, data);
}


/*
 * Free text structure attached to Ruby 2D `Text` class
 */
static void free_text(struct text_data *data) {
  S2D_FreeText(data->txt);
  xfree(data);
}


/*
 * Initialize text structure data
 */
static VALUE init_text(char *font, char *msg, int size) {
  struct text_data *data = ALLOC(struct text_data);
  data->txt = S2D_CreateText(font, msg, size);
  return Data_Wrap_Struct(c_data_klass, NULL, free_text, data);
}


/*
 * Simple 2D `on_key` input callback function
 */
void on_key(const char *key) {
  rb_funcall(self, rb_intern("key_callback"), 1, rb_str_new2(key));
}


/*
 * Simple 2D `on_key_down` input callback function
 */
void on_key_down(const char *key) {
  rb_funcall(self, rb_intern("key_down_callback"), 1, rb_str_new2(key));
}


/*
 * Simple 2D `on_controller` input callback function
 */
void on_controller(bool is_axis, int axis, int val, bool is_btn, int btn) {
  rb_funcall(self, rb_intern("controller_callback"), 5,
    is_axis ? Qtrue : Qfalse, INT2NUM(axis), INT2NUM(val),
    is_btn  ? Qtrue : Qfalse, INT2NUM(btn)
  );
}


/*
 * Simple 2D `update` callback function
 */
void update() {
  
  // Set the cursor
  rb_iv_set(self, "@mouse_x", INT2NUM(window->mouse.x));
  rb_iv_set(self, "@mouse_y", INT2NUM(window->mouse.y));
  
  // Call update proc, `window.update`
  rb_funcall(self, rb_intern("update_callback"), 0);
}


/*
 * Simple 2D `render` callback function
 */
void render() {
  
  // Read window objects
  VALUE objects = rb_iv_get(self, "@objects");
  int num_objects = NUM2INT(rb_funcall(objects, rb_intern("count"), 0));
  
  // Switch on each object type
  for (int i = 0; i < num_objects; ++i) {
    
    VALUE el = rb_ary_entry(objects, i);
    int type_id = NUM2INT(rb_iv_get(el, "@type_id"));
    
    // Switch on the object's type_id
    switch(type_id) {
      
      case TRIANGLE: {
        VALUE c1 = rb_iv_get(el, "@c1");
        VALUE c2 = rb_iv_get(el, "@c2");
        VALUE c3 = rb_iv_get(el, "@c3");
        
        S2D_DrawTriangle(
          NUM2DBL(rb_iv_get(el, "@x1")),
          NUM2DBL(rb_iv_get(el, "@y1")),
          NUM2DBL(rb_iv_get(c1, "@r")),
          NUM2DBL(rb_iv_get(c1, "@g")),
          NUM2DBL(rb_iv_get(c1, "@b")),
          NUM2DBL(rb_iv_get(c1, "@a")),
          
          NUM2DBL(rb_iv_get(el, "@x2")),
          NUM2DBL(rb_iv_get(el, "@y2")),
          NUM2DBL(rb_iv_get(c2, "@r")),
          NUM2DBL(rb_iv_get(c2, "@g")),
          NUM2DBL(rb_iv_get(c2, "@b")),
          NUM2DBL(rb_iv_get(c2, "@a")),
          
          NUM2DBL(rb_iv_get(el, "@x3")),
          NUM2DBL(rb_iv_get(el, "@y3")),
          NUM2DBL(rb_iv_get(c3, "@r")),
          NUM2DBL(rb_iv_get(c3, "@g")),
          NUM2DBL(rb_iv_get(c3, "@b")),
          NUM2DBL(rb_iv_get(c3, "@a"))
        );
      }
      break;
      
      case QUAD: {
        VALUE c1 = rb_iv_get(el, "@c1");
        VALUE c2 = rb_iv_get(el, "@c2");
        VALUE c3 = rb_iv_get(el, "@c3");
        VALUE c4 = rb_iv_get(el, "@c4");
        
        S2D_DrawQuad(
          NUM2DBL(rb_iv_get(el, "@x1")),
          NUM2DBL(rb_iv_get(el, "@y1")),
          NUM2DBL(rb_iv_get(c1, "@r")),
          NUM2DBL(rb_iv_get(c1, "@g")),
          NUM2DBL(rb_iv_get(c1, "@b")),
          NUM2DBL(rb_iv_get(c1, "@a")),

          NUM2DBL(rb_iv_get(el, "@x2")),
          NUM2DBL(rb_iv_get(el, "@y2")),
          NUM2DBL(rb_iv_get(c2, "@r")),
          NUM2DBL(rb_iv_get(c2, "@g")),
          NUM2DBL(rb_iv_get(c2, "@b")),
          NUM2DBL(rb_iv_get(c2, "@a")),

          NUM2DBL(rb_iv_get(el, "@x3")),
          NUM2DBL(rb_iv_get(el, "@y3")),
          NUM2DBL(rb_iv_get(c3, "@r")),
          NUM2DBL(rb_iv_get(c3, "@g")),
          NUM2DBL(rb_iv_get(c3, "@b")),
          NUM2DBL(rb_iv_get(c3, "@a")),

          NUM2DBL(rb_iv_get(el, "@x4")),
          NUM2DBL(rb_iv_get(el, "@y4")),
          NUM2DBL(rb_iv_get(c4, "@r")),
          NUM2DBL(rb_iv_get(c4, "@g")),
          NUM2DBL(rb_iv_get(c4, "@b")),
          NUM2DBL(rb_iv_get(c4, "@a"))
        );
      }
      break;
      
      case IMAGE: {
        if (rb_iv_get(el, "@data") == Qnil) {
          VALUE data = init_image(RSTRING_PTR(rb_iv_get(el, "@path")));
          rb_iv_set(el, "@data", data);
        }
        
        struct image_data *data;
        Data_Get_Struct(rb_iv_get(el, "@data"), struct image_data, data);
        
        data->img.x = NUM2DBL(rb_iv_get(el, "@x"));
        data->img.y = NUM2DBL(rb_iv_get(el, "@y"));
        S2D_DrawImage(data->img);
      }
      break;
      
      case TEXT: {
        if (rb_iv_get(el, "@data") == Qnil) {
          VALUE data = init_text(
            RSTRING_PTR(rb_iv_get(el, "@font")),
            RSTRING_PTR(rb_iv_get(el, "@text")),
            NUM2DBL(rb_iv_get(el, "@size"))
          );
          rb_iv_set(el, "@data", data);
        }
        
        struct text_data *data;
        Data_Get_Struct(rb_iv_get(el, "@data"), struct text_data, data);
        
        data->txt.x = NUM2DBL(rb_iv_get(el, "@x"));
        data->txt.y = NUM2DBL(rb_iv_get(el, "@y"));
        S2D_DrawText(data->txt);
      }
      break;
    }
  }
}


/*
 * Ruby2D::Window#show
 */
static VALUE ruby2d_show(VALUE s) {
  self = s;
  
  char *title = RSTRING_PTR(rb_iv_get(self, "@title"));
  int width   = NUM2INT(rb_iv_get(self, "@width"));
  int height  = NUM2INT(rb_iv_get(self, "@height"));
  
  window = S2D_CreateWindow(
    title, width, height, update, render
  );
  
  window->on_key = on_key;
  window->on_key_down = on_key_down;
  window->on_controller = on_controller;
  
  S2D_Show(window);
  
  atexit(close_window);
  return Qnil;
}


/*
 * Ruby C extension init
 */
void Init_ruby2d() {
  
  // Ruby2D
  ruby2d_module = rb_define_module("Ruby2D");
  
  // Ruby2D::Window
  ruby2d_window_klass = rb_define_class_under(ruby2d_module, "Window", rb_cObject);
  
  // Ruby2D::Window#show
  rb_define_method(ruby2d_window_klass, "show", ruby2d_show, 0);
  
  // Ruby2D::CData
  c_data_klass = rb_define_class_under(ruby2d_module, "CData", rb_cObject);
}
