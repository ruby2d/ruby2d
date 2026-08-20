// canvas.c

#include "ruby2d.h"

R2D_DEFINE_DATA_TYPE(R2D_Canvas);

// Canvas-specific ivar IDs. Shared ivar IDs live in ext.c. Note that canvas
// uses @tint instead of @color, but the underlying r/g/b/a components are
// the shared ones.
static R_ID id_ext_canvas;
static R_ID id_tint;
static R_ID id_fill_r, id_fill_g, id_fill_b, id_fill_a;


/*
 * Initialize
 */
void R2D_Canvas_Init() {
  id_ext_canvas = r_id("@ext_canvas");
  id_tint       = r_id("@tint");
  id_fill_r     = r_id("@fill_r");
  id_fill_g     = r_id("@fill_g");
  id_fill_b     = r_id("@fill_b");
  id_fill_a     = r_id("@fill_a");

  r_define_class_method(ruby2d_ext_module, "canvas_create",             ruby2d_ext_canvas_create,             r_args_variadic);
  r_define_class_method(ruby2d_ext_module, "canvas_draw",               ruby2d_ext_canvas_draw,               r_args_variadic);
  r_define_class_method(ruby2d_ext_module, "canvas_clear",              ruby2d_ext_canvas_clear,              r_args_variadic);
  r_define_class_method(ruby2d_ext_module, "canvas_fill_triangle",      ruby2d_ext_canvas_fill_triangle,      r_args_variadic);
  r_define_class_method(ruby2d_ext_module, "canvas_fill_triangle_lerp", ruby2d_ext_canvas_fill_triangle_lerp, r_args_variadic);
  r_define_class_method(ruby2d_ext_module, "canvas_fill_rectangle",     ruby2d_ext_canvas_fill_rectangle,     r_args_variadic);
  r_define_class_method(ruby2d_ext_module, "canvas_fill_rectangles",    ruby2d_ext_canvas_fill_rectangles,    r_args_variadic);
  r_define_class_method(ruby2d_ext_module, "canvas_fill_pixel_grid",    ruby2d_ext_canvas_fill_pixel_grid,    r_args_variadic);
  r_define_class_method(ruby2d_ext_module, "canvas_fill_ellipse",       ruby2d_ext_canvas_fill_ellipse,       r_args_variadic);
  r_define_class_method(ruby2d_ext_module, "canvas_fill_polygon",       ruby2d_ext_canvas_fill_polygon,       r_args_variadic);
  r_define_class_method(ruby2d_ext_module, "canvas_fill_polygon_lerp",  ruby2d_ext_canvas_fill_polygon_lerp,  r_args_variadic);
  r_define_class_method(ruby2d_ext_module, "canvas_draw_line",          ruby2d_ext_canvas_draw_line,          r_args_variadic);
  r_define_class_method(ruby2d_ext_module, "canvas_draw_line_lerp",     ruby2d_ext_canvas_draw_line_lerp,     r_args_variadic);
  r_define_class_method(ruby2d_ext_module, "canvas_draw_lines",         ruby2d_ext_canvas_draw_lines,         r_args_variadic);
  r_define_class_method(ruby2d_ext_module, "canvas_stroke_polygon",     ruby2d_ext_canvas_stroke_polygon,     r_args_variadic);
  r_define_class_method(ruby2d_ext_module, "canvas_stroke_polyline",    ruby2d_ext_canvas_stroke_polyline,    r_args_variadic);
  r_define_class_method(ruby2d_ext_module, "canvas_draw_image",         ruby2d_ext_canvas_draw_image,         r_args_variadic);
  r_define_class_method(ruby2d_ext_module, "canvas_draw_text",          ruby2d_ext_canvas_draw_text,          r_args_variadic);
}


/*
 * Ruby2D::Canvas#ext_create
 */
R_VAL ruby2d_ext_canvas_create(RUBY2D_METHOD_ARGS_VARIADIC) {
  RUBY2D_EXTRACT_VARIADIC;
  if (argc != 2) r_raise("Ruby2D::Ext.canvas_create expects 2 args (canvas, logical), got %d", (int)argc);
  R_VAL obj = argv[0];
  bool logical = r_test(argv[1]);

  // Ensure SDL subsystems are initialized (display_scale is set in R2D_Init)
  if (!R2D_Init()) r_raise("Ruby2D: failed to initialize: %s", SDL_GetError());

  int width  = obj_int(obj, id_width);
  int height = obj_int(obj, id_height);

  /* Create the surface at physical pixel dimensions so canvas content is
     crisp on HiDPI displays. The Ruby-side width/height remain in logical
     coordinates; drawing methods scale inputs by the same factor.

     A Canvas captures its scale once, here, and never re-evaluates (unlike
     text, which re-rasterizes from its string when the scale changes — a
     Canvas holds the user's accumulated drawing and can't be recreated).
     Before `show` (the usual case) the window's asset scale doesn't yet
     reflect `pixel_scale` — R2D_ApplyPixelScale sets it when the window
     opens — so the Ruby side passes `logical` when the canvas should be
     built at 1:1 instead. Otherwise use the window's asset scale, or the
     init display scale (known since R2D_Init) if there's no window struct
     at all, so the common HiDPI case stays crisp. */
  float scale;
  if (logical) {
    scale = 1.0f;
  } else {
    scale = R2D_GetWindow() ? R2D_GetAssetScale() : R2D_GetInitDisplayScale();
  }
  int pixel_w = (int)(width  * scale);
  int pixel_h = (int)(height * scale);

  SDL_Surface *surface = SDL_CreateSurface(pixel_w, pixel_h, SDL_PIXELFORMAT_RGBA32);
  if (!surface) {
    r_raise("SDL_CreateSurface failed: %s", SDL_GetError());
    return R_NIL;
  }

  // Fill with the fill color
  float fr = obj_float(obj, id_fill_r);
  float fg = obj_float(obj, id_fill_g);
  float fb = obj_float(obj, id_fill_b);
  float fa = obj_float(obj, id_fill_a);

  Uint8 r = (Uint8)(fr * 255);
  Uint8 g = (Uint8)(fg * 255);
  Uint8 b = (Uint8)(fb * 255);
  Uint8 a = (Uint8)(fa * 255);

  Uint32 color = SDL_MapSurfaceRGBA(surface, r, g, b, a);
  SDL_FillSurfaceRect(surface, NULL, color);
  SDL_SetSurfaceBlendMode(surface, SDL_BLENDMODE_BLEND);

  R2D_Canvas *can = ALLOC(R2D_Canvas);
  can->surface = surface;
  can->texture = NULL;
  can->scale   = scale;
  can->dirty   = false;
  can->dirty_rect = (SDL_Rect){ 0, 0, 0, 0 };

  obj_set_struct(obj, id_ext_canvas, R2D_Canvas, can);

  return R_TRUE;
}


static void canvas_mark_dirty(R2D_Canvas *can, float min_x, float min_y,
                              float max_x, float max_y);
static void canvas_mark_dirty_all(R2D_Canvas *can);


/*
 * Ruby2D::Canvas#ext_draw
 */
R_VAL ruby2d_ext_canvas_draw(RUBY2D_METHOD_ARGS_VARIADIC) {
  RUBY2D_EXTRACT_VARIADIC;
  if (argc != 3) r_raise("Ruby2D::Ext.canvas_draw expects 3 args (canvas, rx, ry), got %d", (int)argc);
  R_VAL obj = argv[0];
  float crx = NUM2DBL(argv[1]);
  float cry = NUM2DBL(argv[2]);

  R2D_Canvas *can;
  obj_struct(obj, id_ext_canvas, R2D_Canvas, can);

  /* Create the persistent GPU texture on first draw. Created explicitly in
     the surface's pixel format (rather than SDL_CreateTextureFromSurface) so
     the incremental SDL_UpdateTexture uploads below can pass surface pixel
     rows through unconverted. The texture then lives for the canvas's
     lifetime — mutations upload into it instead of re-creating it. */
  if (can->texture == NULL) {
    can->texture = SDL_CreateTexture(R2D_GetRenderer(), SDL_PIXELFORMAT_RGBA32,
                                     SDL_TEXTUREACCESS_STATIC,
                                     can->surface->w, can->surface->h);
    if (!can->texture) {
      r_raise("SDL_CreateTexture failed: %s", SDL_GetError());
      return R_NIL;
    }
    SDL_SetTextureBlendMode(can->texture, SDL_BLENDMODE_BLEND);
    can->applied_scale_mode = SDL_SCALEMODE_INVALID;
    canvas_mark_dirty_all(can);  // populate with a full first upload
    // Don't destroy the surface — Canvas needs it for future draw operations
  }

  // Upload pending surface mutations — just the dirty union, not the whole
  // surface. A settled canvas skips this entirely.
  if (can->dirty) {
    const SDL_Rect *dr = &can->dirty_rect;
    const Uint8 *pixels = (const Uint8 *)can->surface->pixels
                        + (size_t)dr->y * can->surface->pitch
                        + (size_t)dr->x * 4;
    R2D_CheckSDL(SDL_UpdateTexture(can->texture, dr, pixels, can->surface->pitch),
                 "SDL_UpdateTexture");
    can->dirty = false;
  }

  R2D_ApplyScaleMode(can->texture, obj, &can->applied_scale_mode);

  SDL_FRect dst_rect = {
    obj_float(obj, id_x),
    obj_float(obj, id_y),
    obj_float(obj, id_width),
    obj_float(obj, id_height)
  };

  R_VAL color_obj = r_ivar_get(obj, id_tint);
  SDL_SetTextureColorModFloat(can->texture,
    NUM2DBL(r_ivar_get(color_obj, id_r)),
    NUM2DBL(r_ivar_get(color_obj, id_g)),
    NUM2DBL(r_ivar_get(color_obj, id_b))
  );
  SDL_SetTextureAlphaModFloat(can->texture, NUM2DBL(r_ivar_get(color_obj, id_a)));

  SDL_FPoint center = {
    crx - obj_float(obj, id_x),
    cry - obj_float(obj, id_y)
  };

  R2D_CheckSDL(SDL_RenderTextureRotated(
    R2D_GetRenderer(),
    can->texture,
    NULL,
    &dst_rect,
    obj_float(obj, id_rotate),
    &center,
    SDL_FLIP_NONE
  ), "SDL_RenderTextureRotated");

  return R_TRUE;
}


/*
 * Swap two float values
 */
static void swap_float(float *a, float *b) {
  float t = *a;
  *a = *b;
  *b = t;
}


/*
 * Composite a straight-alpha RGBA source over one RGBA8888 destination pixel,
 * in place, using Porter-Duff "over". Callers handle the opaque (a==255) fast
 * path; this is the partly-transparent case.
 *
 * The canvas stores straight (non-premultiplied) RGBA, so the blended color is
 * divided by the combined output coverage. When the destination is already
 * opaque (da==255) this reduces exactly — bit for bit — to the legacy
 * src*a + dst*(255-a) blend; only partly-transparent destinations (overlay
 * canvases) change, where the old math composited them too dark.
 */
static inline void canvas_blend_over(Uint8 *pixel, Uint8 r, Uint8 g, Uint8 b, Uint8 a) {
  Uint8 dr = pixel[0], dg = pixel[1], db = pixel[2], da = pixel[3];
  int inv = 255 - a;

  // Fast path: an opaque destination (the common case — painting onto a freshly
  // cleared opaque canvas) stays opaque, and "over" reduces bit for bit to the
  // legacy src*a + dst*(255-a) blend with a constant /255 divisor. The compiler
  // lowers that to a multiply+shift, dropping the three runtime divides below.
  if (da == 255) {
    pixel[0] = (Uint8)((r * a + dr * inv) / 255);
    pixel[1] = (Uint8)((g * a + dg * inv) / 255);
    pixel[2] = (Uint8)((b * a + db * inv) / 255);
    pixel[3] = 255;
    return;
  }

  int dst_w = da * inv / 255;        // destination coverage behind src: da*(1-a)
  int out_a = a + dst_w;             // combined src-over-dst coverage; divisor below
  if (out_a == 0) {                  // src and dst both fully transparent
    pixel[0] = pixel[1] = pixel[2] = pixel[3] = 0;
    return;
  }
  pixel[0] = (Uint8)((r * a + dr * dst_w) / out_a);
  pixel[1] = (Uint8)((g * a + dg * dst_w) / out_a);
  pixel[2] = (Uint8)((b * a + db * dst_w) / out_a);
  pixel[3] = (Uint8)out_a;
}


/*
 * Fill a triangle on an SDL_Surface using scanline rasterization.
 * Coordinates are in surface pixel space. Color components are 0-255.
 */
static void canvas_fill_triangle_on_surface(
    SDL_Surface *surface,
    float fx1, float fy1, float fx2, float fy2, float fx3, float fy3,
    Uint8 r, Uint8 g, Uint8 b, Uint8 a) {

  if (a == 0) return;  // fully transparent: nothing to draw

  // A non-finite vertex (NaN/Inf, e.g. from a degenerate user coordinate) would
  // make the (int)ceilf casts below undefined behavior and could index out of
  // the surface. Skip the draw, matching the no-op philosophy for degenerate
  // geometry elsewhere in this file.
  if (!isfinite(fx1) || !isfinite(fy1) || !isfinite(fx2) ||
      !isfinite(fy2) || !isfinite(fx3) || !isfinite(fy3)) return;

  // Sort vertices by y coordinate
  if (fy1 > fy2) { swap_float(&fx1, &fx2); swap_float(&fy1, &fy2); }
  if (fy1 > fy3) { swap_float(&fx1, &fx3); swap_float(&fy1, &fy3); }
  if (fy2 > fy3) { swap_float(&fx2, &fx3); swap_float(&fy2, &fy3); }

  // Half-open y coverage: row i is filled iff ceil(ymin) <= i < ceil(ymax),
  // matching the x-extent rule below and canvas_fill_rectangle_on_surface. Using
  // floorf here would close the interval and over-cover integer-aligned bottom
  // edges by one row (visible as 1px-too-thick horizontal lines at 2x scale).
  int top    = (int)ceilf(fy1);
  int middle = (int)ceilf(fy2);
  int bottom = (int)ceilf(fy3) - 1;

  if (top < 0) top = 0;
  if (bottom >= surface->h) bottom = surface->h - 1;

  float dy13 = fy3 - fy1;
  float dy12 = fy2 - fy1;
  float dy23 = fy3 - fy2;

  // The fill color is constant across the triangle, so pack it once (endian-safe
  // via SDL_MapSurfaceRGBA) and write opaque pixels with a single 32-bit store
  // instead of four byte stores.
  Uint32 packed = SDL_MapSurfaceRGBA(surface, r, g, b, 255);

  for (int y = top; y <= bottom; y++) {
    float xa, xb;

    // Long edge (v1 to v3)
    if (dy13 > 0.0f) {
      xa = fx1 + (fx3 - fx1) * ((float)y - fy1) / dy13;
    } else {
      xa = fx1;
    }

    // Short edge depends on top or bottom half
    if (y < middle) {
      if (dy12 > 0.0f) {
        xb = fx1 + (fx2 - fx1) * ((float)y - fy1) / dy12;
      } else {
        xb = fx1;
      }
    } else {
      if (dy23 > 0.0f) {
        xb = fx2 + (fx3 - fx2) * ((float)y - fy2) / dy23;
      } else {
        xb = fx2;
      }
    }

    int x_start = (int)ceilf(fminf(xa, xb));
    int x_end   = (int)ceilf(fmaxf(xa, xb)) - 1;

    if (x_start < 0) x_start = 0;
    if (x_end >= surface->w) x_end = surface->w - 1;

    // RGBA32 guarantees R,G,B,A byte order in memory
    Uint8 *row = (Uint8 *)surface->pixels + y * surface->pitch;
    for (int x = x_start; x <= x_end; x++) {
      Uint8 *pixel = row + x * 4;
      if (a == 255) {
        SDL_memcpy(pixel, &packed, 4);
      } else {
        canvas_blend_over(pixel, r, g, b, a);
      }
    }
  }
}


/*
 * Fill a triangle on an SDL_Surface with per-vertex color interpolation.
 * Uses barycentric coordinates to interpolate RGBA across the triangle.
 * Coordinates are in surface pixel space. Color components are 0-255.
 */
static void canvas_fill_triangle_lerp_on_surface(
    SDL_Surface *surface,
    float fx1, float fy1, Uint8 r1, Uint8 g1, Uint8 b1, Uint8 a1,
    float fx2, float fy2, Uint8 r2, Uint8 g2, Uint8 b2, Uint8 a2,
    float fx3, float fy3, Uint8 r3, Uint8 g3, Uint8 b3, Uint8 a3) {

  // Fully transparent: alpha interpolates linearly, so if all three vertices
  // are 0 every interior pixel is too. Skip before walking any scanline,
  // mirroring the solid rasterizer's `a == 0` early-out.
  if (a1 == 0 && a2 == 0 && a3 == 0) return;

  // A non-finite vertex (NaN/Inf) would make the (int)ceilf casts below
  // undefined behavior; skip the draw rather than risk an out-of-bounds write.
  if (!isfinite(fx1) || !isfinite(fy1) || !isfinite(fx2) ||
      !isfinite(fy2) || !isfinite(fx3) || !isfinite(fy3)) return;

  // Barycentric denominator (constant for the whole triangle)
  float denom = (fy2 - fy3) * (fx1 - fx3) + (fx3 - fx2) * (fy1 - fy3);
  if (fabsf(denom) < 0.0001f) return;
  float inv_denom = 1.0f / denom;

  // Sort vertices by y for scanline traversal (keep originals for barycentric)
  float sx1 = fx1, sy1 = fy1;
  float sx2 = fx2, sy2 = fy2;
  float sx3 = fx3, sy3 = fy3;

  if (sy1 > sy2) { swap_float(&sx1, &sx2); swap_float(&sy1, &sy2); }
  if (sy1 > sy3) { swap_float(&sx1, &sx3); swap_float(&sy1, &sy3); }
  if (sy2 > sy3) { swap_float(&sx2, &sx3); swap_float(&sy2, &sy3); }

  // Half-open y coverage (see canvas_fill_triangle_on_surface) — keeps the lerp
  // rasterizer consistent with the solid one and avoids over-covering integer-
  // aligned bottom edges by a row.
  int top    = (int)ceilf(sy1);
  int middle = (int)ceilf(sy2);
  int bottom = (int)ceilf(sy3) - 1;

  if (top < 0) top = 0;
  if (bottom >= surface->h) bottom = surface->h - 1;

  float dy13 = sy3 - sy1;
  float dy12 = sy2 - sy1;
  float dy23 = sy3 - sy2;

  for (int y = top; y <= bottom; y++) {
    float xa, xb;

    if (dy13 > 0.0f)
      xa = sx1 + (sx3 - sx1) * ((float)y - sy1) / dy13;
    else
      xa = sx1;

    if (y < middle) {
      if (dy12 > 0.0f)
        xb = sx1 + (sx2 - sx1) * ((float)y - sy1) / dy12;
      else
        xb = sx1;
    } else {
      if (dy23 > 0.0f)
        xb = sx2 + (sx3 - sx2) * ((float)y - sy2) / dy23;
      else
        xb = sx2;
    }

    int x_start = (int)ceilf(fminf(xa, xb));
    int x_end   = (int)ceilf(fmaxf(xa, xb)) - 1;

    if (x_start < 0) x_start = 0;
    if (x_end >= surface->w) x_end = surface->w - 1;

    Uint8 *row = (Uint8 *)surface->pixels + y * surface->pitch;
    for (int x = x_start; x <= x_end; x++) {
      // Barycentric weights from original (unsorted) vertices
      float w1 = ((fy2 - fy3) * ((float)x - fx3) + (fx3 - fx2) * ((float)y - fy3)) * inv_denom;
      float w2 = ((fy3 - fy1) * ((float)x - fx3) + (fx1 - fx3) * ((float)y - fy3)) * inv_denom;
      float w3 = 1.0f - w1 - w2;

      w1 = fminf(fmaxf(w1, 0.0f), 1.0f);
      w2 = fminf(fmaxf(w2, 0.0f), 1.0f);
      w3 = fminf(fmaxf(w3, 0.0f), 1.0f);

      Uint8 r = (Uint8)(w1 * r1 + w2 * r2 + w3 * r3);
      Uint8 g = (Uint8)(w1 * g1 + w2 * g2 + w3 * g3);
      Uint8 b = (Uint8)(w1 * b1 + w2 * b2 + w3 * b3);
      Uint8 a = (Uint8)(w1 * a1 + w2 * a2 + w3 * a3);

      Uint8 *pixel = row + x * 4;
      if (a == 255) {
        pixel[0] = r;
        pixel[1] = g;
        pixel[2] = b;
        pixel[3] = 255;
      } else if (a > 0) {
        canvas_blend_over(pixel, r, g, b, a);
      }
    }
  }
}


/*
 * Draw a thick line on an SDL_Surface as a quad (two triangles).
 * Coordinates are in surface pixel space. Color components are 0-255.
 */
static void canvas_draw_line_on_surface(
    SDL_Surface *surface,
    float x1, float y1, float x2, float y2,
    float width,
    Uint8 r, Uint8 g, Uint8 b, Uint8 a) {

  float dx = x2 - x1;
  float dy = y2 - y1;
  float len = sqrtf(dx * dx + dy * dy);

  if (len < 0.0001f) return;

  // Perpendicular unit vector scaled by half width
  float hw = width / 2.0f;
  float ox = (-dy / len) * hw;
  float oy = ( dx / len) * hw;

  // Four corners of the line quad
  float qx1 = x1 + ox, qy1 = y1 + oy;
  float qx2 = x1 - ox, qy2 = y1 - oy;
  float qx3 = x2 - ox, qy3 = y2 - oy;
  float qx4 = x2 + ox, qy4 = y2 + oy;

  canvas_fill_triangle_on_surface(surface, qx1, qy1, qx2, qy2, qx3, qy3, r, g, b, a);
  canvas_fill_triangle_on_surface(surface, qx1, qy1, qx3, qy3, qx4, qy4, r, g, b, a);
}


/*
 * Draw a thick line on an SDL_Surface as a quad with per-vertex colors.
 * The 4 colors map to corners: c1=start+perp, c2=start-perp, c3=end-perp,
 * c4=end+perp, matching R2D_DrawLine's vertex layout.
 */
static void canvas_draw_line_lerp_on_surface(
    SDL_Surface *surface,
    float x1, float y1, float x2, float y2,
    float width,
    Uint8 r1, Uint8 g1, Uint8 b1, Uint8 a1,
    Uint8 r2, Uint8 g2, Uint8 b2, Uint8 a2,
    Uint8 r3, Uint8 g3, Uint8 b3, Uint8 a3,
    Uint8 r4, Uint8 g4, Uint8 b4, Uint8 a4) {

  float dx = x2 - x1;
  float dy = y2 - y1;
  float len = sqrtf(dx * dx + dy * dy);

  if (len < 0.0001f) return;

  float hw = width / 2.0f;
  float ox = (-dy / len) * hw;
  float oy = ( dx / len) * hw;

  float qx1 = x1 + ox, qy1 = y1 + oy;
  float qx2 = x1 - ox, qy2 = y1 - oy;
  float qx3 = x2 - ox, qy3 = y2 - oy;
  float qx4 = x2 + ox, qy4 = y2 + oy;

  canvas_fill_triangle_lerp_on_surface(surface,
    qx1, qy1, r1, g1, b1, a1,
    qx2, qy2, r2, g2, b2, a2,
    qx3, qy3, r3, g3, b3, a3);
  canvas_fill_triangle_lerp_on_surface(surface,
    qx1, qy1, r1, g1, b1, a1,
    qx3, qy3, r3, g3, b3, a3,
    qx4, qy4, r4, g4, b4, a4);
}


/*
 * Lerp two Uint8 channel values at parameter t in [0, 1].
 */
static inline Uint8 lerp_u8(Uint8 a, Uint8 b, float t) {
  return (Uint8)((float)a + ((float)b - (float)a) * t + 0.5f);
}


/*
 * Stroke a polyline on an SDL_Surface with miter joins.
 * When closed is true, the last vertex connects back to the first.
 * When closed is false, endpoints get butt caps.
 * verts is [x0, y0, x1, y1, ...], n is the vertex count.
 * colors is n*4 Uint8s (rgba per vertex); outer/inner at each vertex share its
 * color, so per-edge quads interpolate between adjacent vertex colors.
 * Coordinates are in surface pixel space. Color components are 0-255.
 *
 * Outline geometry is computed by the shared R2D_ComputeStrokeOutline so
 * Canvas strokes match the GPU-side R2D_StrokePath at corners.
 */
static void canvas_stroke_polyline_on_surface(
    SDL_Surface *surface,
    float *verts, int n, int closed, float width,
    const Uint8 *colors) {

  if (n < 2) return;

  // Most strokes are small (triangle, quad, default circle), so serve the
  // outline buffers from the stack and fall back to the heap only past the
  // threshold — no malloc/free per call on the per-frame canvas paint path.
  float outer_stack[R2D_STROKE_STACK_N * 2];
  float inner_stack[R2D_STROKE_STACK_N * 2];
  float *outer, *inner;
  bool heap = n > R2D_STROKE_STACK_N;

  if (heap) {
    outer = (float *)malloc(n * 2 * sizeof(float));
    inner = (float *)malloc(n * 2 * sizeof(float));
    if (!outer || !inner) { free(outer); free(inner); return; }
  } else {
    outer = outer_stack;
    inner = inner_stack;
  }

  R2D_ComputeStrokeOutline(verts, n, closed, width, R2D_MITER_LIMIT, outer, inner);

  // Draw a quad for each edge segment
  int edges = closed ? n : n - 1;
  for (int i = 0; i < edges; i++) {
    int j = (i + 1) % n;

    Uint8 ri = colors[i * 4],     gi = colors[i * 4 + 1];
    Uint8 bi = colors[i * 4 + 2], ai = colors[i * 4 + 3];
    Uint8 rj = colors[j * 4],     gj = colors[j * 4 + 1];
    Uint8 bj = colors[j * 4 + 2], aj = colors[j * 4 + 3];

    canvas_fill_triangle_lerp_on_surface(surface,
      outer[i*2], outer[i*2+1], ri, gi, bi, ai,
      inner[i*2], inner[i*2+1], ri, gi, bi, ai,
      inner[j*2], inner[j*2+1], rj, gj, bj, aj);

    canvas_fill_triangle_lerp_on_surface(surface,
      outer[i*2], outer[i*2+1], ri, gi, bi, ai,
      inner[j*2], inner[j*2+1], rj, gj, bj, aj,
      outer[j*2], outer[j*2+1], rj, gj, bj, aj);
  }

  if (heap) {
    free(outer);
    free(inner);
  }
}


/*
 * Union a just-mutated surface region into the canvas's pending dirty rect so
 * the next ext_draw uploads it to the persistent GPU texture (the texture is
 * never destroyed on mutation — a full re-create + full-surface upload per
 * animated frame is exactly what made canvases expensive, especially on
 * WebGL). Also mark the next tick as needing a rendered frame so the mutation
 * is visible in :on_demand render mode without an explicit request_render
 * call. Tolerates being called before the window is shown (Canvases can be
 * drawn into pre-show); the dirty mark is a no-op in :continuous mode but the
 * atomic write is cheap.
 *
 * Bounds are floats in surface pixel space, any corner order. They are
 * expanded outward by one pixel so the differing edge conventions of the
 * rasterizers (ceil starts, inclusive vs half-open ends) are always covered —
 * a pixel of extra upload is harmless, a missed pixel is a stale texel.
 */
static void canvas_mark_dirty(R2D_Canvas *can, float min_x, float min_y,
                              float max_x, float max_y) {
  int x0, y0, x1, y1;

  // Non-finite bounds (NaN/Inf) make the int casts below undefined behavior;
  // fall back to the whole surface rather than guess.
  if (!isfinite(min_x) || !isfinite(min_y) || !isfinite(max_x) || !isfinite(max_y)) {
    x0 = 0; y0 = 0; x1 = can->surface->w; y1 = can->surface->h;
  } else {
    if (min_x > max_x) swap_float(&min_x, &max_x);
    if (min_y > max_y) swap_float(&min_y, &max_y);
    x0 = (int)floorf(min_x) - 1;
    y0 = (int)floorf(min_y) - 1;
    x1 = (int)ceilf(max_x) + 1;
    y1 = (int)ceilf(max_y) + 1;
    if (x0 < 0) x0 = 0;
    if (y0 < 0) y0 = 0;
    if (x1 > can->surface->w) x1 = can->surface->w;
    if (y1 > can->surface->h) y1 = can->surface->h;
    if (x0 >= x1 || y0 >= y1) return;  // fully off-surface: nothing uploaded
  }

  if (can->dirty) {
    int ex1 = can->dirty_rect.x + can->dirty_rect.w;
    int ey1 = can->dirty_rect.y + can->dirty_rect.h;
    if (x0 > can->dirty_rect.x) x0 = can->dirty_rect.x;
    if (y0 > can->dirty_rect.y) y0 = can->dirty_rect.y;
    if (x1 < ex1) x1 = ex1;
    if (y1 < ey1) y1 = ey1;
  } else {
    can->dirty = true;
  }
  can->dirty_rect.x = x0;
  can->dirty_rect.y = y0;
  can->dirty_rect.w = x1 - x0;
  can->dirty_rect.h = y1 - y0;

  if (R2D_GetWindow()) {
    SDL_SetAtomicInt(&R2D_GetWindow()->render_pending, 1);
  }
}


/*
 * Mark the entire surface dirty — the first draw populates the fresh texture
 * with a full upload of everything drawn pre-show.
 */
static void canvas_mark_dirty_all(R2D_Canvas *can) {
  canvas_mark_dirty(can, 0.0f, 0.0f,
                    (float)can->surface->w, (float)can->surface->h);
}


/*
 * Mark the bounding box of a vertex list ([x0, y0, x1, y1, ...], surface
 * pixel space) dirty, expanded by `pad` on every side — for strokes, whose
 * geometry extends beyond the vertices (up to half-width * miter limit at a
 * miter join).
 */
static void canvas_mark_dirty_verts(R2D_Canvas *can, const float *verts,
                                    int n, float pad) {
  float min_x = verts[0], min_y = verts[1];
  float max_x = verts[0], max_y = verts[1];
  for (int i = 1; i < n; i++) {
    float x = verts[i * 2];
    float y = verts[i * 2 + 1];
    if (x < min_x) min_x = x;
    if (x > max_x) max_x = x;
    if (y < min_y) min_y = y;
    if (y > max_y) max_y = y;
  }
  canvas_mark_dirty(can, min_x - pad, min_y - pad, max_x + pad, max_y + pad);
}


/*
 * Ruby2D::Canvas#ext_fill_triangle
 * Arguments: [x1, y1, x2, y2, x3, y3, r, g, b, a]
 */
R_VAL ruby2d_ext_canvas_fill_triangle(RUBY2D_METHOD_ARGS_VARIADIC) {
  RUBY2D_EXTRACT_VARIADIC;
  if (argc != 11) r_raise("Ruby2D::Ext.canvas_fill_triangle expects 11 args, got %d", (int)argc);
  R_VAL obj = argv[0];

  R2D_Canvas *can;
  obj_struct(obj, id_ext_canvas, R2D_Canvas, can);

  float scale = can->scale;
  float x1 = (float)NUM2DBL(argv[1]) * scale;
  float y1 = (float)NUM2DBL(argv[2]) * scale;
  float x2 = (float)NUM2DBL(argv[3]) * scale;
  float y2 = (float)NUM2DBL(argv[4]) * scale;
  float x3 = (float)NUM2DBL(argv[5]) * scale;
  float y3 = (float)NUM2DBL(argv[6]) * scale;
  float r  = (float)NUM2DBL(argv[7]);
  float g  = (float)NUM2DBL(argv[8]);
  float b  = (float)NUM2DBL(argv[9]);
  float af = (float)NUM2DBL(argv[10]);

  Uint8 cr = (Uint8)(r * 255);
  Uint8 cg = (Uint8)(g * 255);
  Uint8 cb = (Uint8)(b * 255);
  Uint8 ca = (Uint8)(af * 255);

  if (ca == 0) return R_TRUE;  // fully transparent: skip lock and texture rebuild

  SDL_LockSurface(can->surface);
  canvas_fill_triangle_on_surface(can->surface, x1, y1, x2, y2, x3, y3, cr, cg, cb, ca);
  SDL_UnlockSurface(can->surface);

  canvas_mark_dirty(can,
    fminf(x1, fminf(x2, x3)), fminf(y1, fminf(y2, y3)),
    fmaxf(x1, fmaxf(x2, x3)), fmaxf(y1, fmaxf(y2, y3)));

  return R_TRUE;
}


/*
 * Ruby2D::Canvas#ext_fill_triangle_lerp
 * Arguments: [x1, y1, r1, g1, b1, a1, x2, y2, r2, g2, b2, a2, x3, y3, r3, g3, b3, a3]
 * Each vertex has its own color; colors are interpolated across the triangle.
 */
R_VAL ruby2d_ext_canvas_fill_triangle_lerp(RUBY2D_METHOD_ARGS_VARIADIC) {
  RUBY2D_EXTRACT_VARIADIC;
  if (argc != 2) r_raise("Ruby2D::Ext.canvas_fill_triangle_lerp expects 2 args, got %d", (int)argc);
  R_VAL obj = argv[0];
  R_VAL a   = argv[1];

  R2D_Canvas *can;
  obj_struct(obj, id_ext_canvas, R2D_Canvas, can);

  float scale = can->scale;

  float x1 = (float)NUM2DBL(r_ary_entry(a, 0))  * scale;
  float y1 = (float)NUM2DBL(r_ary_entry(a, 1))  * scale;
  float r1 = (float)NUM2DBL(r_ary_entry(a, 2));
  float g1 = (float)NUM2DBL(r_ary_entry(a, 3));
  float b1 = (float)NUM2DBL(r_ary_entry(a, 4));
  float a1 = (float)NUM2DBL(r_ary_entry(a, 5));

  float x2 = (float)NUM2DBL(r_ary_entry(a, 6))  * scale;
  float y2 = (float)NUM2DBL(r_ary_entry(a, 7))  * scale;
  float r2 = (float)NUM2DBL(r_ary_entry(a, 8));
  float g2 = (float)NUM2DBL(r_ary_entry(a, 9));
  float b2 = (float)NUM2DBL(r_ary_entry(a, 10));
  float a2 = (float)NUM2DBL(r_ary_entry(a, 11));

  float x3 = (float)NUM2DBL(r_ary_entry(a, 12)) * scale;
  float y3 = (float)NUM2DBL(r_ary_entry(a, 13)) * scale;
  float r3 = (float)NUM2DBL(r_ary_entry(a, 14));
  float g3 = (float)NUM2DBL(r_ary_entry(a, 15));
  float b3 = (float)NUM2DBL(r_ary_entry(a, 16));
  float a3 = (float)NUM2DBL(r_ary_entry(a, 17));

  SDL_LockSurface(can->surface);
  canvas_fill_triangle_lerp_on_surface(can->surface,
    x1, y1, (Uint8)(r1 * 255), (Uint8)(g1 * 255), (Uint8)(b1 * 255), (Uint8)(a1 * 255),
    x2, y2, (Uint8)(r2 * 255), (Uint8)(g2 * 255), (Uint8)(b2 * 255), (Uint8)(a2 * 255),
    x3, y3, (Uint8)(r3 * 255), (Uint8)(g3 * 255), (Uint8)(b3 * 255), (Uint8)(a3 * 255));
  SDL_UnlockSurface(can->surface);

  canvas_mark_dirty(can,
    fminf(x1, fminf(x2, x3)), fminf(y1, fminf(y2, y3)),
    fmaxf(x1, fmaxf(x2, x3)), fmaxf(y1, fmaxf(y2, y3)));

  return R_TRUE;
}


/*
 * Fill a rectangle on an SDL_Surface.
 * Coordinates are in surface pixel space (pre-scaled). Color components are 0-255.
 * Opaque fills use SDL_FillSurfaceRect; semi-transparent fills alpha-blend
 * per pixel (surface is locked internally for that path).
 */
static void canvas_fill_rectangle_on_surface(
    SDL_Surface *surface,
    float fx, float fy, float fw, float fh,
    Uint8 cr, Uint8 cg, Uint8 cb, Uint8 ca) {

  // A non-finite coordinate or size (NaN/Inf) makes the (int)ceilf casts below
  // undefined behavior and could produce an out-of-bounds rect. Skip the draw.
  if (!isfinite(fx) || !isfinite(fy) || !isfinite(fw) || !isfinite(fh)) return;

  // Half-open pixel coverage: a rect (x, y, w, h) covers the continuous
  // region [x, x+w) x [y, y+h), so pixel i is filled iff ceil(x) <= i < ceil(x+w).
  // Matches the ceilf convention used by the triangle rasterizer, so
  // fill_rectangle and draw_line share pixel edges for non-integer inputs.
  int rx = (int)ceilf(fx);
  int ry = (int)ceilf(fy);
  int rw = (int)ceilf(fx + fw) - rx;
  int rh = (int)ceilf(fy + fh) - ry;
  SDL_Rect rect = { rx, ry, rw, rh };

  if (ca == 255) {
    // Opaque — use fast SDL fill
    Uint32 color = SDL_MapSurfaceRGBA(surface, cr, cg, cb, 255);
    SDL_FillSurfaceRect(surface, &rect, color);
  } else if (ca > 0) {
    // Semi-transparent — alpha blend per pixel
    // Clamp rect to surface bounds
    int x_start = rx < 0 ? 0 : rx;
    int y_start = ry < 0 ? 0 : ry;
    int x_end = rx + rw;
    int y_end = ry + rh;
    if (x_end > surface->w) x_end = surface->w;
    if (y_end > surface->h) y_end = surface->h;

    SDL_LockSurface(surface);
    for (int y = y_start; y < y_end; y++) {
      Uint8 *row = (Uint8 *)surface->pixels + y * surface->pitch;
      for (int x = x_start; x < x_end; x++) {
        Uint8 *pixel = row + x * 4;
        canvas_blend_over(pixel, cr, cg, cb, ca);
      }
    }
    SDL_UnlockSurface(surface);
  }
}


/*
 * Ruby2D::Canvas#ext_fill_rectangle
 * Arguments: [x, y, width, height, r, g, b, a]
 */
R_VAL ruby2d_ext_canvas_fill_rectangle(RUBY2D_METHOD_ARGS_VARIADIC) {
  RUBY2D_EXTRACT_VARIADIC;
  if (argc != 9) r_raise("Ruby2D::Ext.canvas_fill_rectangle expects 9 args, got %d", (int)argc);
  R_VAL obj = argv[0];

  R2D_Canvas *can;
  obj_struct(obj, id_ext_canvas, R2D_Canvas, can);

  float scale = can->scale;
  float fx = (float)NUM2DBL(argv[1]) * scale;
  float fy = (float)NUM2DBL(argv[2]) * scale;
  float fw = (float)NUM2DBL(argv[3]) * scale;
  float fh = (float)NUM2DBL(argv[4]) * scale;
  float rf = (float)NUM2DBL(argv[5]);
  float gf = (float)NUM2DBL(argv[6]);
  float bf = (float)NUM2DBL(argv[7]);
  float af = (float)NUM2DBL(argv[8]);

  Uint8 cr = (Uint8)(rf * 255);
  Uint8 cg = (Uint8)(gf * 255);
  Uint8 cb = (Uint8)(bf * 255);
  Uint8 ca = (Uint8)(af * 255);

  if (ca == 0) return R_TRUE;  // fully transparent: skip fill and texture rebuild

  canvas_fill_rectangle_on_surface(can->surface, fx, fy, fw, fh, cr, cg, cb, ca);
  canvas_mark_dirty(can, fx, fy, fx + fw, fy + fh);

  return R_TRUE;
}


/*
 * Ruby2D::Canvas#ext_fill_rectangles
 * Arguments: [n, x1, y1, w1, h1, x2, y2, w2, h2, ..., r, g, b, a]
 * Fills n rectangles with a single shared color in one FFI crossing.
 */
R_VAL ruby2d_ext_canvas_fill_rectangles(RUBY2D_METHOD_ARGS_VARIADIC) {
  RUBY2D_EXTRACT_VARIADIC;
  if (argc != 2) r_raise("Ruby2D::Ext.canvas_fill_rectangles expects 2 args, got %d", (int)argc);
  R_VAL obj = argv[0];
  R_VAL a   = argv[1];

  R2D_Canvas *can;
  obj_struct(obj, id_ext_canvas, R2D_Canvas, can);

  if ((int)r_ary_len(a) < 1) return R_TRUE;
  int n = (int)NUM2INT(r_ary_entry(a, 0));
  if (n < 1) return R_TRUE;

  // Guard the array length: [count] + n*[x,y,w,h] + [r,g,b,a]. A short array
  // would make r_ary_entry return nil and NUM2DBL(nil) error (mruby aborts).
  long need = 5L + (long)n * 4;
  if ((long)r_ary_len(a) < need)
    r_raise("Ruby2D::Ext.canvas_fill_rectangles: array has %d values for %d rects (need %ld)",
            (int)r_ary_len(a), n, need);

  int base = 1 + n * 4;
  float rf = (float)NUM2DBL(r_ary_entry(a, base));
  float gf = (float)NUM2DBL(r_ary_entry(a, base + 1));
  float bf = (float)NUM2DBL(r_ary_entry(a, base + 2));
  float af = (float)NUM2DBL(r_ary_entry(a, base + 3));

  Uint8 cr = (Uint8)(rf * 255);
  Uint8 cg = (Uint8)(gf * 255);
  Uint8 cb = (Uint8)(bf * 255);
  Uint8 ca = (Uint8)(af * 255);

  if (ca == 0) return R_TRUE;

  float scale = can->scale;
  for (int i = 0; i < n; i++) {
    int o = 1 + i * 4;
    float fx = (float)NUM2DBL(r_ary_entry(a, o))     * scale;
    float fy = (float)NUM2DBL(r_ary_entry(a, o + 1)) * scale;
    float fw = (float)NUM2DBL(r_ary_entry(a, o + 2)) * scale;
    float fh = (float)NUM2DBL(r_ary_entry(a, o + 3)) * scale;
    canvas_fill_rectangle_on_surface(can->surface, fx, fy, fw, fh, cr, cg, cb, ca);
    canvas_mark_dirty(can, fx, fy, fx + fw, fy + fh);
  }

  return R_TRUE;
}


/*
 * Ruby2D::Canvas#ext_fill_pixel_grid
 * Arguments:
 *   header = [cols, rows, cell_w, cell_h, ox, oy]
 *   colors = flat array of cols*rows*4 floats in 0..1
 *            (r0, g0, b0, a0, r1, g1, b1, a1, ...)
 * Fills a regular cols x rows grid of equal-size rectangles, each with its
 * own RGBA color. Cell (col, row) is the rect at
 * (ox + col*cell_w, oy + row*cell_h, cell_w, cell_h), colored by
 * colors[(row*cols + col)*4 .. +3]. Single FFI crossing for the whole grid:
 * one surface lock, one texture invalidate, cells with a==0 skipped.
 */
R_VAL ruby2d_ext_canvas_fill_pixel_grid(RUBY2D_METHOD_ARGS_VARIADIC) {
  RUBY2D_EXTRACT_VARIADIC;
  if (argc != 3) r_raise("Ruby2D::Ext.canvas_fill_pixel_grid expects 3 args, got %d", (int)argc);
  R_VAL obj    = argv[0];
  R_VAL header = argv[1];
  R_VAL colors = argv[2];

  R2D_Canvas *can;
  obj_struct(obj, id_ext_canvas, R2D_Canvas, can);

  // Guard array lengths before the read loops: a short array would make
  // r_ary_entry return nil and NUM2DBL/NUM2INT(nil) error (hard-abort on mruby).
  if ((int)r_ary_len(header) < 6)
    r_raise("Ruby2D::Ext.canvas_fill_pixel_grid: header needs 6 values, got %d",
            (int)r_ary_len(header));

  int cols = (int)NUM2INT(r_ary_entry(header, 0));
  int rows = (int)NUM2INT(r_ary_entry(header, 1));
  if (cols < 1 || rows < 1) return R_TRUE;

  long need = (long)cols * rows * 4;
  if ((long)r_ary_len(colors) < need)
    r_raise("Ruby2D::Ext.canvas_fill_pixel_grid: %d color values for a %dx%d grid (need %ld)",
            (int)r_ary_len(colors), cols, rows, need);

  float scale  = can->scale;
  float cell_w = (float)NUM2DBL(r_ary_entry(header, 2)) * scale;
  float cell_h = (float)NUM2DBL(r_ary_entry(header, 3)) * scale;
  float ox     = (float)NUM2DBL(r_ary_entry(header, 4)) * scale;
  float oy     = (float)NUM2DBL(r_ary_entry(header, 5)) * scale;

  // A non-finite cell size or origin (NaN/Inf) would make the per-cell
  // (int)ceilf casts below undefined behavior; every cell derives from these
  // four values, so skip the whole grid.
  if (!isfinite(cell_w) || !isfinite(cell_h) || !isfinite(ox) || !isfinite(oy))
    return R_TRUE;

  SDL_Surface *surface = can->surface;

  SDL_LockSurface(surface);
  for (int gr = 0; gr < rows; gr++) {
    for (int gc = 0; gc < cols; gc++) {
      int o = (gr * cols + gc) * 4;
      // Clamp channels to [0,1] before the 8-bit cast. This is the one
      // user-facing color path that builds no Color object, so it has no
      // Ruby-side clamp; an out-of-range value would wrap (1.5 -> 126) rather
      // than saturate.
      float af = (float)NUM2DBL(r_ary_entry(colors, o + 3));
      if (af < 0.0f) af = 0.0f; else if (af > 1.0f) af = 1.0f;
      Uint8 ca = (Uint8)(af * 255);
      if (ca == 0) continue;

      float rf = (float)NUM2DBL(r_ary_entry(colors, o));
      float gf = (float)NUM2DBL(r_ary_entry(colors, o + 1));
      float bf = (float)NUM2DBL(r_ary_entry(colors, o + 2));
      if (rf < 0.0f) rf = 0.0f; else if (rf > 1.0f) rf = 1.0f;
      if (gf < 0.0f) gf = 0.0f; else if (gf > 1.0f) gf = 1.0f;
      if (bf < 0.0f) bf = 0.0f; else if (bf > 1.0f) bf = 1.0f;
      Uint8 cr = (Uint8)(rf * 255);
      Uint8 cg = (Uint8)(gf * 255);
      Uint8 cb = (Uint8)(bf * 255);

      // Half-open pixel coverage, matching canvas_fill_rectangle_on_surface
      float fx = ox + gc * cell_w;
      float fy = oy + gr * cell_h;
      int rx = (int)ceilf(fx);
      int ry = (int)ceilf(fy);
      int rw = (int)ceilf(fx + cell_w) - rx;
      int rh = (int)ceilf(fy + cell_h) - ry;

      int x_start = rx < 0 ? 0 : rx;
      int y_start = ry < 0 ? 0 : ry;
      int x_end = rx + rw;
      int y_end = ry + rh;
      if (x_end > surface->w) x_end = surface->w;
      if (y_end > surface->h) y_end = surface->h;

      if (ca == 255) {
        // Color is constant within the cell: pack once, store 32 bits per pixel.
        Uint32 packed = SDL_MapSurfaceRGBA(surface, cr, cg, cb, 255);
        for (int y = y_start; y < y_end; y++) {
          Uint8 *row = (Uint8 *)surface->pixels + y * surface->pitch;
          for (int x = x_start; x < x_end; x++) {
            Uint8 *pixel = row + x * 4;
            SDL_memcpy(pixel, &packed, 4);
          }
        }
      } else {
        for (int y = y_start; y < y_end; y++) {
          Uint8 *row = (Uint8 *)surface->pixels + y * surface->pitch;
          for (int x = x_start; x < x_end; x++) {
            Uint8 *pixel = row + x * 4;
            canvas_blend_over(pixel, cr, cg, cb, ca);
          }
        }
      }
    }
  }
  SDL_UnlockSurface(surface);

  canvas_mark_dirty(can, ox, oy, ox + cols * cell_w, oy + rows * cell_h);

  return R_TRUE;
}


/*
 * Ruby2D::Canvas#ext_fill_ellipse
 * Arguments: [x, y, xradius, yradius, r, g, b, a]
 */
R_VAL ruby2d_ext_canvas_fill_ellipse(RUBY2D_METHOD_ARGS_VARIADIC) {
  RUBY2D_EXTRACT_VARIADIC;
  if (argc != 9) r_raise("Ruby2D::Ext.canvas_fill_ellipse expects 9 args, got %d", (int)argc);
  R_VAL obj = argv[0];

  R2D_Canvas *can;
  obj_struct(obj, id_ext_canvas, R2D_Canvas, can);

  float scale   = can->scale;
  float cx      = (float)NUM2DBL(argv[1]) * scale;
  float cy      = (float)NUM2DBL(argv[2]) * scale;
  float xradius = (float)NUM2DBL(argv[3]) * scale;
  float yradius = (float)NUM2DBL(argv[4]) * scale;
  float rf      = (float)NUM2DBL(argv[5]);
  float gf      = (float)NUM2DBL(argv[6]);
  float bf      = (float)NUM2DBL(argv[7]);
  float af      = (float)NUM2DBL(argv[8]);

  Uint8 cr = (Uint8)(rf * 255);
  Uint8 cg = (Uint8)(gf * 255);
  Uint8 cb = (Uint8)(bf * 255);
  Uint8 ca = (Uint8)(af * 255);

  if (ca == 0) return R_TRUE;

  // A non-finite center or radius (NaN/Inf) would make the (int)ceilf/floorf
  // casts below undefined behavior (and `radius <= 0` does not catch NaN, since
  // every NaN comparison is false). Skip the draw before the scanline math.
  if (!isfinite(cx) || !isfinite(cy) || !isfinite(xradius) || !isfinite(yradius))
    return R_TRUE;

  // A zero (or negative) radius has no area to fill. Guard before the scanline
  // math below: yradius == 0 makes yr2 == 0, so (dy * dy) / yr2 is 0.0 / 0.0 ==
  // NaN, and converting the resulting NaN pixel bounds to int is undefined
  // behavior that produces an out-of-bounds heap write.
  if (xradius <= 0.0f || yradius <= 0.0f) return R_TRUE;

  SDL_Surface *surface = can->surface;
  float yr2 = yradius * yradius;

  int y_start = (int)ceilf(cy - yradius);
  int y_end   = (int)floorf(cy + yradius);
  if (y_start < 0) y_start = 0;
  if (y_end >= surface->h) y_end = surface->h - 1;

  // The fill color is constant across the ellipse, so pack it once and write
  // opaque pixels with a single 32-bit store instead of four byte stores.
  Uint32 packed = SDL_MapSurfaceRGBA(surface, cr, cg, cb, 255);

  SDL_LockSurface(surface);
  for (int y = y_start; y <= y_end; y++) {
    float dy = (float)y - cy;
    // Boundary-row float rounding can push (dy*dy)/yr2 just above 1.0, making
    // the radicand negative; sqrtf would yield NaN and (int)ceilf(NaN) is UB.
    float t = 1.0f - (dy * dy) / yr2;
    if (t < 0.0f) t = 0.0f;
    float dx = xradius * sqrtf(t);
    int x_start = (int)ceilf(cx - dx);
    int x_end   = (int)floorf(cx + dx);
    if (x_start < 0) x_start = 0;
    if (x_end >= surface->w) x_end = surface->w - 1;

    Uint8 *row = (Uint8 *)surface->pixels + y * surface->pitch;
    for (int x = x_start; x <= x_end; x++) {
      Uint8 *pixel = row + x * 4;
      if (ca == 255) {
        SDL_memcpy(pixel, &packed, 4);
      } else {
        canvas_blend_over(pixel, cr, cg, cb, ca);
      }
    }
  }
  SDL_UnlockSurface(surface);

  canvas_mark_dirty(can, cx - xradius, cy - yradius, cx + xradius, cy + yradius);

  return R_TRUE;
}


/*
 * Ruby2D::Canvas#ext_fill_polygon
 * Arguments: [n, x1, y1, x2, y2, ..., r, g, b, a]
 * Uses ear-clipping triangulation (R2D_TriangulatePolygon) so concave
 * polygons fill correctly.
 */
R_VAL ruby2d_ext_canvas_fill_polygon(RUBY2D_METHOD_ARGS_VARIADIC) {
  RUBY2D_EXTRACT_VARIADIC;
  if (argc != 2) r_raise("Ruby2D::Ext.canvas_fill_polygon expects 2 args, got %d", (int)argc);
  R_VAL obj = argv[0];
  R_VAL a   = argv[1];

  R2D_Canvas *can;
  obj_struct(obj, id_ext_canvas, R2D_Canvas, can);

  if ((int)r_ary_len(a) < 1) return R_TRUE;
  int n = (int)NUM2INT(r_ary_entry(a, 0));
  if (n < 3) return R_TRUE;

  // [n, x1, y1, ... xn, yn, r, g, b, a] — guard before indexing (a short array
  // would hard-abort under mruby), matching the sibling fill_* methods.
  long need = 1 + (long)n * 2 + 4;
  if ((long)r_ary_len(a) < need)
    r_raise("Ruby2D::Ext.canvas_fill_polygon: array has %d values for %d vertices (need %ld)",
            (int)r_ary_len(a), n, need);

  float scale = can->scale;
  float *verts = (float *)malloc(n * 2 * sizeof(float));
  if (!verts) return R_TRUE;

  for (int i = 0; i < n; i++) {
    verts[i*2]   = (float)NUM2DBL(r_ary_entry(a, 1 + i*2)) * scale;
    verts[i*2+1] = (float)NUM2DBL(r_ary_entry(a, 2 + i*2)) * scale;
  }

  int base = 1 + n * 2;
  float rf = (float)NUM2DBL(r_ary_entry(a, base));
  float gf = (float)NUM2DBL(r_ary_entry(a, base + 1));
  float bf = (float)NUM2DBL(r_ary_entry(a, base + 2));
  float af = (float)NUM2DBL(r_ary_entry(a, base + 3));

  Uint8 cr = (Uint8)(rf * 255);
  Uint8 cg = (Uint8)(gf * 255);
  Uint8 cb = (Uint8)(bf * 255);
  Uint8 ca = (Uint8)(af * 255);

  if (ca > 0) {
    int tri_count = 0;
    int *indices = R2D_TriangulatePolygon(verts, n, &tri_count);
    if (indices && tri_count > 0) {
      SDL_LockSurface(can->surface);
      for (int t = 0; t < tri_count; t++) {
        int i1 = indices[t * 3];
        int i2 = indices[t * 3 + 1];
        int i3 = indices[t * 3 + 2];
        canvas_fill_triangle_on_surface(can->surface,
          verts[i1*2], verts[i1*2+1],
          verts[i2*2], verts[i2*2+1],
          verts[i3*2], verts[i3*2+1],
          cr, cg, cb, ca);
      }
      SDL_UnlockSurface(can->surface);
      canvas_mark_dirty_verts(can, verts, n, 0.0f);
    }
    free(indices);
  }

  free(verts);
  return R_TRUE;
}


/*
 * Ruby2D::Canvas#ext_fill_polygon_lerp
 * Arguments: [n, x1, y1, r1, g1, b1, a1, x2, y2, r2, g2, b2, a2, ...]
 * Per-vertex colors. Triangulated via ear clipping; each emitted triangle
 * is rasterized with barycentric color interpolation between its three
 * source vertices' colors.
 */
R_VAL ruby2d_ext_canvas_fill_polygon_lerp(RUBY2D_METHOD_ARGS_VARIADIC) {
  RUBY2D_EXTRACT_VARIADIC;
  if (argc != 2) r_raise("Ruby2D::Ext.canvas_fill_polygon_lerp expects 2 args, got %d", (int)argc);
  R_VAL obj = argv[0];
  R_VAL a   = argv[1];

  R2D_Canvas *can;
  obj_struct(obj, id_ext_canvas, R2D_Canvas, can);

  if ((int)r_ary_len(a) < 1) return R_TRUE;
  int n = (int)NUM2INT(r_ary_entry(a, 0));
  if (n < 3) return R_TRUE;

  // [n, x1, y1, r1, g1, b1, a1, ...] — 6 entries per vertex. Guard before
  // indexing (a short array would hard-abort under mruby).
  long need = 1 + (long)n * 6;
  if ((long)r_ary_len(a) < need)
    r_raise("Ruby2D::Ext.canvas_fill_polygon_lerp: array has %d values for %d vertices (need %ld)",
            (int)r_ary_len(a), n, need);

  float scale = can->scale;
  float *verts  = (float *)malloc(n * 2 * sizeof(float));
  Uint8 *colors = (Uint8 *)malloc(n * 4 * sizeof(Uint8));
  if (!verts || !colors) { free(verts); free(colors); return R_TRUE; }

  // Each vertex packs as (x, y, r, g, b, a) — 6 entries.
  for (int i = 0; i < n; i++) {
    int o = 1 + i * 6;
    verts[i*2]     = (float)NUM2DBL(r_ary_entry(a, o))     * scale;
    verts[i*2+1]   = (float)NUM2DBL(r_ary_entry(a, o + 1)) * scale;
    colors[i*4]    = (Uint8)((float)NUM2DBL(r_ary_entry(a, o + 2)) * 255);
    colors[i*4+1]  = (Uint8)((float)NUM2DBL(r_ary_entry(a, o + 3)) * 255);
    colors[i*4+2]  = (Uint8)((float)NUM2DBL(r_ary_entry(a, o + 4)) * 255);
    colors[i*4+3]  = (Uint8)((float)NUM2DBL(r_ary_entry(a, o + 5)) * 255);
  }

  int tri_count = 0;
  int *indices = R2D_TriangulatePolygon(verts, n, &tri_count);
  if (indices && tri_count > 0) {
    SDL_LockSurface(can->surface);
    for (int t = 0; t < tri_count; t++) {
      int i1 = indices[t * 3];
      int i2 = indices[t * 3 + 1];
      int i3 = indices[t * 3 + 2];
      canvas_fill_triangle_lerp_on_surface(can->surface,
        verts[i1*2], verts[i1*2+1],
        colors[i1*4], colors[i1*4+1], colors[i1*4+2], colors[i1*4+3],
        verts[i2*2], verts[i2*2+1],
        colors[i2*4], colors[i2*4+1], colors[i2*4+2], colors[i2*4+3],
        verts[i3*2], verts[i3*2+1],
        colors[i3*4], colors[i3*4+1], colors[i3*4+2], colors[i3*4+3]);
    }
    SDL_UnlockSurface(can->surface);
    canvas_mark_dirty_verts(can, verts, n, 0.0f);
  }
  free(indices);

  free(verts);
  free(colors);
  return R_TRUE;
}


/*
 * Ruby2D::Canvas#ext_draw_line
 * Arguments: [x1, y1, x2, y2, stroke_width, r, g, b, a, dash, gap]
 * When dash > 0, draws a dashed line; otherwise a solid line.
 */
R_VAL ruby2d_ext_canvas_draw_line(RUBY2D_METHOD_ARGS_VARIADIC) {
  RUBY2D_EXTRACT_VARIADIC;
  if (argc != 12) r_raise("Ruby2D::Ext.canvas_draw_line expects 12 args, got %d", (int)argc);
  R_VAL obj = argv[0];

  R2D_Canvas *can;
  obj_struct(obj, id_ext_canvas, R2D_Canvas, can);

  float scale = can->scale;
  float x1 = (float)NUM2DBL(argv[1]) * scale;
  float y1 = (float)NUM2DBL(argv[2]) * scale;
  float x2 = (float)NUM2DBL(argv[3]) * scale;
  float y2 = (float)NUM2DBL(argv[4]) * scale;
  float sw = (float)NUM2DBL(argv[5]) * scale;
  float rf = (float)NUM2DBL(argv[6]);
  float gf = (float)NUM2DBL(argv[7]);
  float bf = (float)NUM2DBL(argv[8]);
  float af = (float)NUM2DBL(argv[9]);
  float dash = (float)NUM2DBL(argv[10]) * scale;
  float gap  = (float)NUM2DBL(argv[11]) * scale;

  Uint8 cr = (Uint8)(rf * 255);
  Uint8 cg = (Uint8)(gf * 255);
  Uint8 cb = (Uint8)(bf * 255);
  Uint8 ca = (Uint8)(af * 255);

  if (ca == 0) return R_TRUE;

  SDL_LockSurface(can->surface);

  if (dash > 0.0f) {
    if (dash < 0.5f) dash = 0.5f;
    if (gap  < 0.5f) gap  = 0.5f;

    float dx  = x2 - x1;
    float dy  = y2 - y1;
    float len = sqrtf(dx * dx + dy * dy);
    if (len >= 0.0001f) {
      float ux = dx / len;
      float uy = dy / len;

      float t = 0.0f;
      int drawing = 1;
      while (t < len) {
        float seg = drawing ? dash : gap;
        if (t + seg > len) seg = len - t;

        if (drawing) {
          float sx1 = x1 + ux * t;
          float sy1 = y1 + uy * t;
          float sx2 = x1 + ux * (t + seg);
          float sy2 = y1 + uy * (t + seg);
          canvas_draw_line_on_surface(can->surface, sx1, sy1, sx2, sy2, sw, cr, cg, cb, ca);
        }

        t += seg;
        drawing = !drawing;
      }
    }
  } else {
    canvas_draw_line_on_surface(can->surface, x1, y1, x2, y2, sw, cr, cg, cb, ca);
  }

  SDL_UnlockSurface(can->surface);
  {
    float hw = sw * 0.5f;
    canvas_mark_dirty(can, fminf(x1, x2) - hw, fminf(y1, y2) - hw,
                           fmaxf(x1, x2) + hw, fmaxf(y1, y2) + hw);
  }

  return R_TRUE;
}


/*
 * Ruby2D::Canvas#ext_draw_line_lerp
 * Arguments: [x1, y1, x2, y2, stroke_width,
 *             r1, g1, b1, a1, r2, g2, b2, a2,
 *             r3, g3, b3, a3, r4, g4, b4, a4,
 *             dash, gap]
 * 4 per-corner colors mirror R2D_DrawLine's vertex layout
 * (c1=start+perp, c2=start-perp, c3=end-perp, c4=end+perp). When dash > 0,
 * draws a dashed line and interpolates endpoint colors along the length.
 */
R_VAL ruby2d_ext_canvas_draw_line_lerp(RUBY2D_METHOD_ARGS_VARIADIC) {
  RUBY2D_EXTRACT_VARIADIC;
  if (argc != 2) r_raise("Ruby2D::Ext.canvas_draw_line_lerp expects 2 args, got %d", (int)argc);
  R_VAL obj = argv[0];
  R_VAL a   = argv[1];

  R2D_Canvas *can;
  obj_struct(obj, id_ext_canvas, R2D_Canvas, can);

  float scale = can->scale;
  float x1 = (float)NUM2DBL(r_ary_entry(a, 0)) * scale;
  float y1 = (float)NUM2DBL(r_ary_entry(a, 1)) * scale;
  float x2 = (float)NUM2DBL(r_ary_entry(a, 2)) * scale;
  float y2 = (float)NUM2DBL(r_ary_entry(a, 3)) * scale;
  float sw = (float)NUM2DBL(r_ary_entry(a, 4)) * scale;

  Uint8 r1 = (Uint8)(NUM2DBL(r_ary_entry(a,  5)) * 255);
  Uint8 g1 = (Uint8)(NUM2DBL(r_ary_entry(a,  6)) * 255);
  Uint8 b1 = (Uint8)(NUM2DBL(r_ary_entry(a,  7)) * 255);
  Uint8 a1 = (Uint8)(NUM2DBL(r_ary_entry(a,  8)) * 255);
  Uint8 r2 = (Uint8)(NUM2DBL(r_ary_entry(a,  9)) * 255);
  Uint8 g2 = (Uint8)(NUM2DBL(r_ary_entry(a, 10)) * 255);
  Uint8 b2 = (Uint8)(NUM2DBL(r_ary_entry(a, 11)) * 255);
  Uint8 a2 = (Uint8)(NUM2DBL(r_ary_entry(a, 12)) * 255);
  Uint8 r3 = (Uint8)(NUM2DBL(r_ary_entry(a, 13)) * 255);
  Uint8 g3 = (Uint8)(NUM2DBL(r_ary_entry(a, 14)) * 255);
  Uint8 b3 = (Uint8)(NUM2DBL(r_ary_entry(a, 15)) * 255);
  Uint8 a3 = (Uint8)(NUM2DBL(r_ary_entry(a, 16)) * 255);
  Uint8 r4 = (Uint8)(NUM2DBL(r_ary_entry(a, 17)) * 255);
  Uint8 g4 = (Uint8)(NUM2DBL(r_ary_entry(a, 18)) * 255);
  Uint8 b4 = (Uint8)(NUM2DBL(r_ary_entry(a, 19)) * 255);
  Uint8 a4 = (Uint8)(NUM2DBL(r_ary_entry(a, 20)) * 255);

  float dash = (float)NUM2DBL(r_ary_entry(a, 21)) * scale;
  float gap  = (float)NUM2DBL(r_ary_entry(a, 22)) * scale;

  SDL_LockSurface(can->surface);

  if (dash > 0.0f) {
    if (dash < 0.5f) dash = 0.5f;
    if (gap  < 0.5f) gap  = 0.5f;

    float dx  = x2 - x1;
    float dy  = y2 - y1;
    float len = sqrtf(dx * dx + dy * dy);
    if (len >= 0.0001f) {
      float ux = dx / len;
      float uy = dy / len;

      float t = 0.0f;
      int drawing = 1;
      while (t < len) {
        float seg = drawing ? dash : gap;
        if (t + seg > len) seg = len - t;

        if (drawing) {
          float t1 = t / len;
          float t2 = (t + seg) / len;

          // Top edge (c1->c4) and bottom edge (c2->c3) interpolated at t1,t2
          Uint8 sr1 = lerp_u8(r1, r4, t1), sg1 = lerp_u8(g1, g4, t1);
          Uint8 sb1 = lerp_u8(b1, b4, t1), sa1 = lerp_u8(a1, a4, t1);
          Uint8 er1 = lerp_u8(r1, r4, t2), eg1 = lerp_u8(g1, g4, t2);
          Uint8 eb1 = lerp_u8(b1, b4, t2), ea1 = lerp_u8(a1, a4, t2);

          Uint8 sr2 = lerp_u8(r2, r3, t1), sg2 = lerp_u8(g2, g3, t1);
          Uint8 sb2 = lerp_u8(b2, b3, t1), sa2 = lerp_u8(a2, a3, t1);
          Uint8 er2 = lerp_u8(r2, r3, t2), eg2 = lerp_u8(g2, g3, t2);
          Uint8 eb2 = lerp_u8(b2, b3, t2), ea2 = lerp_u8(a2, a3, t2);

          float sx1 = x1 + ux * t,         sy1 = y1 + uy * t;
          float sx2 = x1 + ux * (t + seg), sy2 = y1 + uy * (t + seg);

          canvas_draw_line_lerp_on_surface(can->surface, sx1, sy1, sx2, sy2, sw,
            sr1, sg1, sb1, sa1,
            sr2, sg2, sb2, sa2,
            er2, eg2, eb2, ea2,
            er1, eg1, eb1, ea1);
        }

        t += seg;
        drawing = !drawing;
      }
    }
  } else {
    canvas_draw_line_lerp_on_surface(can->surface, x1, y1, x2, y2, sw,
      r1, g1, b1, a1,
      r2, g2, b2, a2,
      r3, g3, b3, a3,
      r4, g4, b4, a4);
  }

  SDL_UnlockSurface(can->surface);
  {
    float hw = sw * 0.5f;
    canvas_mark_dirty(can, fminf(x1, x2) - hw, fminf(y1, y2) - hw,
                           fmaxf(x1, x2) + hw, fmaxf(y1, y2) + hw);
  }

  return R_TRUE;
}


/*
 * Ruby2D::Canvas#ext_draw_lines
 * Arguments: [n, x1a, y1a, x2a, y2a, x1b, y1b, x2b, y2b, ..., stroke_width, r, g, b, a]
 * Draws n line segments with a single shared color and stroke width in one
 * FFI crossing.
 */
R_VAL ruby2d_ext_canvas_draw_lines(RUBY2D_METHOD_ARGS_VARIADIC) {
  RUBY2D_EXTRACT_VARIADIC;
  if (argc != 2) r_raise("Ruby2D::Ext.canvas_draw_lines expects 2 args, got %d", (int)argc);
  R_VAL obj = argv[0];
  R_VAL a   = argv[1];

  R2D_Canvas *can;
  obj_struct(obj, id_ext_canvas, R2D_Canvas, can);

  int n = (int)NUM2INT(r_ary_entry(a, 0));
  if (n < 1) return R_TRUE;

  float scale = can->scale;
  int base = 1 + n * 4;
  float sw = (float)NUM2DBL(r_ary_entry(a, base))     * scale;
  float rf = (float)NUM2DBL(r_ary_entry(a, base + 1));
  float gf = (float)NUM2DBL(r_ary_entry(a, base + 2));
  float bf = (float)NUM2DBL(r_ary_entry(a, base + 3));
  float af = (float)NUM2DBL(r_ary_entry(a, base + 4));

  Uint8 cr = (Uint8)(rf * 255);
  Uint8 cg = (Uint8)(gf * 255);
  Uint8 cb = (Uint8)(bf * 255);
  Uint8 ca = (Uint8)(af * 255);

  if (ca == 0) return R_TRUE;

  float hw = sw * 0.5f;
  SDL_LockSurface(can->surface);
  for (int i = 0; i < n; i++) {
    int o = 1 + i * 4;
    float x1 = (float)NUM2DBL(r_ary_entry(a, o))     * scale;
    float y1 = (float)NUM2DBL(r_ary_entry(a, o + 1)) * scale;
    float x2 = (float)NUM2DBL(r_ary_entry(a, o + 2)) * scale;
    float y2 = (float)NUM2DBL(r_ary_entry(a, o + 3)) * scale;
    canvas_draw_line_on_surface(can->surface, x1, y1, x2, y2, sw, cr, cg, cb, ca);
    canvas_mark_dirty(can, fminf(x1, x2) - hw, fminf(y1, y2) - hw,
                           fmaxf(x1, x2) + hw, fmaxf(y1, y2) + hw);
  }
  SDL_UnlockSurface(can->surface);

  return R_TRUE;
}


/*
 * Shared body for stroke_polygon/stroke_polyline. `vbase` is the array index
 * of the first vertex coordinate (the leading args differ between the two);
 * `closed` joins the last vertex back to the first.
 */
static R_VAL canvas_stroke_impl(R2D_Canvas *can, R_VAL a, int n, int vbase, int closed) {
  if (n < 2) return R_TRUE;

  float scale = can->scale;
  // Small strokes use stack scratch; heap only past the threshold.
  float verts_stack[R2D_STROKE_STACK_N * 2];
  Uint8 colors_stack[R2D_STROKE_STACK_N * 4];
  float *verts;
  Uint8 *colors;
  bool heap = n > R2D_STROKE_STACK_N;

  if (heap) {
    verts = (float *)malloc(n * 2 * sizeof(float));
    colors = (Uint8 *)malloc(n * 4 * sizeof(Uint8));
    if (!verts || !colors) { free(verts); free(colors); return R_TRUE; }
  } else {
    verts = verts_stack;
    colors = colors_stack;
  }

  for (int i = 0; i < n; i++) {
    verts[i*2]   = (float)NUM2DBL(r_ary_entry(a, vbase + i*2)) * scale;
    verts[i*2+1] = (float)NUM2DBL(r_ary_entry(a, vbase + 1 + i*2)) * scale;
  }

  int base = vbase + n * 2;
  float sw = (float)NUM2DBL(r_ary_entry(a, base)) * scale;

  int has_any_alpha = 0;
  for (int i = 0; i < n; i++) {
    colors[i*4]     = (Uint8)(NUM2DBL(r_ary_entry(a, base + 1 + i*4))     * 255);
    colors[i*4 + 1] = (Uint8)(NUM2DBL(r_ary_entry(a, base + 2 + i*4))     * 255);
    colors[i*4 + 2] = (Uint8)(NUM2DBL(r_ary_entry(a, base + 3 + i*4))     * 255);
    colors[i*4 + 3] = (Uint8)(NUM2DBL(r_ary_entry(a, base + 4 + i*4))     * 255);
    if (colors[i*4 + 3] > 0) has_any_alpha = 1;
  }

  if (has_any_alpha) {
    SDL_LockSurface(can->surface);
    canvas_stroke_polyline_on_surface(can->surface, verts, n, closed, sw, colors);
    SDL_UnlockSurface(can->surface);
    // Miter joins extend past the vertices by up to hw * R2D_MITER_LIMIT
    canvas_mark_dirty_verts(can, verts, n, 0.5f * sw * R2D_MITER_LIMIT);
  }

  if (heap) {
    free(verts);
    free(colors);
  }
  return R_TRUE;
}


/*
 * Ruby2D::Canvas#ext_stroke_polygon
 * Arguments: [n, x1, y1, x2, y2, ..., stroke_width, r1,g1,b1,a1, ...rn,gn,bn,an]
 */
R_VAL ruby2d_ext_canvas_stroke_polygon(RUBY2D_METHOD_ARGS_VARIADIC) {
  RUBY2D_EXTRACT_VARIADIC;
  if (argc != 2) r_raise("Ruby2D::Ext.canvas_stroke_polygon expects 2 args, got %d", (int)argc);
  R_VAL obj = argv[0];
  R_VAL a   = argv[1];

  R2D_Canvas *can;
  obj_struct(obj, id_ext_canvas, R2D_Canvas, can);

  int n = (int)NUM2INT(r_ary_entry(a, 0));
  return canvas_stroke_impl(can, a, n, 1, 1);
}


/*
 * Ruby2D::Canvas#ext_stroke_polyline
 * Arguments: [closed, n, x1, y1, x2, y2, ..., stroke_width, r1,g1,b1,a1, ...rn,gn,bn,an]
 */
R_VAL ruby2d_ext_canvas_stroke_polyline(RUBY2D_METHOD_ARGS_VARIADIC) {
  RUBY2D_EXTRACT_VARIADIC;
  if (argc != 2) r_raise("Ruby2D::Ext.canvas_stroke_polyline expects 2 args, got %d", (int)argc);
  R_VAL obj = argv[0];
  R_VAL a   = argv[1];

  R2D_Canvas *can;
  obj_struct(obj, id_ext_canvas, R2D_Canvas, can);

  int closed = (int)NUM2INT(r_ary_entry(a, 0));
  int n      = (int)NUM2INT(r_ary_entry(a, 1));
  return canvas_stroke_impl(can, a, n, 2, closed);
}


/*
 * Ruby2D::Canvas#ext_draw_image
 * Blit an Image's SDL_Surface onto this Canvas's SDL_Surface.
 * Arguments: img_obj (Ruby2D::Image), a = [x, y, width, height]
 */
R_VAL ruby2d_ext_canvas_draw_image(RUBY2D_METHOD_ARGS_VARIADIC) {
  RUBY2D_EXTRACT_VARIADIC;
  if (argc != 3) r_raise("Ruby2D::Ext.canvas_draw_image expects 3 args (canvas, image, params), got %d", (int)argc);
  R_VAL obj     = argv[0];
  R_VAL img_obj = argv[1];
  R_VAL a       = argv[2];

  R2D_Canvas *can;
  obj_struct(obj, id_ext_canvas, R2D_Canvas, can);

  // Get the R2D_Image struct from the Image object's @ext_image ivar. Guard
  // against a nil/absent handle (wrong object type, or a failed Image) before
  // dereferencing — r_data_ptr on a non-data value would otherwise crash.
  R_VAL ext_image_val = r_ivar_get(img_obj, id_ext_image);
  if (!r_test(ext_image_val)) {
    r_error("Canvas#draw_image requires a valid Ruby2D::Image");
    return R_NIL;
  }
  R2D_Image *img = (R2D_Image *)r_data_ptr(ext_image_val);

  if (!img->surface) {
    r_error("Image surface is not available for canvas blitting");
    return R_NIL;
  }

  float scale = can->scale;
  int dx = (int)(NUM2DBL(r_ary_entry(a, 0)) * scale);
  int dy = (int)(NUM2DBL(r_ary_entry(a, 1)) * scale);
  int dw = (int)(NUM2DBL(r_ary_entry(a, 2)) * scale);
  int dh = (int)(NUM2DBL(r_ary_entry(a, 3)) * scale);

  // Nothing to draw for a degenerate (zero/negative) destination rect.
  if (dw <= 0 || dh <= 0) return R_TRUE;

  SDL_Rect dst_rect = { dx, dy, dw, dh };

  // The source image's mode, not the canvas's: a :nearest sprite stamped
  // into a :linear canvas stays crisp.
  SDL_SetSurfaceBlendMode(img->surface, SDL_BLENDMODE_BLEND);
  SDL_BlitSurfaceScaled(img->surface, NULL, can->surface, &dst_rect,
                        R2D_ResolveSurfaceScaleMode(img_obj));

  canvas_mark_dirty(can, (float)dx, (float)dy, (float)(dx + dw), (float)(dy + dh));

  return R_TRUE;
}


/*
 * Ruby2D::Canvas#ext_draw_text
 * Blit a Text's SDL_Surface onto this Canvas's SDL_Surface with color modulation.
 * Arguments: txt_obj (Ruby2D::Text), a = [x, y, width, height, r, g, b, a]
 */
R_VAL ruby2d_ext_canvas_draw_text(RUBY2D_METHOD_ARGS_VARIADIC) {
  RUBY2D_EXTRACT_VARIADIC;
  if (argc != 3) r_raise("Ruby2D::Ext.canvas_draw_text expects 3 args (canvas, text, params), got %d", (int)argc);
  R_VAL obj     = argv[0];
  R_VAL txt_obj = argv[1];
  R_VAL a       = argv[2];

  R2D_Canvas *can;
  obj_struct(obj, id_ext_canvas, R2D_Canvas, can);

  // Get the R2D_Text struct from the Text object's @ext_text ivar. Guard
  // against a nil/absent handle (wrong object type, or a failed Text) before
  // dereferencing — r_data_ptr on a non-data value would otherwise crash.
  R_VAL ext_text_val = r_ivar_get(txt_obj, id_ext_text);
  if (!r_test(ext_text_val)) {
    r_error("Canvas#draw_text requires a valid Ruby2D::Text");
    return R_NIL;
  }
  R2D_Text *txt = (R2D_Text *)r_data_ptr(ext_text_val);

  if (txt->empty) return R_TRUE;  // empty content: nothing to blit

  if (!txt->surface) {
    r_error("Text surface is not available for canvas blitting");
    return R_NIL;
  }

  float scale = can->scale;
  int dx = (int)(NUM2DBL(r_ary_entry(a, 0)) * scale);
  int dy = (int)(NUM2DBL(r_ary_entry(a, 1)) * scale);
  int dw = (int)(NUM2DBL(r_ary_entry(a, 2)) * scale);
  int dh = (int)(NUM2DBL(r_ary_entry(a, 3)) * scale);

  // Nothing to draw for a degenerate (zero/negative) destination rect.
  if (dw <= 0 || dh <= 0) return R_TRUE;

  float rf = (float)NUM2DBL(r_ary_entry(a, 4));
  float gf = (float)NUM2DBL(r_ary_entry(a, 5));
  float bf = (float)NUM2DBL(r_ary_entry(a, 6));
  float af = (float)NUM2DBL(r_ary_entry(a, 7));

  // Apply color/alpha modulation to tint the white text surface
  SDL_SetSurfaceColorMod(txt->surface, (Uint8)(rf * 255), (Uint8)(gf * 255), (Uint8)(bf * 255));
  SDL_SetSurfaceAlphaMod(txt->surface, (Uint8)(af * 255));
  SDL_SetSurfaceBlendMode(txt->surface, SDL_BLENDMODE_BLEND);

  SDL_Rect dst_rect = { dx, dy, dw, dh };
  SDL_BlitSurfaceScaled(txt->surface, NULL, can->surface, &dst_rect,
                        R2D_ResolveSurfaceScaleMode(txt_obj));

  // Reset color/alpha mod to defaults so GPU rendering is unaffected
  SDL_SetSurfaceColorMod(txt->surface, 255, 255, 255);
  SDL_SetSurfaceAlphaMod(txt->surface, 255);

  canvas_mark_dirty(can, (float)dx, (float)dy, (float)(dx + dw), (float)(dy + dh));

  return R_TRUE;
}


/*
 * Ruby2D::Canvas#ext_clear
 * Arguments: [r, g, b, a, x, y, width, height]
 * Resets pixels on the surface to the given color (no blending).
 * When x/y are 0 and width/height match the surface, clears the entire canvas.
 */
R_VAL ruby2d_ext_canvas_clear(RUBY2D_METHOD_ARGS_VARIADIC) {
  RUBY2D_EXTRACT_VARIADIC;
  if (argc != 2) r_raise("Ruby2D::Ext.canvas_clear expects 2 args, got %d", (int)argc);
  R_VAL obj = argv[0];
  R_VAL a   = argv[1];

  R2D_Canvas *can;
  obj_struct(obj, id_ext_canvas, R2D_Canvas, can);

  Uint8 cr = (Uint8)((float)NUM2DBL(r_ary_entry(a, 0)) * 255);
  Uint8 cg = (Uint8)((float)NUM2DBL(r_ary_entry(a, 1)) * 255);
  Uint8 cb = (Uint8)((float)NUM2DBL(r_ary_entry(a, 2)) * 255);
  Uint8 ca = (Uint8)((float)NUM2DBL(r_ary_entry(a, 3)) * 255);

  float scale = can->scale;
  int rx = (int)(NUM2DBL(r_ary_entry(a, 4)) * scale);
  int ry = (int)(NUM2DBL(r_ary_entry(a, 5)) * scale);
  int rw = (int)(NUM2DBL(r_ary_entry(a, 6)) * scale);
  int rh = (int)(NUM2DBL(r_ary_entry(a, 7)) * scale);

  Uint32 color = SDL_MapSurfaceRGBA(can->surface, cr, cg, cb, ca);

  // If the rect covers the entire surface, pass NULL for a full clear
  if (rx == 0 && ry == 0 && rw == can->surface->w && rh == can->surface->h) {
    SDL_FillSurfaceRect(can->surface, NULL, color);
  } else {
    SDL_Rect rect = { rx, ry, rw, rh };
    SDL_FillSurfaceRect(can->surface, &rect, color);
  }

  canvas_mark_dirty(can, (float)rx, (float)ry, (float)(rx + rw), (float)(ry + rh));

  return R_TRUE;
}


/*
 * Free canvas
 */
static void R2D_Canvas_free(void *p) {
  if (!p) return;
  R2D_Canvas *can = (R2D_Canvas *)p;
  if (can->surface) {
    SDL_DestroySurface(can->surface);
    can->surface = NULL;
  }
  if (can->texture) {
    if (R2D_RendererAlive()) SDL_DestroyTexture(can->texture);
    can->texture = NULL;
  }
  xfree(can);
}
