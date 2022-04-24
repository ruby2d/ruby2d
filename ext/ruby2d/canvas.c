// canvas.c

#include "ruby2d.h"

typedef SDL_FPoint vector_t;

static float vector_magnitude(const vector_t *vec)
{
  return sqrtf((vec->x * vec->x) + (vec->y * vec->y));
}

static vector_t *vector_normalize(vector_t *vec)
{
  float mag = vector_magnitude(vec);
  if (mag == 0)
    mag = INFINITY;
  vec->x /= mag;
  vec->y /= mag;
  return vec;
}

static vector_t *vector_perpendicular(vector_t *vec)
{
  float tmp_x = vec->x;
  vec->x = vec->y;
  vec->y = -tmp_x;
  return vec;
}

static vector_t *vector_times_scalar(vector_t *vec, float value)
{
  vec->x *= value;
  vec->y *= value;
  return vec;
}

static vector_t *vector_minus_vector(vector_t *vec, const vector_t *other)
{
  vec->x -= other->x;
  vec->y -= other->y;
  return vec;
}

static vector_t *vector_minus_xy(vector_t *vec, float other_x, float other_y)
{
  vec->x -= other_x;
  vec->y -= other_y;
  return vec;
}

static vector_t *vector_plus_vector(vector_t *vec, const vector_t *other)
{
  vec->x += other->x;
  vec->y += other->y;
  return vec;
}

static vector_t *vector_plus_xy(vector_t *vec, float other_x, float other_y)
{
  vec->x += other_x;
  vec->y += other_y;
  return vec;
}

/*
 * Draw a thick line on a canvas using a pre-converted RGBA colour value.
 * @param [int] thickness must be > 1, else does nothing
 */
void R2D_Canvas_DrawThickLine(SDL_Renderer *render, int x1, int y1, int x2,
                              int y2, int thickness, int r, int g, int b, int a)
{

  if (thickness <= 1)
    return;

  vector_t vec = {.x = (x2 - x1), .y = (y2 - y1)};

  // calculate perpendicular with half-thickness in place
  vector_times_scalar(vector_perpendicular(vector_normalize(&vec)),
                      thickness / 2.0f);

  // calculate perp vertices based on thickness
  SDL_Vertex verts[4];

  verts[0].position = (SDL_FPoint){.x = x1 + vec.x, .y = y1 + vec.y};
  verts[1].position = (SDL_FPoint){.x = x2 + vec.x, .y = y2 + vec.y};
  verts[2].position = (SDL_FPoint){.x = x2 - vec.x, .y = y2 - vec.y};
  verts[3].position = (SDL_FPoint){.x = x1 - vec.x, .y = y1 - vec.y};

  // set the vertex colour
  for (register int i = 0; i < 4; i++) {
    verts[i].color = (SDL_Color){.r = r, .g = g, .b = b, .a = a};
  }

  // sub-divide the two triangles; we know this is convex
  int indices[] = {0, 1, 2, 2, 3, 0};
  SDL_RenderGeometry(render, NULL, verts, 4, indices, 6);
}

/*
 * Draw a thick circle on a canvas using a pre-converted RGBA colour value.
 * @param [int] thickness must be > 1, else does nothing
 */
void R2D_Canvas_DrawThickCircle(SDL_Renderer *render, int x, int y,
                                float radius, float sectors, int thickness,
                                int r, int g, int b, int a)
{
  if (thickness <= 1) {
    return;
  }

  // renders a thick circle by treating each segment as a monotonic quad
  // and rendering as two triangles per segment
  SDL_Vertex verts[4];

  // colour all vertices
  verts[3].color = verts[2].color = verts[1].color = verts[0].color =
      (SDL_Color){.r = r, .g = g, .b = b, .a = a};
  float half_thick = thickness / 2.0f;
  float outer_radius = radius + half_thick;
  float inner_radius = radius - half_thick;
  float cache_cosf = cosf(0), cache_sinf = sinf(0);
  float angle = 2 * M_PI / sectors;

  int indices[] = {0, 1, 3, 3, 1, 2};

  // point at 0 radians
  verts[0].position = (SDL_FPoint){.x = x + outer_radius * cache_cosf,
                                   .y = y + outer_radius * cache_sinf};
  verts[3].position = (SDL_FPoint){.x = x + inner_radius * cache_cosf,
                                   .y = y + inner_radius * cache_sinf};
  for (float i = 1; i <= sectors; i++) {
    // re-use index 0 and 3 from previous calculation
    verts[1].position = verts[0].position;
    verts[2].position = verts[3].position;
    // calculate new index 0 and 3 values
    cache_cosf = cosf(i * angle);
    cache_sinf = sinf(i * angle);
    verts[0].position = (SDL_FPoint){.x = x + outer_radius * cache_cosf,
                                     .y = y + outer_radius * cache_sinf};
    verts[3].position = (SDL_FPoint){.x = x + inner_radius * cache_cosf,
                                     .y = y + inner_radius * cache_sinf};
    SDL_RenderGeometry(render, NULL, verts, 4, indices, 6);
  }
}

/*
 * Compute the intersection between two lines represented by the input line
 * segments. Unlike a typical line segment collision detector, this function
 * will find a possible intersection point even if that point is not on either
 * of the input line "segments". This helps find where two line segments "would"
 * intersect if they were long enough, in addition to the case when the segments
 * intersect.
 * @param line1_p1
 * @param line1_p2
 * @param line2_p1
 * @param line2_p2
 * @param intersection Pointer into which to write the point of intersection.
 * @return true if an intersection is found, false if the lines are parallel
 * (collinear).
 */
static bool intersect_two_lines(const vector_t *line1_p1,
                                const vector_t *line1_p2,
                                const vector_t *line2_p1,
                                const vector_t *line2_p2,
                                vector_t *intersection)
{
  vector_t alpha = {.x = line1_p2->x - line1_p1->x,
                    .y = line1_p2->y - line1_p1->y};
  vector_t beta = {.x = line2_p1->x - line2_p2->x,
                   .y = line2_p1->y - line2_p2->y};
  float denom = (alpha.y * beta.x) - (alpha.x * beta.y);

  if (denom == 0)
    return false; // collinear

  vector_t theta = {.x = line1_p1->x - line2_p1->x,
                    .y = line1_p1->y - line2_p1->y};
  float alpha_numerator = beta.y * theta.x - (beta.x * theta.y);
  // float beta_numerator = alpha.x * theta.y - (alpha.y * theta.x);

  intersection->x = alpha.x;
  intersection->y = alpha.y;
  vector_times_scalar(intersection, alpha_numerator / denom);
  vector_plus_vector(intersection, line1_p1);
  return true;
}

/*
 * Draw a thick three-point (two line) polyline, with a mitre join where the two
 * segments are joined.
 * @param [int] thickness must be > 1, else does nothing
 */
void R2D_Canvas_DrawThickPolyline3(SDL_Renderer *render, int x1, int y1, int x2,
                                   int y2, int x3, int y3, int thickness, int r,
                                   int g, int b, int a)
{
  if (thickness <= 1)
    return;

  float thick_half = thickness / 2.0f;

  // line one: (x1, y1) -> (x2, y2)
  // line two: (x2, y2) -> (x3, y3)
  //
  // calculate the unit perpendicular for each of the line segments
  vector_t vec_one_perp = {.x = (x2 - x1), .y = (y2 - y1)};
  vector_times_scalar(vector_normalize(vector_perpendicular(&vec_one_perp)),
                      thick_half);
  vector_t vec_two_perp = {.x = (x3 - x2), .y = (y3 - y2)};
  vector_times_scalar(vector_normalize(vector_perpendicular(&vec_two_perp)),
                      thick_half);

  // Prepare to store the different points used map
  // the triangles that render the thick polyline
  SDL_Vertex verts[10];
  // left outer bottom
  verts[0].position =
      (SDL_FPoint){.x = x1 + vec_one_perp.x, .y = y1 + vec_one_perp.y};
  // left outer top
  verts[1].position =
      (SDL_FPoint){.x = x2 + vec_one_perp.x, .y = y2 + vec_one_perp.y};
  // left inner top
  verts[2].position =
      (SDL_FPoint){.x = x2 - vec_one_perp.x, .y = y2 - vec_one_perp.y};
  // left inner bottom
  verts[3].position =
      (SDL_FPoint){.x = x1 - vec_one_perp.x, .y = y1 - vec_one_perp.y};
  // right inner bottom
  verts[4].position =
      (SDL_FPoint){.x = x3 - vec_two_perp.x, .y = y3 - vec_two_perp.y};
  // right outer bottom
  verts[5].position =
      (SDL_FPoint){.x = x3 + vec_two_perp.x, .y = y3 + vec_two_perp.y};

  // temporarily calculate the "right inner top" to
  // figure out the intersection with the "left inner top" which
  vector_t tmp = {.x = x2 - vec_two_perp.x, .y = y2 - vec_two_perp.y};
  // find intersection of the left/right inner lines
  bool has_intersect = intersect_two_lines(
      &verts[3].position, &verts[2].position, &verts[4].position, &tmp,
      &verts[2].position // over-write
  );

  if (has_intersect) {
    // adjust the "left outer top" point so that it's distance from (x2, y2) is
    // the same as the left/right "inner top" intersection we calculated above
    tmp = (vector_t){.x = x2, .y = y2};
    vector_minus_vector(&tmp, &verts[2].position);
    verts[1].position = (SDL_FPoint){.x = x2 + tmp.x, .y = y2 + tmp.y};

    // all points have the same colour so
    int vcount = 6;
    for (int i = 0; i < vcount; i++) {
      verts[i].color = (SDL_Color){.r = r, .g = g, .b = b, .a = a};
    }
    // setup the index array to define the triangles to render
    int indices[] = {
        0, 1, 2, // left outer triangle
        0, 2, 3, // left inner triangle
        1, 2, 4, // right inner triangle
        1, 4, 5, // right outer triangle
    };
    SDL_RenderGeometry(render, NULL, verts, vcount, indices, 12);
  }
  // else no intersection, which is an extreme case which for now
  // we will ignore and render nothing.
}
