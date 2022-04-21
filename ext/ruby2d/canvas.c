// canvas.c

#include "ruby2d.h"

typedef struct {
  float x;
  float y;
} vector_t;

static float vector_magnitude(const vector_t *vec) {
  return sqrtf((vec->x * vec->x) + (vec->y * vec->y));
}

static vector_t *vector_normalize_self(vector_t *vec) {
  float mag = vector_magnitude(vec);
  if (mag == 0) mag = INFINITY;
  vec->x /= mag;
  vec->y /= mag;
  return vec;
}

static vector_t *vector_perpendicular_self(vector_t *vec) {
  float tmp_x = vec->x;
  vec->x = vec->y;
  vec->y = -tmp_x;
  return vec;
}

static vector_t *vector_multiply_self(vector_t *vec, float value) {
  vec->x *= value;
  vec->y *= value;
  return vec;
}

/*
 * Draw a thick line on a canvas using a pre-converted RGBA colour value.
 * @param [int] thickness must be > 1, else does nothing
 */
void R2D_Canvas_DrawThickLine(SDL_Renderer *render, 
                       int x1, int y1, int x2, int y2, int thickness, 
                       int r, int g, int b, int a) {

  if (thickness <= 1) {
    return;
  }

  vector_t vec = { .x = (x2 - x1), .y = (y2 - y1) };
  
  // calculate perpendicular with half-thickness in place
  vector_multiply_self(vector_perpendicular_self(vector_normalize_self(&vec)), thickness / 2.0f);
  
  // calculate perp vertices based on thickness
  SDL_Vertex verts[4];

  verts[0].position = (SDL_FPoint) { .x = x1 + vec.x, .y = y1 + vec.y };
  verts[1].position = (SDL_FPoint) { .x = x2 + vec.x, .y = y2 + vec.y };
  verts[2].position = (SDL_FPoint) { .x = x2 - vec.x, .y = y2 - vec.y };
  verts[3].position = (SDL_FPoint) { .x = x1 - vec.x, .y = y1 - vec.y };

  // set the vertex colour
  for (register int i=0; i< 4; i++) {
    verts[i].color = (SDL_Color) {
      .r = r, .g = g, .b = b, .a = a
    };
  }

  // sub-divide the two triangles; we know this is convex
  int indices[] = { 0, 1, 2, 2, 3, 0 };
  SDL_RenderGeometry(render, NULL, verts, 4, indices, 6);
}
