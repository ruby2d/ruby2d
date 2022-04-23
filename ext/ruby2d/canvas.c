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

/*
 * Draw a thick circle on a canvas using a pre-converted RGBA colour value.
 * @param [int] thickness must be > 1, else does nothing
 */
void R2D_Canvas_DrawThickCircle(SDL_Renderer *render, 
                       int x, int y, float radius, float sectors, int thickness, 
                       int r, int g, int b, int a) {
  if (thickness <= 1) {
    return;
  }

  // renders a thick circle by treating each segment as a monotonic quad
  // and rendering as two triangles per segment
  SDL_Vertex verts[4];

  // colour all vertices
  verts[3].color = verts[2].color = verts[1].color = verts[0].color = (SDL_Color) {
      .r = r, .g = g, .b = b, .a = a
  };
  float half_thick = thickness / 2.0f;
  float outer_radius = radius + half_thick;
  float inner_radius = radius - half_thick;
  float cache_cosf = cosf(0), cache_sinf = sinf(0);
  float angle = 2 * M_PI / sectors;

  int indices[] = { 0, 1, 3, 3, 1, 2 };

  // point at 0 radians
  verts[0].position = (SDL_FPoint) { 
    .x = x + outer_radius * cache_cosf, 
    .y = y + outer_radius * cache_sinf
  };
  verts[3].position = (SDL_FPoint) { 
    .x = x + inner_radius * cache_cosf, 
    .y = y + inner_radius * cache_sinf
  };
  for (float i = 1; i <= sectors; i++) {
    // re-use index 0 and 3 from previous calculation
    verts[1].position = verts[0].position;
    verts[2].position = verts[3].position;
    // calculate new index 0 and 3 values
    cache_cosf = cosf(i * angle);
    cache_sinf = sinf(i * angle);
    verts[0].position = (SDL_FPoint) { 
      .x = x + outer_radius * cache_cosf, 
      .y = y + outer_radius * cache_sinf
    };
    verts[3].position = (SDL_FPoint) { 
      .x = x + inner_radius * cache_cosf, 
      .y = y + inner_radius * cache_sinf
    };
    SDL_RenderGeometry(render, NULL, verts, 4, indices, 6);
  }
}