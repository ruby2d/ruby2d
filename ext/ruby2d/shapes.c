// shapes.c
//
// Pure C primitives for shape rendering — no Ruby in this file. Ruby-callable
// wrappers live in ext.c and dispatch into these via Ruby2D::Ext class methods.

#include "ruby2d.h"


/*
 * Compute outer and inner outline points for a polyline or polygon stroke.
 * See ruby2d.h for parameter documentation.
 *
 * Interior vertices (and all vertices in closed mode) use miter joins;
 * endpoints in open mode get butt caps using the perpendicular of the single
 * adjacent edge. Sharp miters are clamped to `miter_limit * half_width` so
 * very acute corners don't shoot off into space (SVG's miterlimit behavior,
 * though implemented here as a clamp rather than a bevel fallback).
 */
void R2D_ComputeStrokeOutline(const float *verts, int n, int closed,
                              float stroke_width, float miter_limit,
                              float *outer, float *inner) {

  if (n < 2) return;

  float hw = stroke_width / 2.0f;
  float max_ml = miter_limit * hw;

  for (int i = 0; i < n; i++) {
    int is_endpoint = !closed && (i == 0 || i == n - 1);

    if (is_endpoint) {
      // Butt cap: perpendicular of the single adjacent edge
      int other = (i == 0) ? 1 : n - 2;
      float dx = verts[i*2]   - verts[other*2];
      float dy = verts[i*2+1] - verts[other*2+1];
      if (i == 0) { dx = -dx; dy = -dy; }
      float len = sqrtf(dx * dx + dy * dy);

      if (len < 0.0001f) {
        outer[i*2] = verts[i*2];     outer[i*2+1] = verts[i*2+1];
        inner[i*2] = verts[i*2];     inner[i*2+1] = verts[i*2+1];
      } else {
        float nx = -dy / len, ny = dx / len;
        outer[i*2]   = verts[i*2]   + nx * hw;
        outer[i*2+1] = verts[i*2+1] + ny * hw;
        inner[i*2]   = verts[i*2]   - nx * hw;
        inner[i*2+1] = verts[i*2+1] - ny * hw;
      }
      continue;
    }

    // Interior (or any vertex in closed mode): compute miter
    int prev = (i - 1 + n) % n;
    int next = (i + 1) % n;

    float d1x = verts[i*2]   - verts[prev*2];
    float d1y = verts[i*2+1] - verts[prev*2+1];
    float d2x = verts[next*2]   - verts[i*2];
    float d2y = verts[next*2+1] - verts[i*2+1];

    float len1 = sqrtf(d1x * d1x + d1y * d1y);
    float len2 = sqrtf(d2x * d2x + d2y * d2y);

    if (len1 < 0.0001f || len2 < 0.0001f) {
      outer[i*2] = verts[i*2];     outer[i*2+1] = verts[i*2+1];
      inner[i*2] = verts[i*2];     inner[i*2+1] = verts[i*2+1];
      continue;
    }

    d1x /= len1; d1y /= len1;
    d2x /= len2; d2y /= len2;

    float n1x = -d1y, n1y = d1x;
    float n2x = -d2y, n2y = d2x;

    float mx = n1x + n2x;
    float my = n1y + n2y;
    float mlen = sqrtf(mx * mx + my * my);

    if (mlen < 0.0001f) {
      // 180° turn — degenerate; use the perpendicular of edge 1
      outer[i*2]   = verts[i*2]   + n1x * hw;
      outer[i*2+1] = verts[i*2+1] + n1y * hw;
      inner[i*2]   = verts[i*2]   - n1x * hw;
      inner[i*2+1] = verts[i*2+1] - n1y * hw;
      continue;
    }

    mx /= mlen; my /= mlen;

    float dot = mx * n1x + my * n1y;
    if (fabsf(dot) < 0.0001f) dot = 0.0001f;
    float ml = hw / dot;

    // Clamp miter length for sharp corners
    if (ml > max_ml) ml = max_ml;
    else if (ml < -max_ml) ml = -max_ml;

    outer[i*2]   = verts[i*2]   + mx * ml;
    outer[i*2+1] = verts[i*2+1] + my * ml;
    inner[i*2]   = verts[i*2]   - mx * ml;
    inner[i*2+1] = verts[i*2+1] - my * ml;
  }
}


/*
 * Stroke a polyline or closed polygon outline via SDL_RenderGeometry.
 * See ruby2d.h for parameter documentation.
 */
void R2D_StrokePath(const float *verts, int n, int closed,
                    float stroke_width, float miter_limit,
                    const float *colors) {

  if (n < 2 || stroke_width <= 0.0f) return;

  // 2n vertices (outer[0], inner[0], outer[1], inner[1], ...); 6 indices per
  // edge, with n edges when closed and n-1 when open.
  int num_vertices = n * 2;
  int edges = closed ? n : n - 1;
  int num_indices = edges * 6;

  // Most stroked shapes are small (triangles, quads, short polylines), so serve
  // the four scratch buffers from the stack and fall back to the heap only for
  // large vertex counts. Avoids four malloc/free pairs per call on the
  // per-frame stroke path.
  float outer_stack[R2D_STROKE_STACK_N * 2];
  float inner_stack[R2D_STROKE_STACK_N * 2];
  SDL_Vertex vertices_stack[R2D_STROKE_STACK_N * 2];
  int indices_stack[R2D_STROKE_STACK_N * 6];

  float *outer, *inner;
  SDL_Vertex *vertices;
  int *indices;
  bool heap = n > R2D_STROKE_STACK_N;

  if (heap) {
    outer    = (float *)malloc(n * 2 * sizeof(float));
    inner    = (float *)malloc(n * 2 * sizeof(float));
    vertices = (SDL_Vertex *)malloc(num_vertices * sizeof(SDL_Vertex));
    indices  = (int *)malloc(num_indices * sizeof(int));
    if (!outer || !inner || !vertices || !indices) {
      free(outer); free(inner); free(vertices); free(indices);
      return;
    }
  } else {
    outer    = outer_stack;
    inner    = inner_stack;
    vertices = vertices_stack;
    indices  = indices_stack;
  }

  R2D_ComputeStrokeOutline(verts, n, closed, stroke_width, miter_limit, outer, inner);

  for (int i = 0; i < n; i++) {
    float r = colors[i * 4];
    float g = colors[i * 4 + 1];
    float b = colors[i * 4 + 2];
    float a = colors[i * 4 + 3];

    vertices[i * 2].position.x = outer[i * 2];
    vertices[i * 2].position.y = outer[i * 2 + 1];
    vertices[i * 2].color.r = r;
    vertices[i * 2].color.g = g;
    vertices[i * 2].color.b = b;
    vertices[i * 2].color.a = a;
    vertices[i * 2].tex_coord.x = 0.0f;
    vertices[i * 2].tex_coord.y = 0.0f;

    vertices[i * 2 + 1].position.x = inner[i * 2];
    vertices[i * 2 + 1].position.y = inner[i * 2 + 1];
    vertices[i * 2 + 1].color.r = r;
    vertices[i * 2 + 1].color.g = g;
    vertices[i * 2 + 1].color.b = b;
    vertices[i * 2 + 1].color.a = a;
    vertices[i * 2 + 1].tex_coord.x = 0.0f;
    vertices[i * 2 + 1].tex_coord.y = 0.0f;
  }

  for (int i = 0; i < edges; i++) {
    int j = (i + 1) % n;
    int oi = i * 2,      ii = i * 2 + 1;
    int oj = j * 2,      ij = j * 2 + 1;

    indices[i * 6]     = oi;
    indices[i * 6 + 1] = ii;
    indices[i * 6 + 2] = ij;
    indices[i * 6 + 3] = oi;
    indices[i * 6 + 4] = ij;
    indices[i * 6 + 5] = oj;
  }

  R2D_CheckSDL(SDL_RenderGeometry(R2D_GetRenderer(), NULL,
                                  vertices, num_vertices, indices, num_indices),
               "SDL_RenderGeometry");

  if (heap) {
    free(indices);
    free(vertices);
    free(outer);
    free(inner);
  }
}


/*
 * Unit-circle lookup cache, keyed by sector count.
 *
 * The cos/sin of each sector angle depend only on the sector count — not on
 * position, radius, or color — so they are identical every frame and across
 * every circle/ellipse drawn with the same sector count. Build each table once
 * on first use and reuse it, turning the per-vertex fill into a multiply-add
 * with no trig. Rendering is single-threaded, so the file-static cache needs no
 * locking; tables live for the process lifetime and slots for unused sector
 * counts stay NULL.
 */
#define R2D_MAX_SECTORS 360
#define R2D_MIN_SECTORS 3
static float *unit_cos_table[R2D_MAX_SECTORS + 1];
static float *unit_sin_table[R2D_MAX_SECTORS + 1];

/*
 * Fetch the cached unit-circle cos/sin tables for `sectors` (in [3, 360]),
 * building them on first use. On success points *cos_out / *sin_out at tables
 * of `sectors` floats — cosf/sinf of i*(2*PI/sectors) for i in [0, sectors) —
 * and returns true; on a bad sector count or allocation failure returns false
 * so the caller computes the trig inline. The build expression matches the draw
 * loops' former inline math exactly, so the geometry is bit-identical.
 */
static bool R2D_UnitCircle(int sectors, const float **cos_out, const float **sin_out) {
  if (sectors < 3 || sectors > R2D_MAX_SECTORS) return false;

  if (!unit_cos_table[sectors]) {
    float *cos_t = (float *)malloc(sectors * sizeof(float));
    float *sin_t = (float *)malloc(sectors * sizeof(float));
    if (!cos_t || !sin_t) { free(cos_t); free(sin_t); return false; }

    float angle_step = (2.0f * M_PI) / sectors;
    for (int i = 0; i < sectors; i++) {
      float angle = i * angle_step;
      cos_t[i] = cosf(angle);
      sin_t[i] = sinf(angle);
    }
    unit_cos_table[sectors] = cos_t;
    unit_sin_table[sectors] = sin_t;
  }

  *cos_out = unit_cos_table[sectors];
  *sin_out = unit_sin_table[sectors];
  return true;
}


/*
 * Draw a filled ellipse via a triangle fan.
 * See ruby2d.h for parameter documentation.
 */
void R2D_DrawEllipse(float cx, float cy, float rx, float ry, float angle,
                     int sectors, float r, float g, float b, float a) {

  if (sectors < R2D_MIN_SECTORS) sectors = R2D_MIN_SECTORS;
  if (sectors > R2D_MAX_SECTORS) sectors = R2D_MAX_SECTORS;

  // 1 center + one vertex per sector. The fan's last triangle wraps its index
  // back to the first rim vertex (% sectors), so there's no duplicate rim point
  // at angle 0 / 2π — matching R2D_StrokeEllipse.
  int num_vertices = sectors + 1;
  int num_indices = sectors * 3;

  // Most ellipses use the default 30 sectors, so serve the vertex and index
  // scratch from the stack and fall back to the heap only past the threshold.
  // Avoids two malloc/free pairs per fill on the per-frame round-shape path.
  SDL_Vertex vertices_stack[R2D_STROKE_STACK_N + 1];
  int indices_stack[R2D_STROKE_STACK_N * 3];

  SDL_Vertex *vertices;
  int *indices;
  bool heap = sectors > R2D_STROKE_STACK_N;

  if (heap) {
    vertices = (SDL_Vertex *)malloc(num_vertices * sizeof(SDL_Vertex));
    indices  = (int *)malloc(num_indices * sizeof(int));
    if (!vertices || !indices) {
      free(vertices); free(indices);
      return;
    }
  } else {
    vertices = vertices_stack;
    indices  = indices_stack;
  }

  // Center
  vertices[0].position.x = cx;
  vertices[0].position.y = cy;
  vertices[0].color.r = r;
  vertices[0].color.g = g;
  vertices[0].color.b = b;
  vertices[0].color.a = a;
  vertices[0].tex_coord.x = 0.0f;
  vertices[0].tex_coord.y = 0.0f;

  // Unit-circle cos/sin come from the cached table (no per-vertex trig); only a
  // table-build failure falls back to computing them inline.
  const float *uc, *us;
  bool cached = R2D_UnitCircle(sectors, &uc, &us);
  float angle_step = cached ? 0.0f : (2.0f * M_PI) / sectors;
  // Tilt the whole rim by `angle` (radians) so the ellipse can sit off-axis;
  // when angle is 0 this is the identity, so skip the extra trig.
  float rot_c = 1.0f, rot_s = 0.0f;
  if (angle != 0.0f) { rot_c = cosf(angle); rot_s = sinf(angle); }
  for (int i = 0; i < sectors; i++) {
    float cv = cached ? uc[i] : cosf(i * angle_step);
    float sv = cached ? us[i] : sinf(i * angle_step);
    float ox = rx * cv, oy = ry * sv;
    vertices[i + 1].position.x = cx + ox * rot_c - oy * rot_s;
    vertices[i + 1].position.y = cy + ox * rot_s + oy * rot_c;
    vertices[i + 1].color.r = r;
    vertices[i + 1].color.g = g;
    vertices[i + 1].color.b = b;
    vertices[i + 1].color.a = a;
    vertices[i + 1].tex_coord.x = 0.0f;
    vertices[i + 1].tex_coord.y = 0.0f;
  }

  for (int i = 0; i < sectors; i++) {
    indices[i * 3]     = 0;
    indices[i * 3 + 1] = i + 1;
    indices[i * 3 + 2] = (i + 1) % sectors + 1;
  }

  R2D_CheckSDL(SDL_RenderGeometry(R2D_GetRenderer(), NULL,
                                  vertices, num_vertices, indices, num_indices),
               "SDL_RenderGeometry");

  if (heap) {
    free(indices);
    free(vertices);
  }
}


/*
 * Signed area (×2) of a polygon. Positive for CCW, negative for CW
 * winding in screen coordinates (y-down). Used to normalize winding
 * before ear clipping.
 */
static float shapes_polygon_signed_area2(const float *verts, int n) {
  float sum = 0.0f;
  for (int i = 0; i < n; i++) {
    int j = (i + 1) % n;
    sum += verts[i * 2] * verts[j * 2 + 1] - verts[j * 2] * verts[i * 2 + 1];
  }
  return sum;
}


/*
 * Triangle area sign helper (uses cross product). >0 is CCW, <0 is CW.
 */
static float shapes_tri_cross(float ax, float ay, float bx, float by,
                              float cx, float cy) {
  return (bx - ax) * (cy - ay) - (by - ay) * (cx - ax);
}


/*
 * Point-in-triangle test using barycentric sign comparisons.
 * Returns 1 if (px, py) is strictly inside triangle (a, b, c) with the
 * given winding (assumed CCW); points exactly on an edge are excluded.
 */
static int shapes_point_in_tri(float px, float py,
                               float ax, float ay,
                               float bx, float by,
                               float cx, float cy) {
  float d1 = shapes_tri_cross(ax, ay, bx, by, px, py);
  float d2 = shapes_tri_cross(bx, by, cx, cy, px, py);
  float d3 = shapes_tri_cross(cx, cy, ax, ay, px, py);
  // For CCW triangles, all three should be > 0 for strict interior.
  return (d1 > 0.0f && d2 > 0.0f && d3 > 0.0f);
}


/*
 * Is the working polygon convex? (CCW winding assumed.) A blind triangle fan
 * from poly[0] is only correct for a convex polygon — over a concave remainder
 * it emits triangles that spill outside the outline. Used to guard the
 * ear-clipping fan-tail fallback.
 */
static bool shapes_remaining_is_convex(const float *verts, const int *poly, int remaining) {
  for (int i = 0; i < remaining; i++) {
    int a = poly[(i + remaining - 1) % remaining];
    int b = poly[i];
    int c = poly[(i + 1) % remaining];
    float cross = shapes_tri_cross(verts[a * 2], verts[a * 2 + 1],
                                   verts[b * 2], verts[b * 2 + 1],
                                   verts[c * 2], verts[c * 2 + 1]);
    if (cross < 0.0f) return false;  // reflex corner — not convex
  }
  return true;
}


/*
 * Ear-clipping triangulation of a simple polygon.
 * See ruby2d.h for parameter documentation.
 */
int *R2D_TriangulatePolygon(const float *verts, int n, int *out_tri_count) {
  if (out_tri_count) *out_tri_count = 0;
  if (n < 3) return NULL;

  int tri_count = n - 2;
  int *indices = (int *)malloc(tri_count * 3 * sizeof(int));
  if (!indices) return NULL;

  // Fast path for triangles
  if (n == 3) {
    indices[0] = 0;
    indices[1] = 1;
    indices[2] = 2;
    if (out_tri_count) *out_tri_count = 1;
    return indices;
  }

  // Build a working list of original-vertex indices ordered CCW.
  // If the input polygon is CW, reverse it so the rest of the algorithm
  // can assume CCW (= "convex corner has positive cross product").
  // poly is internal scratch (freed before return), so serve it from the stack
  // for the common small-n case; only the largest polygons fall to the heap.
  int poly_stack[R2D_STROKE_STACK_N];
  bool poly_heap = n > R2D_STROKE_STACK_N;
  int *poly = poly_heap ? (int *)malloc(n * sizeof(int)) : poly_stack;
  if (!poly) { free(indices); return NULL; }

  float area2 = shapes_polygon_signed_area2(verts, n);
  if (area2 < 0.0f) {
    // CW input — reverse so we work in CCW order. Output indices still
    // refer to the caller's original vertex array.
    for (int i = 0; i < n; i++) poly[i] = n - 1 - i;
  } else {
    for (int i = 0; i < n; i++) poly[i] = i;
  }

  int remaining = n;
  int out = 0;
  // Guard against pathological inputs (e.g. self-intersecting polygons
  // where no ear can ever be found): cap total iterations.
  int safety = 0;
  int safety_limit = n * n + 4;

  while (remaining > 3 && safety++ < safety_limit) {
    int found_ear = 0;

    for (int i = 0; i < remaining; i++) {
      int i_prev = (i + remaining - 1) % remaining;
      int i_next = (i + 1) % remaining;

      int a = poly[i_prev];
      int b = poly[i];
      int c = poly[i_next];

      float ax = verts[a * 2], ay = verts[a * 2 + 1];
      float bx = verts[b * 2], by = verts[b * 2 + 1];
      float cx = verts[c * 2], cy = verts[c * 2 + 1];

      // Corner test (CCW => positive cross). Reject only reflex corners
      // (cross < 0). A collinear corner (cross == 0) is clipped as a
      // zero-area ear: it renders nothing but removes the vertex, keeping
      // the algorithm progressing so polygons with collinear vertex runs
      // don't stall into the fan-tail fallback.
      float cross = shapes_tri_cross(ax, ay, bx, by, cx, cy);
      if (cross < 0.0f) continue;

      // Ear test: no other polygon vertex lies inside (a, b, c).
      int contains = 0;
      for (int k = 0; k < remaining; k++) {
        if (k == i_prev || k == i || k == i_next) continue;
        int v = poly[k];
        float px = verts[v * 2], py = verts[v * 2 + 1];
        if (shapes_point_in_tri(px, py, ax, ay, bx, by, cx, cy)) {
          contains = 1;
          break;
        }
      }
      if (contains) continue;

      // Emit the ear and remove vertex b from the working list.
      indices[out++] = a;
      indices[out++] = b;
      indices[out++] = c;

      for (int k = i; k < remaining - 1; k++) poly[k] = poly[k + 1];
      remaining--;
      found_ear = 1;
      break;
    }

    if (!found_ear) {
      // Degenerate / self-intersecting input. Fall back to a fan over
      // whatever remains so we still emit something defined.
      break;
    }
  }

  // Final triangle (or fan tail on fallback). A blind fan from poly[0] is only
  // correct when the remainder is convex; over a concave remainder (genuinely
  // degenerate / self-intersecting input, documented as unsupported) it would
  // spill triangles outside the shape. In that case emit nothing for the
  // remainder rather than render garbage — the unused slots pad to degenerate
  // triangles below.
  if (remaining == 3 || shapes_remaining_is_convex(verts, poly, remaining)) {
    while (remaining >= 3 && out < tri_count * 3) {
      indices[out++] = poly[0];
      indices[out++] = poly[1];
      indices[out++] = poly[2];
      // Drop poly[1] to continue the fan if any remainder is left.
      for (int k = 1; k < remaining - 1; k++) poly[k] = poly[k + 1];
      remaining--;
    }
  }

  if (poly_heap) free(poly);

  // Real number of triangles emitted (before any degenerate padding below).
  // Reporting this — not the theoretical n-2 — keeps callers from setting up
  // the zero-area padding triangles when the input was degenerate.
  int real_tri_count = out / 3;

  // If the loop bailed early, pad unused slots with a degenerate triangle so
  // the buffer stays well-formed even for a caller that ignores the count.
  while (out < tri_count * 3) {
    indices[out++] = 0;
    indices[out++] = 0;
    indices[out++] = 0;
  }

  if (out_tri_count) *out_tri_count = real_tri_count;
  return indices;
}


/*
 * Draw a filled polygon. Triangulated via ear clipping so concave
 * polygons fill correctly. See ruby2d.h for parameter documentation.
 */
void R2D_DrawPolygon(const float *verts, int n,
                     const float *per_vertex_colors,
                     float r, float g, float b, float a) {

  if (n < 3) return;

  int tri_count = 0;
  int *indices = R2D_TriangulatePolygon(verts, n, &tri_count);
  if (!indices || tri_count <= 0) { free(indices); return; }

  // vertices is per-draw scratch; stack-serve it for small n to avoid a
  // per-frame malloc/free. (indices stays heap — it is owned by this path and
  // freed below after the draw.)
  SDL_Vertex vertices_stack[R2D_STROKE_STACK_N];
  bool heap = n > R2D_STROKE_STACK_N;
  SDL_Vertex *vertices = heap ? (SDL_Vertex *)malloc(n * sizeof(SDL_Vertex)) : vertices_stack;
  if (!vertices) { free(indices); return; }

  for (int i = 0; i < n; i++) {
    vertices[i].position.x = verts[i * 2];
    vertices[i].position.y = verts[i * 2 + 1];
    if (per_vertex_colors) {
      vertices[i].color.r = per_vertex_colors[i * 4];
      vertices[i].color.g = per_vertex_colors[i * 4 + 1];
      vertices[i].color.b = per_vertex_colors[i * 4 + 2];
      vertices[i].color.a = per_vertex_colors[i * 4 + 3];
    } else {
      vertices[i].color.r = r;
      vertices[i].color.g = g;
      vertices[i].color.b = b;
      vertices[i].color.a = a;
    }
    vertices[i].tex_coord.x = 0.0f;
    vertices[i].tex_coord.y = 0.0f;
  }

  R2D_CheckSDL(SDL_RenderGeometry(R2D_GetRenderer(), NULL,
                                  vertices, n, indices, tri_count * 3),
               "SDL_RenderGeometry");

  free(indices);
  if (heap) free(vertices);
}


/*
 * Draw a dashed line from (x1,y1) to (x2,y2) as repeated thick quads.
 * Each of the 4 input colors maps to a corner of the full line quad
 * (c1=start+perp, c2=start-perp, c3=end-perp, c4=end+perp). Per-segment
 * endpoint colors are linearly interpolated along the length.
 * See ruby2d.h for parameter documentation.
 */
void R2D_DrawDashedLine(float x1, float y1, float x2, float y2,
                        float stroke_width, float dash, float gap,
                        float r1, float g1, float b1, float a1,
                        float r2, float g2, float b2, float a2,
                        float r3, float g3, float b3, float a3,
                        float r4, float g4, float b4, float a4) {

  if (stroke_width <= 0.0f || dash <= 0.0f) return;

  float dx = x2 - x1;
  float dy = y2 - y1;
  float length = sqrtf(dx * dx + dy * dy);
  if (length <= 0.0f) return;

  float ux = dx / length;
  float uy = dy / length;
  float step = dash + (gap > 0.0f ? gap : 0.0f);

  // Bound the work: a sub-pixel dash/gap on a long line would otherwise issue
  // hundreds of thousands of draw calls and stall the frame. If the segment
  // count blows past a ceiling, scale dash and gap up together (preserving
  // their ratio) so the pattern still reads while the work stays bounded.
  const int max_segments = 10000;
  if (length / step > (float)max_segments) {
    static bool warned = false;
    if (!warned) {
      R2D_Log(R2D_WARN, "Dashed line dash/gap too small; clamping segment count");
      warned = true;
    }
    float f = (length / step) / (float)max_segments;
    dash *= f;
    gap  *= f;
    step = dash + (gap > 0.0f ? gap : 0.0f);
  }

  // Perpendicular offset, scaled by half the stroke width. Every dash lies
  // along the same line, so this is constant — compute it once instead of
  // re-deriving it per dash inside R2D_DrawLine.
  float half_width = stroke_width / 2.0f;
  float px = -uy * half_width;
  float py =  ux * half_width;

  // Batch every dash into one geometry submission: one quad (4 vertices,
  // 6 indices) per dash. length / step is bounded by max_segments above, so
  // this allocation is bounded; + 2 covers the partial trailing dash.
  int max_dashes = (int)(length / step) + 2;
  SDL_Vertex *vertices = (SDL_Vertex *)malloc((size_t)max_dashes * 4 * sizeof(SDL_Vertex));
  int *indices = (int *)malloc((size_t)max_dashes * 6 * sizeof(int));
  if (!vertices || !indices) {
    free(vertices);
    free(indices);
    return;
  }

  int q = 0;
  float pos = 0.0f;
  while (pos < length) {
    float end = pos + dash;
    if (end > length) end = length;

    float sx1 = x1 + ux * pos,  sy1 = y1 + uy * pos;
    float sx2 = x1 + ux * end,  sy2 = y1 + uy * end;

    float t1 = pos / length;
    float t2 = end / length;

    // Top edge: lerp c1 -> c4 along length
    float sr1 = r1 + (r4 - r1) * t1, sg1 = g1 + (g4 - g1) * t1;
    float sb1 = b1 + (b4 - b1) * t1, sa1 = a1 + (a4 - a1) * t1;
    float er1 = r1 + (r4 - r1) * t2, eg1 = g1 + (g4 - g1) * t2;
    float eb1 = b1 + (b4 - b1) * t2, ea1 = a1 + (a4 - a1) * t2;

    // Bottom edge: lerp c2 -> c3 along length
    float sr2 = r2 + (r3 - r2) * t1, sg2 = g2 + (g3 - g2) * t1;
    float sb2 = b2 + (b3 - b2) * t1, sa2 = a2 + (a3 - a2) * t1;
    float er2 = r2 + (r3 - r2) * t2, eg2 = g2 + (g3 - g2) * t2;
    float eb2 = b2 + (b3 - b2) * t2, ea2 = a2 + (a3 - a2) * t2;

    // Same four corners and winding as R2D_DrawLine, written straight into the
    // batch: start + perp, start - perp, end - perp, end + perp.
    int v = q * 4;
    vertices[v + 0] = (SDL_Vertex){
      .position  = { sx1 + px, sy1 + py },
      .color     = { sr1, sg1, sb1, sa1 },
      .tex_coord = { 0.0f, 0.0f }
    };
    vertices[v + 1] = (SDL_Vertex){
      .position  = { sx1 - px, sy1 - py },
      .color     = { sr2, sg2, sb2, sa2 },
      .tex_coord = { 0.0f, 0.0f }
    };
    vertices[v + 2] = (SDL_Vertex){
      .position  = { sx2 - px, sy2 - py },
      .color     = { er2, eg2, eb2, ea2 },
      .tex_coord = { 0.0f, 0.0f }
    };
    vertices[v + 3] = (SDL_Vertex){
      .position  = { sx2 + px, sy2 + py },
      .color     = { er1, eg1, eb1, ea1 },
      .tex_coord = { 0.0f, 0.0f }
    };

    int ix = q * 6;
    indices[ix + 0] = v + 0;
    indices[ix + 1] = v + 1;
    indices[ix + 2] = v + 2;
    indices[ix + 3] = v + 0;
    indices[ix + 4] = v + 2;
    indices[ix + 5] = v + 3;

    q++;
    pos += step;
  }

  if (q > 0) {
    R2D_CheckSDL(
      SDL_RenderGeometry(R2D_GetRenderer(), NULL, vertices, q * 4, indices, q * 6),
      "SDL_RenderGeometry");
  }

  free(vertices);
  free(indices);
}


/*
 * Stroke an ellipse outline as a ring of triangles via SDL_RenderGeometry.
 * Outer radius is (rx + sw/2, ry + sw/2), inner is (rx - sw/2, ry - sw/2),
 * putting the stroke centered on the ellipse line.
 */
void R2D_StrokeEllipse(float cx, float cy, float rx, float ry, float angle,
                       int sectors, float stroke_width,
                       float r, float g, float b, float a) {

  if (stroke_width <= 0.0f) return;
  if (sectors < R2D_MIN_SECTORS) sectors = R2D_MIN_SECTORS;
  if (sectors > R2D_MAX_SECTORS) sectors = R2D_MAX_SECTORS;

  float hw = stroke_width / 2.0f;
  float orx = rx + hw, ory = ry + hw;
  float irx = rx - hw, iry = ry - hw;
  if (irx < 0.0f) irx = 0.0f;
  if (iry < 0.0f) iry = 0.0f;

  int num_vertices = sectors * 2;
  int num_indices = sectors * 6;

  // Default 30 sectors fits the stack; fall back to the heap only past the
  // threshold. Avoids two malloc/free pairs per stroke on the per-frame path.
  SDL_Vertex vertices_stack[R2D_STROKE_STACK_N * 2];
  int indices_stack[R2D_STROKE_STACK_N * 6];

  SDL_Vertex *vertices;
  int *indices;
  bool heap = sectors > R2D_STROKE_STACK_N;

  if (heap) {
    vertices = (SDL_Vertex *)malloc(num_vertices * sizeof(SDL_Vertex));
    indices  = (int *)malloc(num_indices * sizeof(int));
    if (!vertices || !indices) {
      free(vertices); free(indices);
      return;
    }
  } else {
    vertices = vertices_stack;
    indices  = indices_stack;
  }

  // Unit-circle cos/sin come from the cached table (no per-vertex trig); only a
  // table-build failure falls back to computing them inline.
  const float *uc, *us;
  bool cached = R2D_UnitCircle(sectors, &uc, &us);
  float angle_step = cached ? 0.0f : (2.0f * M_PI) / sectors;
  // Tilt both rims by `angle` (radians); identity when angle is 0.
  float rot_c = 1.0f, rot_s = 0.0f;
  if (angle != 0.0f) { rot_c = cosf(angle); rot_s = sinf(angle); }
  for (int i = 0; i < sectors; i++) {
    float ca = cached ? uc[i] : cosf(i * angle_step);
    float sa = cached ? us[i] : sinf(i * angle_step);

    float oox = orx * ca, ooy = ory * sa;   // outer rim offset
    float iox = irx * ca, ioy = iry * sa;    // inner rim offset
    vertices[i * 2].position.x = cx + oox * rot_c - ooy * rot_s;
    vertices[i * 2].position.y = cy + oox * rot_s + ooy * rot_c;
    vertices[i * 2].color.r = r;
    vertices[i * 2].color.g = g;
    vertices[i * 2].color.b = b;
    vertices[i * 2].color.a = a;
    vertices[i * 2].tex_coord.x = 0.0f;
    vertices[i * 2].tex_coord.y = 0.0f;

    vertices[i * 2 + 1].position.x = cx + iox * rot_c - ioy * rot_s;
    vertices[i * 2 + 1].position.y = cy + iox * rot_s + ioy * rot_c;
    vertices[i * 2 + 1].color.r = r;
    vertices[i * 2 + 1].color.g = g;
    vertices[i * 2 + 1].color.b = b;
    vertices[i * 2 + 1].color.a = a;
    vertices[i * 2 + 1].tex_coord.x = 0.0f;
    vertices[i * 2 + 1].tex_coord.y = 0.0f;
  }

  for (int i = 0; i < sectors; i++) {
    int j = (i + 1) % sectors;
    int oi = i * 2,      ii = i * 2 + 1;
    int oj = j * 2,      ij = j * 2 + 1;

    indices[i * 6]     = oi;
    indices[i * 6 + 1] = ii;
    indices[i * 6 + 2] = ij;
    indices[i * 6 + 3] = oi;
    indices[i * 6 + 4] = ij;
    indices[i * 6 + 5] = oj;
  }

  R2D_CheckSDL(SDL_RenderGeometry(R2D_GetRenderer(), NULL,
                                  vertices, num_vertices, indices, num_indices),
               "SDL_RenderGeometry");

  if (heap) {
    free(indices);
    free(vertices);
  }
}


/*
 * Draws a filled triangle with per-vertex colors.
 *
 * Parameters:
 *   x, y - Vertex position coordinates
 *   r, g, b, a - Vertex color values (red, green, blue, alpha)
 *   The numbers specify the coordinates and color for each vertex of the triangle
 *
 * The triangle is rendered using the current SDL renderer, and colors are
 * interpolated between vertices.
 */
void R2D_DrawTriangle(float x1, float y1,
                      float r1, float g1, float b1, float a1,
                      float x2, float y2,
                      float r2, float g2, float b2, float a2,
                      float x3, float y3,
                      float r3, float g3, float b3, float a3) {

  SDL_Vertex vertices[3] = {{
      .position  = { x1, y1 },
      .color     = { r1, g1, b1, a1 },
      .tex_coord = { 0.0f, 0.0f }
    }, {
      .position  = { x2, y2 },
      .color     = { r2, g2, b2, a2 },
      .tex_coord = { 0.0f, 0.0f }
    }, {
      .position  = { x3, y3 },
      .color     = { r3, g3, b3, a3 },
      .tex_coord = { 0.0f, 0.0f }
  }};

  R2D_CheckSDL(
    SDL_RenderGeometry(R2D_GetRenderer(), NULL, vertices, 3, NULL, 0),
    "SDL_RenderGeometry");
}


/*
 * Draws a filled quad with per-vertex colors.
 *
 * Parameters:
 *   x, y - Vertex position coordinates for each of the 4 corners
 *   r, g, b, a - Vertex color values (red, green, blue, alpha) for each corner
 *
 * The quad is rendered as two triangles with interpolated colors.
 */
void R2D_DrawQuad(float x1, float y1,
                  float r1, float g1, float b1, float a1,
                  float x2, float y2,
                  float r2, float g2, float b2, float a2,
                  float x3, float y3,
                  float r3, float g3, float b3, float a3,
                  float x4, float y4,
                  float r4, float g4, float b4, float a4) {

  SDL_Vertex vertices[4] = {{
      .position  = { x1, y1 },
      .color     = { r1, g1, b1, a1 },
      .tex_coord = { 0.0f, 0.0f }
    }, {
      .position  = { x2, y2 },
      .color     = { r2, g2, b2, a2 },
      .tex_coord = { 0.0f, 0.0f }
    }, {
      .position  = { x3, y3 },
      .color     = { r3, g3, b3, a3 },
      .tex_coord = { 0.0f, 0.0f }
    }, {
      .position  = { x4, y4 },
      .color     = { r4, g4, b4, a4 },
      .tex_coord = { 0.0f, 0.0f }
  }};

  // Indices for two triangles forming the quad
  int indices[6] = { 0, 1, 2, 0, 2, 3 };

  R2D_CheckSDL(
    SDL_RenderGeometry(R2D_GetRenderer(), NULL, vertices, 4, indices, 6),
    "SDL_RenderGeometry");
}


/*
 * Draws a line with specified width and per-vertex colors.
 *
 * Parameters:
 *   x1, y1 - Start point of the line
 *   x2, y2 - End point of the line
 *   width - Thickness of the line
 *   r, g, b, a - Color values for each of the 4 corners of the line quad
 *
 * The line is rendered as a quad perpendicular to the line direction.
 */
void R2D_DrawLine(float x1, float y1, float x2, float y2,
                  float width,
                  float r1, float g1, float b1, float a1,
                  float r2, float g2, float b2, float a2,
                  float r3, float g3, float b3, float a3,
                  float r4, float g4, float b4, float a4) {

  // Calculate the direction vector of the line
  float dx = x2 - x1;
  float dy = y2 - y1;

  // Calculate the length of the line
  float length = sqrtf(dx * dx + dy * dy);

  // Avoid division by zero for zero-length lines and skip non-positive widths
  // (a negative width would swap the quad sides and still fill a visible band)
  if (length == 0.0f || width <= 0.0f) return;

  // Calculate the perpendicular unit vector scaled by half width
  float half_width = width / 2.0f;
  float px = (-dy / length) * half_width;
  float py = (dx / length) * half_width;

  // Calculate the four corners of the line quad
  SDL_Vertex vertices[4] = {{
      .position  = { x1 + px, y1 + py },
      .color     = { r1, g1, b1, a1 },
      .tex_coord = { 0.0f, 0.0f }
    }, {
      .position  = { x1 - px, y1 - py },
      .color     = { r2, g2, b2, a2 },
      .tex_coord = { 0.0f, 0.0f }
    }, {
      .position  = { x2 - px, y2 - py },
      .color     = { r3, g3, b3, a3 },
      .tex_coord = { 0.0f, 0.0f }
    }, {
      .position  = { x2 + px, y2 + py },
      .color     = { r4, g4, b4, a4 },
      .tex_coord = { 0.0f, 0.0f }
  }};

  // Indices for two triangles forming the quad
  int indices[6] = { 0, 1, 2, 0, 2, 3 };

  R2D_CheckSDL(
    SDL_RenderGeometry(R2D_GetRenderer(), NULL, vertices, 4, indices, 6),
    "SDL_RenderGeometry");
}


/*
 * Draws a filled circle with a solid color.
 *
 * Parameters:
 *   x, y - Center position of the circle
 *   radius - Radius of the circle
 *   sectors - Number of triangular sectors (higher = smoother circle)
 *   r, g, b, a - Color values for the circle
 *
 * The circle is rendered as a triangle fan from the center.
 */
void R2D_DrawCircle(float x, float y, float radius, int sectors,
                    float r, float g, float b, float a) {

  // A circle is an ellipse with equal radii. Delegating reuses the ellipse
  // rasterizer's heap allocation and NULL checks instead of stack VLAs.
  R2D_DrawEllipse(x, y, radius, radius, 0.0f, sectors, r, g, b, a);
}
