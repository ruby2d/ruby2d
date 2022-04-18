// canvas.c

#include "ruby2d.h"

Uint32 R2D_Canvas_Color2RGBA(SDL_Surface *surf, double r, double g, double b, double a) {
  return SDL_MapRGBA(surf->format, r * 255, g * 255, b * 255, a * 255);
}

/*
 * Draw a filled rectangle on a canvas using a pre-converted RGBA colour value.
 */
void R2D_Canvas_FillRect_RGBA(SDL_Surface *surf, int x, int y, int w, int h, Uint32 rgba) {
  SDL_Rect rect = { .x = x, .y = y, .w = w, .h = h };
  SDL_FillRect(surf, &rect, rgba);
}

/*
 * Draw the outline of a rectangle on a canvas using a pre-converted RGBA colour value.
 */
void R2D_Canvas_DrawRect_RGBA(SDL_Surface *surf, int x, int y, int w, int h, Uint32 rgba) {
  SDL_Rect rect = { .x = x, .y = y, .w = w, .h = 1 };
  SDL_FillRect(surf, &rect, rgba);    // top side
  rect.h = h; rect.w = 1;
  SDL_FillRect(surf, &rect, rgba);    // left side
  rect.x += w - 1;
  SDL_FillRect(surf, &rect, rgba);    // right side
  rect.x = x; rect.w = w; rect.h = 1; rect.y += h - 1;
  SDL_FillRect(surf, &rect, rgba);    // bottom side
}

/*
 * Draw a thick line on a canvas using a pre-converted RGBA colour value.
 */
void R2D_Canvas_DrawLine_RGBA(SDL_Surface *surf, int x1, int y1, int x2, int y2, int thickness, Uint32 rgba) {
  double x = x2 - x1;
  double y = y2 - y1;
  double length = sqrt(x*x + y*y);
  double addx = x / length;
  double addy = y / length;
  x = x1;
  y = y1;

  // Draw the pixel on the canvas
  for (int i = 0; i < length; i += 1) {
    R2D_Canvas_FillRect_RGBA(
      surf, x, y,
      thickness, thickness,  // w & h are same val, the pixel "size" based on thickness
      rgba
    );
    x += addx;
    y += addy;
  }

}