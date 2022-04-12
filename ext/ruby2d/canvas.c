// canvas.c

#include "ruby2d.h"

/*
 * Draw a rectangle on a canvas
 */
void R2D_Canvas_DrawRect(SDL_Surface *surf, int x, int y, int w, int h, double r, double g, double b, double a) {
  SDL_Rect rect = { .x = x, .y = y, .w = w, .h = h };
  SDL_FillRect(surf, &rect, SDL_MapRGBA(surf->format, r * 255, g * 255, b * 255, a * 255));
}
