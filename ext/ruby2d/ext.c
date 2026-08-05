// ext.c
//
// Ruby2D::Ext — Ruby-callable bindings exposing libruby2d C primitives.
// Per-shape Ruby code calls these directly instead of having C functions
// reach into Ruby objects via r_ivar_get. Keeps SDL3-touching code in C
// and per-frame logic in Ruby.
//
// Fixed-arity shapes (Triangle, Quad, Line, Circle, Ellipse) use positional
// float args. Variadic shapes (Polygon, Polyline) take Ruby arrays for
// vertex and color buffers since the count is not known at bind time.

#include "ruby2d.h"


// File-scope storage for the Ext module so subsystem .c files (audio, image,
// text, etc.) can register their own Ext bindings on it without re-creating it.
R_CLASS ruby2d_ext_module;

// Shared ivar ID cache. Subsystem .c files use these instead of caching their
// own per-file copies — same Ruby ivar name, same R_ID across subsystems. The
// IDs are interned during R2D_Ext_Init (which runs first), so they're ready
// when subsequent subsystem inits execute.
R_ID id_x, id_y, id_width, id_height, id_rotate;
R_ID id_color, id_r, id_g, id_b, id_a;
R_ID id_ext_image, id_ext_text;
R_ID id_path, id_content;
R_ID id_viewport_width, id_viewport_height;


// Fixed-arity shape bindings //////////////////////////////////////////////////


/*
 * Ruby2D::Ext.draw_triangle(
 *   x1, y1, r1, g1, b1, a1,
 *   x2, y2, r2, g2, b2, a2,
 *   x3, y3, r3, g3, b3, a3
 * )
 */
R_VAL ruby2d_ext_draw_triangle(RUBY2D_METHOD_ARGS_VARIADIC) {
  RUBY2D_EXTRACT_VARIADIC;
  if (argc != 18) r_raise("Ruby2D::Ext.draw_triangle expects 18 args, got %d", (int)argc);

  R2D_DrawTriangle(
    NUM2DBL(argv[0]),  NUM2DBL(argv[1]),
    NUM2DBL(argv[2]),  NUM2DBL(argv[3]),  NUM2DBL(argv[4]),  NUM2DBL(argv[5]),

    NUM2DBL(argv[6]),  NUM2DBL(argv[7]),
    NUM2DBL(argv[8]),  NUM2DBL(argv[9]),  NUM2DBL(argv[10]), NUM2DBL(argv[11]),

    NUM2DBL(argv[12]), NUM2DBL(argv[13]),
    NUM2DBL(argv[14]), NUM2DBL(argv[15]), NUM2DBL(argv[16]), NUM2DBL(argv[17])
  );

  return R_NIL;
}


/*
 * Ruby2D::Ext.draw_triangle_uniform(x1, y1, x2, y2, x3, y3, r, g, b, a)
 *
 * Solid (single-color) triangle: one rgba is replicated to all three vertices,
 * so a uniform Triangle passes 10 args instead of 18 and skips the per-vertex
 * color marshaling. Geometry is identical to draw_triangle with equal colors.
 */
R_VAL ruby2d_ext_draw_triangle_uniform(RUBY2D_METHOD_ARGS_VARIADIC) {
  RUBY2D_EXTRACT_VARIADIC;
  if (argc != 10) r_raise("Ruby2D::Ext.draw_triangle_uniform expects 10 args, got %d", (int)argc);

  float r = NUM2DBL(argv[6]);
  float g = NUM2DBL(argv[7]);
  float b = NUM2DBL(argv[8]);
  float a = NUM2DBL(argv[9]);

  R2D_DrawTriangle(
    NUM2DBL(argv[0]), NUM2DBL(argv[1]), r, g, b, a,
    NUM2DBL(argv[2]), NUM2DBL(argv[3]), r, g, b, a,
    NUM2DBL(argv[4]), NUM2DBL(argv[5]), r, g, b, a
  );

  return R_NIL;
}


/*
 * Ruby2D::Ext.stroke_triangle(
 *   x1, y1, x2, y2, x3, y3,
 *   stroke_width,
 *   r1, g1, b1, a1,
 *   r2, g2, b2, a2,
 *   r3, g3, b3, a3
 * )
 */
R_VAL ruby2d_ext_stroke_triangle(RUBY2D_METHOD_ARGS_VARIADIC) {
  RUBY2D_EXTRACT_VARIADIC;
  if (argc != 19) r_raise("Ruby2D::Ext.stroke_triangle expects 19 args, got %d", (int)argc);

  float pts[6] = {
    NUM2DBL(argv[0]), NUM2DBL(argv[1]),
    NUM2DBL(argv[2]), NUM2DBL(argv[3]),
    NUM2DBL(argv[4]), NUM2DBL(argv[5])
  };
  float sw = NUM2DBL(argv[6]);
  float colors[12] = {
    NUM2DBL(argv[7]),  NUM2DBL(argv[8]),  NUM2DBL(argv[9]),  NUM2DBL(argv[10]),
    NUM2DBL(argv[11]), NUM2DBL(argv[12]), NUM2DBL(argv[13]), NUM2DBL(argv[14]),
    NUM2DBL(argv[15]), NUM2DBL(argv[16]), NUM2DBL(argv[17]), NUM2DBL(argv[18])
  };

  R2D_StrokePath(pts, 3, 1, sw, R2D_MITER_LIMIT, colors);

  return R_NIL;
}


/*
 * Ruby2D::Ext.stroke_triangle_uniform(x1, y1, x2, y2, x3, y3, sw, r, g, b, a)
 *
 * Solid (single-color) triangle outline: one rgba replicated to all three
 * vertices, so a uniform stroke passes 11 args instead of 19.
 */
R_VAL ruby2d_ext_stroke_triangle_uniform(RUBY2D_METHOD_ARGS_VARIADIC) {
  RUBY2D_EXTRACT_VARIADIC;
  if (argc != 11) r_raise("Ruby2D::Ext.stroke_triangle_uniform expects 11 args, got %d", (int)argc);

  float pts[6] = {
    NUM2DBL(argv[0]), NUM2DBL(argv[1]),
    NUM2DBL(argv[2]), NUM2DBL(argv[3]),
    NUM2DBL(argv[4]), NUM2DBL(argv[5])
  };
  float sw = NUM2DBL(argv[6]);
  float r = NUM2DBL(argv[7]), g = NUM2DBL(argv[8]), b = NUM2DBL(argv[9]), a = NUM2DBL(argv[10]);
  float colors[12] = { r,g,b,a, r,g,b,a, r,g,b,a };

  R2D_StrokePath(pts, 3, 1, sw, R2D_MITER_LIMIT, colors);

  return R_NIL;
}


/*
 * Ruby2D::Ext.draw_quad(
 *   x1, y1, r1, g1, b1, a1,
 *   x2, y2, r2, g2, b2, a2,
 *   x3, y3, r3, g3, b3, a3,
 *   x4, y4, r4, g4, b4, a4
 * )
 */
R_VAL ruby2d_ext_draw_quad(RUBY2D_METHOD_ARGS_VARIADIC) {
  RUBY2D_EXTRACT_VARIADIC;
  if (argc != 24) r_raise("Ruby2D::Ext.draw_quad expects 24 args, got %d", (int)argc);

  R2D_DrawQuad(
    NUM2DBL(argv[0]),  NUM2DBL(argv[1]),
    NUM2DBL(argv[2]),  NUM2DBL(argv[3]),  NUM2DBL(argv[4]),  NUM2DBL(argv[5]),

    NUM2DBL(argv[6]),  NUM2DBL(argv[7]),
    NUM2DBL(argv[8]),  NUM2DBL(argv[9]),  NUM2DBL(argv[10]), NUM2DBL(argv[11]),

    NUM2DBL(argv[12]), NUM2DBL(argv[13]),
    NUM2DBL(argv[14]), NUM2DBL(argv[15]), NUM2DBL(argv[16]), NUM2DBL(argv[17]),

    NUM2DBL(argv[18]), NUM2DBL(argv[19]),
    NUM2DBL(argv[20]), NUM2DBL(argv[21]), NUM2DBL(argv[22]), NUM2DBL(argv[23])
  );

  return R_NIL;
}


/*
 * Ruby2D::Ext.draw_quad_uniform(x1, y1, x2, y2, x3, y3, x4, y4, r, g, b, a)
 *
 * Solid (single-color) quad: one rgba is replicated to all four vertices, so a
 * uniform Quad/Rectangle/Square passes 12 args instead of 24 and skips the
 * per-vertex color marshaling. Geometry is identical to draw_quad with equal
 * colors — the common case for solid rectangles.
 */
R_VAL ruby2d_ext_draw_quad_uniform(RUBY2D_METHOD_ARGS_VARIADIC) {
  RUBY2D_EXTRACT_VARIADIC;
  if (argc != 12) r_raise("Ruby2D::Ext.draw_quad_uniform expects 12 args, got %d", (int)argc);

  float r = NUM2DBL(argv[8]);
  float g = NUM2DBL(argv[9]);
  float b = NUM2DBL(argv[10]);
  float a = NUM2DBL(argv[11]);

  R2D_DrawQuad(
    NUM2DBL(argv[0]), NUM2DBL(argv[1]), r, g, b, a,
    NUM2DBL(argv[2]), NUM2DBL(argv[3]), r, g, b, a,
    NUM2DBL(argv[4]), NUM2DBL(argv[5]), r, g, b, a,
    NUM2DBL(argv[6]), NUM2DBL(argv[7]), r, g, b, a
  );

  return R_NIL;
}


/*
 * Ruby2D::Ext.stroke_quad(
 *   x1, y1, x2, y2, x3, y3, x4, y4,
 *   stroke_width,
 *   r1, g1, b1, a1,
 *   r2, g2, b2, a2,
 *   r3, g3, b3, a3,
 *   r4, g4, b4, a4
 * )
 */
R_VAL ruby2d_ext_stroke_quad(RUBY2D_METHOD_ARGS_VARIADIC) {
  RUBY2D_EXTRACT_VARIADIC;
  if (argc != 25) r_raise("Ruby2D::Ext.stroke_quad expects 25 args, got %d", (int)argc);

  float pts[8] = {
    NUM2DBL(argv[0]), NUM2DBL(argv[1]),
    NUM2DBL(argv[2]), NUM2DBL(argv[3]),
    NUM2DBL(argv[4]), NUM2DBL(argv[5]),
    NUM2DBL(argv[6]), NUM2DBL(argv[7])
  };
  float sw = NUM2DBL(argv[8]);
  float colors[16] = {
    NUM2DBL(argv[9]),  NUM2DBL(argv[10]), NUM2DBL(argv[11]), NUM2DBL(argv[12]),
    NUM2DBL(argv[13]), NUM2DBL(argv[14]), NUM2DBL(argv[15]), NUM2DBL(argv[16]),
    NUM2DBL(argv[17]), NUM2DBL(argv[18]), NUM2DBL(argv[19]), NUM2DBL(argv[20]),
    NUM2DBL(argv[21]), NUM2DBL(argv[22]), NUM2DBL(argv[23]), NUM2DBL(argv[24])
  };

  R2D_StrokePath(pts, 4, 1, sw, R2D_MITER_LIMIT, colors);

  return R_NIL;
}


/*
 * Ruby2D::Ext.stroke_quad_uniform(x1, y1, x2, y2, x3, y3, x4, y4, sw, r, g, b, a)
 *
 * Solid (single-color) quad outline: one rgba is replicated to all four
 * vertices, so a uniform stroke passes 13 args instead of 25. Identical stroke
 * geometry to stroke_quad with equal colors.
 */
R_VAL ruby2d_ext_stroke_quad_uniform(RUBY2D_METHOD_ARGS_VARIADIC) {
  RUBY2D_EXTRACT_VARIADIC;
  if (argc != 13) r_raise("Ruby2D::Ext.stroke_quad_uniform expects 13 args, got %d", (int)argc);

  float pts[8] = {
    NUM2DBL(argv[0]), NUM2DBL(argv[1]),
    NUM2DBL(argv[2]), NUM2DBL(argv[3]),
    NUM2DBL(argv[4]), NUM2DBL(argv[5]),
    NUM2DBL(argv[6]), NUM2DBL(argv[7])
  };
  float sw = NUM2DBL(argv[8]);
  float r = NUM2DBL(argv[9]), g = NUM2DBL(argv[10]), b = NUM2DBL(argv[11]), a = NUM2DBL(argv[12]);
  float colors[16] = { r,g,b,a, r,g,b,a, r,g,b,a, r,g,b,a };

  R2D_StrokePath(pts, 4, 1, sw, R2D_MITER_LIMIT, colors);

  return R_NIL;
}


/*
 * Ruby2D::Ext.draw_line(
 *   x1, y1, x2, y2,
 *   stroke_width,
 *   r1, g1, b1, a1,    -- start + perp
 *   r2, g2, b2, a2,    -- start - perp
 *   r3, g3, b3, a3,    -- end - perp
 *   r4, g4, b4, a4     -- end + perp
 * )
 */
R_VAL ruby2d_ext_draw_line(RUBY2D_METHOD_ARGS_VARIADIC) {
  RUBY2D_EXTRACT_VARIADIC;
  if (argc != 21) r_raise("Ruby2D::Ext.draw_line expects 21 args, got %d", (int)argc);

  R2D_DrawLine(
    NUM2DBL(argv[0]), NUM2DBL(argv[1]),
    NUM2DBL(argv[2]), NUM2DBL(argv[3]),
    NUM2DBL(argv[4]),

    NUM2DBL(argv[5]),  NUM2DBL(argv[6]),  NUM2DBL(argv[7]),  NUM2DBL(argv[8]),
    NUM2DBL(argv[9]),  NUM2DBL(argv[10]), NUM2DBL(argv[11]), NUM2DBL(argv[12]),
    NUM2DBL(argv[13]), NUM2DBL(argv[14]), NUM2DBL(argv[15]), NUM2DBL(argv[16]),
    NUM2DBL(argv[17]), NUM2DBL(argv[18]), NUM2DBL(argv[19]), NUM2DBL(argv[20])
  );

  return R_NIL;
}


/*
 * Ruby2D::Ext.draw_dashed_line(
 *   x1, y1, x2, y2,
 *   stroke_width, dash, gap,
 *   r1, g1, b1, a1,
 *   r2, g2, b2, a2,
 *   r3, g3, b3, a3,
 *   r4, g4, b4, a4
 * )
 */
R_VAL ruby2d_ext_draw_dashed_line(RUBY2D_METHOD_ARGS_VARIADIC) {
  RUBY2D_EXTRACT_VARIADIC;
  if (argc != 23) r_raise("Ruby2D::Ext.draw_dashed_line expects 23 args, got %d", (int)argc);

  R2D_DrawDashedLine(
    NUM2DBL(argv[0]), NUM2DBL(argv[1]),
    NUM2DBL(argv[2]), NUM2DBL(argv[3]),
    NUM2DBL(argv[4]), NUM2DBL(argv[5]), NUM2DBL(argv[6]),

    NUM2DBL(argv[7]),  NUM2DBL(argv[8]),  NUM2DBL(argv[9]),  NUM2DBL(argv[10]),
    NUM2DBL(argv[11]), NUM2DBL(argv[12]), NUM2DBL(argv[13]), NUM2DBL(argv[14]),
    NUM2DBL(argv[15]), NUM2DBL(argv[16]), NUM2DBL(argv[17]), NUM2DBL(argv[18]),
    NUM2DBL(argv[19]), NUM2DBL(argv[20]), NUM2DBL(argv[21]), NUM2DBL(argv[22])
  );

  return R_NIL;
}


/*
 * Ruby2D::Ext.draw_circle(x, y, radius, sectors, r, g, b, a)
 */
R_VAL ruby2d_ext_draw_circle(RUBY2D_METHOD_ARGS_VARIADIC) {
  RUBY2D_EXTRACT_VARIADIC;
  if (argc != 8) r_raise("Ruby2D::Ext.draw_circle expects 8 args, got %d", (int)argc);

  R2D_DrawCircle(
    NUM2DBL(argv[0]), NUM2DBL(argv[1]),
    NUM2DBL(argv[2]), NUM2INT(argv[3]),
    NUM2DBL(argv[4]), NUM2DBL(argv[5]), NUM2DBL(argv[6]), NUM2DBL(argv[7])
  );

  return R_NIL;
}


/*
 * Ruby2D::Ext.stroke_circle(x, y, radius, sectors, stroke_width, r, g, b, a)
 */
R_VAL ruby2d_ext_stroke_circle(RUBY2D_METHOD_ARGS_VARIADIC) {
  RUBY2D_EXTRACT_VARIADIC;
  if (argc != 9) r_raise("Ruby2D::Ext.stroke_circle expects 9 args, got %d", (int)argc);

  float x = NUM2DBL(argv[0]);
  float y = NUM2DBL(argv[1]);
  float r = NUM2DBL(argv[2]);
  int sectors = NUM2INT(argv[3]);
  float sw = NUM2DBL(argv[4]);

  R2D_StrokeEllipse(x, y, r, r, 0.0f, sectors, sw,
    NUM2DBL(argv[5]), NUM2DBL(argv[6]), NUM2DBL(argv[7]), NUM2DBL(argv[8]));

  return R_NIL;
}


/*
 * Ruby2D::Ext.draw_ellipse(x, y, xradius, yradius, angle, sectors, r, g, b, a)
 */
R_VAL ruby2d_ext_draw_ellipse(RUBY2D_METHOD_ARGS_VARIADIC) {
  RUBY2D_EXTRACT_VARIADIC;
  if (argc != 10) r_raise("Ruby2D::Ext.draw_ellipse expects 10 args, got %d", (int)argc);

  R2D_DrawEllipse(
    NUM2DBL(argv[0]), NUM2DBL(argv[1]),
    NUM2DBL(argv[2]), NUM2DBL(argv[3]),
    NUM2DBL(argv[4]), NUM2INT(argv[5]),
    NUM2DBL(argv[6]), NUM2DBL(argv[7]), NUM2DBL(argv[8]), NUM2DBL(argv[9])
  );

  return R_NIL;
}


/*
 * Ruby2D::Ext.stroke_ellipse(x, y, xradius, yradius, angle, sectors, stroke_width, r, g, b, a)
 */
R_VAL ruby2d_ext_stroke_ellipse(RUBY2D_METHOD_ARGS_VARIADIC) {
  RUBY2D_EXTRACT_VARIADIC;
  if (argc != 11) r_raise("Ruby2D::Ext.stroke_ellipse expects 11 args, got %d", (int)argc);

  R2D_StrokeEllipse(
    NUM2DBL(argv[0]), NUM2DBL(argv[1]),
    NUM2DBL(argv[2]), NUM2DBL(argv[3]),
    NUM2DBL(argv[4]), NUM2INT(argv[5]), NUM2DBL(argv[6]),
    NUM2DBL(argv[7]), NUM2DBL(argv[8]), NUM2DBL(argv[9]), NUM2DBL(argv[10])
  );

  return R_NIL;
}


// Variadic shape bindings (Polygon, Polyline) /////////////////////////////////


/*
 * Ruby2D::Ext.draw_polygon(verts, pv_colors)
 *
 *   verts     — flat Array [x1, y1, x2, y2, ...] of length 2n
 *   pv_colors — flat Array [r1, g1, b1, a1, r2, ...] of length 4n
 *
 * Vertex count is inferred from verts.length / 2. n must be >= 3.
 */
R_VAL ruby2d_ext_draw_polygon(RUBY2D_METHOD_ARGS_VARIADIC) {
  RUBY2D_EXTRACT_VARIADIC;
  if (argc != 2) r_raise("Ruby2D::Ext.draw_polygon expects 2 args, got %d", (int)argc);

  R_VAL verts_ary  = argv[0];
  R_VAL colors_ary = argv[1];

  int n = (int)(r_ary_len(verts_ary) / 2);
  if (n < 3) return R_NIL;

  // Guard the colors array length before the read loop: a short array would
  // make r_ary_entry return nil and NUM2DBL(nil) error (hard-abort on mruby).
  if ((int)r_ary_len(colors_ary) < n * 4)
    r_raise("Ruby2D::Ext.draw_polygon: %d color values for %d vertices (need %d)",
            (int)r_ary_len(colors_ary), n, n * 4);

  // Most polygons are small, so serve the marshaling buffers from the stack and
  // fall back to the heap only past the threshold — no malloc/free per frame.
  float pts_stack[R2D_STROKE_STACK_N * 2];
  float colors_stack[R2D_STROKE_STACK_N * 4];
  float *pts, *colors;
  bool heap = n > R2D_STROKE_STACK_N;

  if (heap) {
    pts    = (float *)malloc(n * 2 * sizeof(float));
    colors = (float *)malloc(n * 4 * sizeof(float));
    if (!pts || !colors) { free(pts); free(colors); return R_NIL; }
  } else {
    pts    = pts_stack;
    colors = colors_stack;
  }

  for (int i = 0; i < n * 2; i++) pts[i]    = NUM2DBL(r_ary_entry(verts_ary,  i));
  for (int i = 0; i < n * 4; i++) colors[i] = NUM2DBL(r_ary_entry(colors_ary, i));

  R2D_DrawPolygon(pts, n, colors, 0, 0, 0, 0);

  if (heap) { free(colors); free(pts); }
  return R_NIL;
}


/*
 * Ruby2D::Ext.stroke_path(verts, stroke_width, pv_colors, closed)
 *
 *   verts        — flat Array [x1, y1, x2, y2, ...] of length 2n
 *   stroke_width — Float
 *   pv_colors    — flat Array [r1, g1, b1, a1, r2, ...] of length 4n
 *   closed       — truthy → close the path back to vertex 0
 *
 * Used by Polygon (closed = true) and Polyline (closed varies).
 */
R_VAL ruby2d_ext_stroke_path(RUBY2D_METHOD_ARGS_VARIADIC) {
  RUBY2D_EXTRACT_VARIADIC;
  if (argc != 4) r_raise("Ruby2D::Ext.stroke_path expects 4 args, got %d", (int)argc);

  R_VAL verts_ary  = argv[0];
  float sw         = NUM2DBL(argv[1]);
  R_VAL colors_ary = argv[2];
  int closed       = r_test(argv[3]) ? 1 : 0;

  int n = (int)(r_ary_len(verts_ary) / 2);
  if (n < 2 || sw <= 0.0f) return R_NIL;

  // Guard the colors array length before the read loop: a short array would
  // make r_ary_entry return nil and NUM2DBL(nil) error (hard-abort on mruby).
  if ((int)r_ary_len(colors_ary) < n * 4)
    r_raise("Ruby2D::Ext.stroke_path: %d color values for %d vertices (need %d)",
            (int)r_ary_len(colors_ary), n, n * 4);

  // Most paths are small, so serve the marshaling buffers from the stack and
  // fall back to the heap only past the threshold — no malloc/free per frame.
  float pts_stack[R2D_STROKE_STACK_N * 2];
  float colors_stack[R2D_STROKE_STACK_N * 4];
  float *pts, *colors;
  bool heap = n > R2D_STROKE_STACK_N;

  if (heap) {
    pts    = (float *)malloc(n * 2 * sizeof(float));
    colors = (float *)malloc(n * 4 * sizeof(float));
    if (!pts || !colors) { free(pts); free(colors); return R_NIL; }
  } else {
    pts    = pts_stack;
    colors = colors_stack;
  }

  for (int i = 0; i < n * 2; i++) pts[i]    = NUM2DBL(r_ary_entry(verts_ary,  i));
  for (int i = 0; i < n * 4; i++) colors[i] = NUM2DBL(r_ary_entry(colors_ary, i));

  R2D_StrokePath(pts, n, closed, sw, R2D_MITER_LIMIT, colors);

  if (heap) { free(colors); free(pts); }
  return R_NIL;
}


/*
 * Initialize
 */
void R2D_Ext_Init() {
  ruby2d_ext_module = r_define_module_under(ruby2d_module, "Ext");

  // Shared ivar IDs — see declarations above.
  id_x          = r_id("@x");
  id_y          = r_id("@y");
  id_width      = r_id("@width");
  id_height     = r_id("@height");
  id_rotate     = r_id("@rotate");
  id_color      = r_id("@color");
  id_r          = r_id("@r");
  id_g          = r_id("@g");
  id_b          = r_id("@b");
  id_a          = r_id("@a");
  id_ext_image  = r_id("@ext_image");
  id_ext_text   = r_id("@ext_text");
  id_path       = r_id("@path");
  id_content    = r_id("@content");
  id_viewport_width  = r_id("@viewport_width");
  id_viewport_height = r_id("@viewport_height");

  // Fixed-arity shape bindings
  r_define_class_method(ruby2d_ext_module, "draw_triangle",    ruby2d_ext_draw_triangle,    r_args_variadic);
  r_define_class_method(ruby2d_ext_module, "draw_triangle_uniform", ruby2d_ext_draw_triangle_uniform, r_args_variadic);
  r_define_class_method(ruby2d_ext_module, "stroke_triangle",  ruby2d_ext_stroke_triangle,  r_args_variadic);
  r_define_class_method(ruby2d_ext_module, "stroke_triangle_uniform", ruby2d_ext_stroke_triangle_uniform, r_args_variadic);
  r_define_class_method(ruby2d_ext_module, "draw_quad",        ruby2d_ext_draw_quad,        r_args_variadic);
  r_define_class_method(ruby2d_ext_module, "draw_quad_uniform", ruby2d_ext_draw_quad_uniform, r_args_variadic);
  r_define_class_method(ruby2d_ext_module, "stroke_quad",      ruby2d_ext_stroke_quad,      r_args_variadic);
  r_define_class_method(ruby2d_ext_module, "stroke_quad_uniform", ruby2d_ext_stroke_quad_uniform, r_args_variadic);
  r_define_class_method(ruby2d_ext_module, "draw_line",        ruby2d_ext_draw_line,        r_args_variadic);
  r_define_class_method(ruby2d_ext_module, "draw_dashed_line", ruby2d_ext_draw_dashed_line, r_args_variadic);
  r_define_class_method(ruby2d_ext_module, "draw_circle",      ruby2d_ext_draw_circle,      r_args_variadic);
  r_define_class_method(ruby2d_ext_module, "stroke_circle",    ruby2d_ext_stroke_circle,    r_args_variadic);
  r_define_class_method(ruby2d_ext_module, "draw_ellipse",     ruby2d_ext_draw_ellipse,     r_args_variadic);
  r_define_class_method(ruby2d_ext_module, "stroke_ellipse",   ruby2d_ext_stroke_ellipse,   r_args_variadic);

  // Variadic shape bindings
  r_define_class_method(ruby2d_ext_module, "draw_polygon",     ruby2d_ext_draw_polygon,     r_args_variadic);
  r_define_class_method(ruby2d_ext_module, "stroke_path",      ruby2d_ext_stroke_path,      r_args_variadic);
}
