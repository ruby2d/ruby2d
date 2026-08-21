// image.c

#include "ruby2d.h"

// Case-insensitive check for the `.svg` extension on a path.
static bool path_is_svg(const char *path) {
  if (!path) return false;
  size_t len = strlen(path);
  if (len < 4) return false;
  const char *ext = path + len - 4;
  return ext[0] == '.' &&
         (ext[1] == 's' || ext[1] == 'S') &&
         (ext[2] == 'v' || ext[2] == 'V') &&
         (ext[3] == 'g' || ext[3] == 'G');
}


// Cores ///////////////////////////////////////////////////////////////////////
//
// The image renderer with no Ruby object in it: the Ruby bindings below read
// the ivars and call these, and the Ruby-free handle API after them passes the
// same values in as arguments. Failures set the SDL error and return NULL or
// false so either caller can report them its own way.

/*
 * Decode an image file into a surface. SVGs rasterize at their intrinsic size
 * via IMG_Load and then pixelate when drawn larger, so when the caller knows
 * the display size (w, h > 0) they rasterize at 2× it: small upscales and
 * rotations stay crisp, and downscales to the display size are SDL's at draw
 * time. Raster formats ignore the size.
 */
static SDL_Surface *R2D_ImageLoadSurface(const char *path, int w, int h) {
  SDL_Surface *surface = NULL;
  if (path_is_svg(path) && w > 0 && h > 0) {
    SDL_IOStream *io = SDL_IOFromFile(path, "rb");
    if (io) {
      surface = IMG_LoadSizedSVG_IO(io, w * 2, h * 2);
      SDL_CloseIO(io);
    }
  }
  if (!surface) surface = IMG_Load(path);
  return surface;
}


/*
 * Upload the surface to a texture the first time it is drawn. The surface
 * stays alive for canvas blitting; R2D_ImageDestroy releases both.
 */
static bool R2D_ImageEnsureTexture(R2D_Image *img) {
  if (img->texture) return true;
  img->texture = SDL_CreateTextureFromSurface(R2D_GetRenderer(), img->surface);
  if (!img->texture) return false;
  SDL_SetTextureBlendMode(img->texture, SDL_BLENDMODE_BLEND);
  img->applied_scale_mode = SDL_SCALEMODE_INVALID;
  return true;
}


/*
 * Draw the image into (x, y, w, h), rotated about the world point (crx, cry)
 * and tinted. `clipped` selects the (clip_x, clip_y, clip_w, clip_h) source
 * rect, placed inside the destination by the trim metadata: `source_w` /
 * `source_h` is the original logical frame size, `trim_x` / `trim_y` where
 * the packed pixels live within it. With the no-trim defaults (source = clip,
 * trim = 0) the math collapses to drawing the clip rect at (x, y).
 */
static bool R2D_ImageDrawWith(R2D_Image *img,
                              float x, float y, float w, float h, float rotate,
                              float crx, float cry,
                              float r, float g, float b, float a,
                              SDL_FlipMode flip_mode, SDL_ScaleMode mode,
                              bool clipped, int clip_x, int clip_y,
                              int clip_w, int clip_h,
                              int source_w, int source_h, int trim_x, int trim_y) {
  if (!R2D_ImageEnsureTexture(img)) return false;

  if (mode != img->applied_scale_mode) {
    SDL_SetTextureScaleMode(img->texture, mode);
    img->applied_scale_mode = mode;
  }

  SDL_FRect dst_rect;
  SDL_FRect clip_rect;
  SDL_FRect *src_rect = NULL;

  if (clipped) {
    // Source rect inside the texture, clamped to the area that actually
    // remains after the clip offset. The public accessors (`clip_x=`,
    // `clip_width=`, etc.) are unvalidated, so a zero-size, negative, or
    // past-the-edge clip can reach here; an offset-aware clamp keeps the
    // src rect inside the texture and the scale math finite.
    int orig_width  = img->surface->w;
    int orig_height = img->surface->h;

    if (clip_x < 0) clip_x = 0;
    if (clip_x > orig_width)  clip_x = orig_width;
    if (clip_y < 0) clip_y = 0;
    if (clip_y > orig_height) clip_y = orig_height;

    int avail_w = orig_width  - clip_x;
    int avail_h = orig_height - clip_y;
    int clipped_w = clip_w > avail_w ? avail_w : clip_w;
    int clipped_h = clip_h > avail_h ? avail_h : clip_h;

    // Degenerate or fully out-of-bounds clip: nothing to draw. Bail before
    // the source_w/source_h division so it can't produce Inf/NaN geometry.
    if (clipped_w <= 0 || clipped_h <= 0) return true;

    clip_rect.x = clip_x;
    clip_rect.y = clip_y;
    clip_rect.w = clipped_w;
    clip_rect.h = clipped_h;
    src_rect = &clip_rect;

    if (source_w <= 0) source_w = clipped_w;
    if (source_h <= 0) source_h = clipped_h;

    // Mirror the trim offset for flipped sprites so the pose flips around
    // the original frame's center, not around the trimmed rect's center.
    if (flip_mode & SDL_FLIP_HORIZONTAL) trim_x = source_w - trim_x - clipped_w;
    if (flip_mode & SDL_FLIP_VERTICAL)   trim_y = source_h - trim_y - clipped_h;

    float scale_x = w / (float)source_w;
    float scale_y = h / (float)source_h;

    dst_rect.x = x + trim_x * scale_x;
    dst_rect.y = y + trim_y * scale_y;
    dst_rect.w = clipped_w * scale_x;
    dst_rect.h = clipped_h * scale_y;
  } else {
    dst_rect.x = x;
    dst_rect.y = y;
    dst_rect.w = w;
    dst_rect.h = h;
  }

  SDL_SetTextureColorModFloat(img->texture, r, g, b);
  SDL_SetTextureAlphaModFloat(img->texture, a);

  // Rotation center: world coords minus dst_rect's top-left. With trim, the
  // dst rect shifts by (trim_x*scale_x, trim_y*scale_y), so the
  // center-relative offset shifts by the same amount.
  SDL_FPoint center = { crx - dst_rect.x, cry - dst_rect.y };

  bool ok = SDL_RenderTextureRotated(
    R2D_GetRenderer(), img->texture, src_rect, &dst_rect, rotate, &center, flip_mode
  );
  R2D_CheckSDL(ok, "SDL_RenderTextureRotated");
  return ok;
}


/*
 * Re-rasterize the source at a new pixel size. SVG sources reload at 2× the
 * requested size; raster sources reload and resample via SDL_ScaleSurface in
 * the given mode. The cached texture is freed and recreated lazily on the
 * next draw.
 */
static bool R2D_ImageReload(R2D_Image *img, const char *path, int w, int h,
                            SDL_ScaleMode mode) {
  SDL_Surface *new_surface = NULL;

  if (path_is_svg(path)) {
    new_surface = R2D_ImageLoadSurface(path, w, h);
  } else {
    SDL_Surface *src = IMG_Load(path);
    if (src) {
      new_surface = SDL_ScaleSurface(src, w, h, mode);
      SDL_DestroySurface(src);
    }
  }
  if (!new_surface) return false;

  if (img->surface) SDL_DestroySurface(img->surface);
  if (img->texture) {
    SDL_DestroyTexture(img->texture);
    img->texture = NULL;
  }
  img->surface = new_surface;
  return true;
}


/*
 * Free the memory and resources associated with an R2D_Image
 */
static void R2D_ImageDestroy(R2D_Image *img) {
  if (!img) return;
  if (img->surface) {
    SDL_DestroySurface(img->surface);
    img->surface = NULL;
  }
  if (img->texture) {
    if (R2D_RendererAlive()) SDL_DestroyTexture(img->texture);
    img->texture = NULL;
  }
  free(img);
}


// Ruby-free image API /////////////////////////////////////////////////////////
//
// What the Spinel build calls over FFI, since it cannot hand a Ruby object to
// C: an image is an opaque handle loaded from a path, its size is read back,
// and every draw passes the geometry, tint and clip in as arguments. Clip
// state sits on the handle (R2D_ImageClip) rather than on the draw call, so a
// plain Image never mentions it; a Sprite sets it before each draw.

void *R2D_ImageNew(const char *path, int width, int height) {
  if (!path || !R2D_FileExists(path)) {
    SDL_SetError("Image file `%s` not found", path ? path : "");
    return NULL;
  }
  R2D_Image *img = (R2D_Image *)calloc(1, sizeof(R2D_Image));
  if (!img) return NULL;
  img->surface = R2D_ImageLoadSurface(path, width, height);
  if (!img->surface) {
    free(img);
    return NULL;
  }
  img->applied_scale_mode = SDL_SCALEMODE_INVALID;
  return img;
}

int R2D_ImageWidth(void *image)  { return image ? ((R2D_Image *)image)->surface->w : 0; }
int R2D_ImageHeight(void *image) { return image ? ((R2D_Image *)image)->surface->h : 0; }

void R2D_ImageClip(void *image, bool clipped, int clip_x, int clip_y,
                   int clip_w, int clip_h, int source_w, int source_h,
                   int trim_x, int trim_y) {
  R2D_Image *img = (R2D_Image *)image;
  if (!img) return;
  img->clipped  = clipped;
  img->clip_x   = clip_x;
  img->clip_y   = clip_y;
  img->clip_w   = clip_w;
  img->clip_h   = clip_h;
  img->source_w = source_w;
  img->source_h = source_h;
  img->trim_x   = trim_x;
  img->trim_y   = trim_y;
}

// `flip`: 0 none, 1 horizontal, 2 vertical, 3 both — SDL_FlipMode's bits.
bool R2D_ImageDraw(void *image, float x, float y, float w, float h, float rotate,
                   float crx, float cry, float r, float g, float b, float a,
                   int flip, const char *scale_mode) {
  R2D_Image *img = (R2D_Image *)image;
  if (!img) return false;
  R2D_Window *window = R2D_GetWindow();
  SDL_ScaleMode fallback = window ? window->scale_mode : SDL_SCALEMODE_LINEAR;
  return R2D_ImageDrawWith(img, x, y, w, h, rotate, crx, cry, r, g, b, a,
                           (SDL_FlipMode)(flip & 3),
                           R2D_ParseScaleModeName(scale_mode, fallback),
                           img->clipped, img->clip_x, img->clip_y,
                           img->clip_w, img->clip_h,
                           img->source_w, img->source_h, img->trim_x, img->trim_y);
}

// Resampling is a CPU blit, so PIXELART degrades to nearest as
// R2D_ResolveSurfaceScaleMode does.
bool R2D_ImageResize(void *image, const char *path, int w, int h, const char *scale_mode) {
  if (!image || !path || w <= 0 || h <= 0) return false;
  R2D_Window *window = R2D_GetWindow();
  SDL_ScaleMode mode = R2D_ParseScaleModeName(scale_mode, window ? window->scale_mode : SDL_SCALEMODE_LINEAR);
  if (mode == SDL_SCALEMODE_PIXELART) mode = SDL_SCALEMODE_NEAREST;
  return R2D_ImageReload((R2D_Image *)image, path, w, h, mode);
}

void R2D_ImageFree(void *image) {
  R2D_ImageDestroy((R2D_Image *)image);
}


// Ruby bindings ///////////////////////////////////////////////////////////////

#ifndef RUBY2D_NO_RUBY
R2D_DEFINE_DATA_TYPE(R2D_Image);

// Image-specific ivar IDs. Shared ivar IDs (id_x, id_y, id_width, id_height,
// id_rotate, id_color, id_r, id_g, id_b, id_a, id_ext_image, id_path) live in
// ext.c; this file only caches what's unique to Image.
static R_ID id_clipped, id_clip_x, id_clip_y, id_clip_width, id_clip_height;
static R_ID id_orig_width, id_orig_height;
static R_ID id_source_width, id_source_height, id_trim_x, id_trim_y;
static R_ID id_user_rx, id_user_ry;
static R_ID id_flip;
static R_ID id_flip_horizontal, id_flip_vertical, id_flip_both;


/*
 * Initialize — caches ivar IDs and registers Ruby2D::Ext image bindings.
 * Bindings take the Image Ruby object as their first arg and read ivars off
 * it; the C side reads ivars from that object via obj_* macros.
 */
void R2D_Image_Init() {
  id_orig_width  = r_id("@orig_width");
  id_orig_height = r_id("@orig_height");
  id_clipped     = r_id("@clipped");
  id_clip_x      = r_id("@clip_x");
  id_clip_y      = r_id("@clip_y");
  id_clip_width  = r_id("@clip_width");
  id_clip_height = r_id("@clip_height");
  id_source_width  = r_id("@source_width");
  id_source_height = r_id("@source_height");
  id_trim_x        = r_id("@trim_x");
  id_trim_y        = r_id("@trim_y");
  id_user_rx     = r_id("@_user_rx");
  id_user_ry     = r_id("@_user_ry");
  id_flip        = r_id("@flip");
  id_flip_horizontal = r_id("horizontal");
  id_flip_vertical   = r_id("vertical");
  id_flip_both       = r_id("both");

  r_define_class_method(ruby2d_ext_module, "image_create",    ruby2d_ext_image_create,    r_args_variadic);
  r_define_class_method(ruby2d_ext_module, "image_draw",      ruby2d_ext_image_draw,      r_args_variadic);
  r_define_class_method(ruby2d_ext_module, "image_draw_quads", ruby2d_ext_image_draw_quads, r_args_variadic);
  r_define_class_method(ruby2d_ext_module, "image_resize",    ruby2d_ext_image_resize,    r_args_variadic);
}


// The sizes image_create and image_resize write back onto the object after a
// (re)load: the surface's, with the clip reset to cover all of it.
static void R2D_ImageSyncSize(R_VAL obj, R2D_Image *img) {
  obj_set_int(obj, id_orig_width, img->surface->w);
  obj_set_int(obj, id_orig_height, img->surface->h);
  obj_set_bool(obj, id_clipped, false);
  obj_set_float(obj, id_clip_x, 0.0);
  obj_set_float(obj, id_clip_y, 0.0);
  obj_set_int(obj, id_clip_width, img->surface->w);
  obj_set_int(obj, id_clip_height, img->surface->h);
  obj_set_int(obj, id_source_width, img->surface->w);
  obj_set_int(obj, id_source_height, img->surface->h);
  obj_set_int(obj, id_trim_x, 0);
  obj_set_int(obj, id_trim_y, 0);
}


/*
 * Ruby2D::Ext.image_create(image)
 */
R_VAL ruby2d_ext_image_create(RUBY2D_METHOD_ARGS_VARIADIC) {
  RUBY2D_EXTRACT_VARIADIC;
  if (argc != 1) r_raise("Ruby2D::Ext.image_create expects 1 arg (image), got %d", (int)argc);
  R_VAL obj = argv[0];

  const char *path = obj_str(obj, id_path);

  if (!R2D_FileExists(path)) {
    r_error("Image file `%s` not found", path);
    return R_NIL;
  }

  // The user's display size, if given, steers the SVG rasterizer.
  int w = 0, h = 0;
  R_VAL w_val = r_ivar_get(obj, id_width);
  R_VAL h_val = r_ivar_get(obj, id_height);
  if (r_test(w_val) && r_test(h_val)) {
    w = (int)NUM2DBL(w_val);
    h = (int)NUM2DBL(h_val);
  }

  R2D_Image *img = (R2D_Image *)calloc(1, sizeof(R2D_Image));
  img->surface = R2D_ImageLoadSurface(path, w, h);
  if (!img->surface) {
    free(img);
    r_error("Failed to load image `%s`: %s", path, SDL_GetError());
    return R_NIL;
  }
  img->applied_scale_mode = SDL_SCALEMODE_INVALID;

  obj_set_struct(obj, id_ext_image, R2D_Image, img);
  obj_set_int(obj, id_width, img->surface->w);
  obj_set_int(obj, id_height, img->surface->h);
  R2D_ImageSyncSize(obj, img);
  obj_set_float(obj, id_rotate, 0.0);

  return R_TRUE;
}


/*
 * Ruby2D::Ext.image_draw(image)
 */
R_VAL ruby2d_ext_image_draw(RUBY2D_METHOD_ARGS_VARIADIC) {
  RUBY2D_EXTRACT_VARIADIC;
  if (argc != 1) r_raise("Ruby2D::Ext.image_draw expects 1 arg (image), got %d", (int)argc);
  R_VAL obj = argv[0];

  R2D_Image *img;
  obj_struct(obj, id_ext_image, R2D_Image, img);

  SDL_FlipMode flip_mode = SDL_FLIP_NONE;
  R_VAL flip_val = r_ivar_get(obj, id_flip);
  if (r_test(flip_val)) {
    R_ID flip_sym = r_sym_to_id(flip_val);
    if (flip_sym == id_flip_horizontal)
      flip_mode = SDL_FLIP_HORIZONTAL;
    else if (flip_sym == id_flip_vertical)
      flip_mode = SDL_FLIP_VERTICAL;
    else if (flip_sym == id_flip_both)
      flip_mode = (SDL_FlipMode)(SDL_FLIP_HORIZONTAL | SDL_FLIP_VERTICAL);
  }

  float img_x = obj_float(obj, id_x);
  float img_y = obj_float(obj, id_y);
  float img_w = obj_float(obj, id_width);
  float img_h = obj_float(obj, id_height);

  // Read color directly from the Color object
  R_VAL color_obj = r_ivar_get(obj, id_color);

  // Rotation center: the user's, or the image's center.
  R_VAL urx = r_ivar_get(obj, id_user_rx);
  R_VAL ury = r_ivar_get(obj, id_user_ry);
  float center_rx = r_test(urx) ? NUM2DBL(urx) : img_x + img_w / 2.0f;
  float center_ry = r_test(ury) ? NUM2DBL(ury) : img_y + img_h / 2.0f;

  bool ok = R2D_ImageDrawWith(img, img_x, img_y, img_w, img_h,
                              obj_float(obj, id_rotate), center_rx, center_ry,
                              NUM2DBL(r_ivar_get(color_obj, id_r)),
                              NUM2DBL(r_ivar_get(color_obj, id_g)),
                              NUM2DBL(r_ivar_get(color_obj, id_b)),
                              NUM2DBL(r_ivar_get(color_obj, id_a)),
                              flip_mode, R2D_ResolveScaleMode(obj),
                              obj_bool(obj, id_clipped),
                              (int)obj_float(obj, id_clip_x), (int)obj_float(obj, id_clip_y),
                              obj_int(obj, id_clip_width), obj_int(obj, id_clip_height),
                              obj_int(obj, id_source_width), obj_int(obj, id_source_height),
                              obj_int(obj, id_trim_x), obj_int(obj, id_trim_y));
  if (!ok && !img->texture) {
    r_raise("SDL_CreateTextureFromSurface failed: %s", SDL_GetError());
    return R_NIL;
  }

  return R_TRUE;
}


// Grow-only scratch buffers for image_draw_quads, reused across every call so a
// per-frame tileset draw costs no malloc/free. Capacity is measured in quads:
// quad_capacity quads back quad_capacity*4 vertices and quad_capacity*6 indices.
// Safe as a single shared slot because the render path is single-threaded and
// each call fully repopulates the vertices before drawing and retains nothing
// after. Never freed — bounded by the largest tileset ever drawn, matching the
// engine's no-teardown design. The index buffer is a pure function of quad
// position (i*4 + {0,1,2,0,2,3}), so it is filled only for the newly grown
// region and left untouched on every steady-state frame.
static SDL_Vertex *quad_vertices = NULL;
static int *quad_indices = NULL;
static int quad_capacity = 0;

/*
 * Ruby2D::Ext.image_draw_quads
 *
 * Draws a batch of textured quads from one atlas texture in a single
 * SDL_RenderGeometry call. Used by Tileset to render every placed tile at once
 * rather than one draw call per tile.
 *   coords_batch     - Array of N coordinate arrays, each 8 floats
 *                      [x1,y1, x2,y2, x3,y3, x4,y4]
 *   tex_coords_batch - Array of N texture-coordinate arrays, each 8 floats
 *                      [u1,v1, u2,v2, u3,v3, u4,v4], paired with coords_batch
 *   color            - Color object with @r, @g, @b, @a, applied to every quad
 *
 * The vertex buffer is fully repopulated on every call, even when no placement
 * changed since the last frame. Don't add a dirty-flag skip: an A/B measured it
 * ~9% slower on tiles_static (299 -> 272 fps) because the per-frame CPU write
 * keeps the buffer hot in cache for SDL_RenderGeometry's immediate read — the
 * "wasted" marshaling is prefetching. See "Tried and rejected" in
 * benchmark/README.md.
 */
R_VAL ruby2d_ext_image_draw_quads(RUBY2D_METHOD_ARGS_VARIADIC) {
  RUBY2D_EXTRACT_VARIADIC;
  if (argc != 4) r_raise("Ruby2D::Ext.image_draw_quads expects 4 args (image, coords_batch, tex_coords_batch, color), got %d", (int)argc);
  R_VAL obj              = argv[0];
  R_VAL coords_batch     = argv[1];
  R_VAL tex_coords_batch = argv[2];
  R_VAL color_obj        = argv[3];

  R2D_Image *img;
  obj_struct(obj, id_ext_image, R2D_Image, img);

  int count = (int)r_ary_len(coords_batch);
  if (count <= 0) return R_TRUE;

  if (!R2D_ImageEnsureTexture(img)) {
    r_raise("SDL_CreateTextureFromSurface failed: %s", SDL_GetError());
    return R_NIL;
  }

  R2D_ApplyScaleMode(img->texture, obj, &img->applied_scale_mode);

  // Extract color components (a single tint applied to every quad)
  float cr = NUM2DBL(r_ivar_get(color_obj, id_r));
  float cg = NUM2DBL(r_ivar_get(color_obj, id_g));
  float cb = NUM2DBL(r_ivar_get(color_obj, id_b));
  float ca = NUM2DBL(r_ivar_get(color_obj, id_a));

  // One batch: 4 vertices and 6 indices per quad, drawn in a single call. Grow
  // the shared scratch buffers if this batch is the largest seen so far; on the
  // steady-state frame (count <= quad_capacity) this is a no-op.
  if (count > quad_capacity) {
    SDL_Vertex *nv = (SDL_Vertex *)realloc(quad_vertices, (size_t)count * 4 * sizeof(SDL_Vertex));
    if (nv) quad_vertices = nv;
    int *ni = (int *)realloc(quad_indices, (size_t)count * 6 * sizeof(int));
    if (ni) quad_indices = ni;
    if (!nv || !ni) {
      r_raise("Ruby2D::Ext.image_draw_quads failed to allocate geometry for %d quads", count);
      return R_NIL;
    }
    // Indices are address-independent and realloc preserves the prefix, so fill
    // only the freshly grown quads [quad_capacity, count).
    for (int i = quad_capacity; i < count; i++) {
      int v = i * 4;
      int x = i * 6;
      quad_indices[x + 0] = v + 0;
      quad_indices[x + 1] = v + 1;
      quad_indices[x + 2] = v + 2;
      quad_indices[x + 3] = v + 0;
      quad_indices[x + 4] = v + 2;
      quad_indices[x + 5] = v + 3;
    }
    quad_capacity = count;
  }

  for (int i = 0; i < count; i++) {
    R_VAL coords = r_ary_entry(coords_batch, i);
    R_VAL tex    = r_ary_entry(tex_coords_batch, i);
    int v = i * 4;

    quad_vertices[v + 0] = (SDL_Vertex){
      .position  = { NUM2DBL(r_ary_entry(coords, 0)), NUM2DBL(r_ary_entry(coords, 1)) },
      .color     = { cr, cg, cb, ca },
      .tex_coord = { NUM2DBL(r_ary_entry(tex, 0)), NUM2DBL(r_ary_entry(tex, 1)) }
    };
    quad_vertices[v + 1] = (SDL_Vertex){
      .position  = { NUM2DBL(r_ary_entry(coords, 2)), NUM2DBL(r_ary_entry(coords, 3)) },
      .color     = { cr, cg, cb, ca },
      .tex_coord = { NUM2DBL(r_ary_entry(tex, 2)), NUM2DBL(r_ary_entry(tex, 3)) }
    };
    quad_vertices[v + 2] = (SDL_Vertex){
      .position  = { NUM2DBL(r_ary_entry(coords, 4)), NUM2DBL(r_ary_entry(coords, 5)) },
      .color     = { cr, cg, cb, ca },
      .tex_coord = { NUM2DBL(r_ary_entry(tex, 4)), NUM2DBL(r_ary_entry(tex, 5)) }
    };
    quad_vertices[v + 3] = (SDL_Vertex){
      .position  = { NUM2DBL(r_ary_entry(coords, 6)), NUM2DBL(r_ary_entry(coords, 7)) },
      .color     = { cr, cg, cb, ca },
      .tex_coord = { NUM2DBL(r_ary_entry(tex, 6)), NUM2DBL(r_ary_entry(tex, 7)) }
    };
  }

  bool ok = SDL_RenderGeometry(R2D_GetRenderer(), img->texture,
                               quad_vertices, count * 4, quad_indices, count * 6);
  R2D_CheckSDL(ok, "SDL_RenderGeometry");

  return R_TRUE;
}


/*
 * Ruby2D::Image#ext_resize
 *
 * Re-rasterize the source at a new pixel size (see R2D_ImageReload) and write
 * the resulting size back onto the object.
 */
R_VAL ruby2d_ext_image_resize(RUBY2D_METHOD_ARGS_VARIADIC) {
  RUBY2D_EXTRACT_VARIADIC;
  if (argc != 3) r_raise("Ruby2D::Ext.image_resize expects 3 args (image, w, h), got %d", (int)argc);
  R_VAL obj   = argv[0];
  R_VAL w_val = argv[1];
  R_VAL h_val = argv[2];

  R2D_Image *img;
  obj_struct(obj, id_ext_image, R2D_Image, img);

  int new_w = (int)NUM2DBL(w_val);
  int new_h = (int)NUM2DBL(h_val);
  if (new_w <= 0 || new_h <= 0) {
    r_raise("Image#resize! requires positive width and height");
    return R_NIL;
  }

  if (!R2D_ImageReload(img, obj_str(obj, id_path), new_w, new_h,
                       R2D_ResolveSurfaceScaleMode(obj))) {
    r_raise("Image#resize! failed: %s", SDL_GetError());
    return R_NIL;
  }

  R2D_ImageSyncSize(obj, img);

  return R_TRUE;
}


/*
 * GC hook: the object's R2D_Image is released with it
 */
static void R2D_Image_free(void *p) {
  R2D_ImageDestroy((R2D_Image *)p);
}
#endif
