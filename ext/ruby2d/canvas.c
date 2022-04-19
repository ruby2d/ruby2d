// canvas.c

#include "ruby2d.h"

/*
 * Draw a thick line on a canvas using a pre-converted RGBA colour value.
 */
void R2D_Canvas_DrawLine(SDL_Renderer *render, int x1, int y1, int x2, int y2, int thickness) {
  if (thickness == 1) {
    SDL_RenderDrawLine(render, x1, y1, x2, y2);
    return;
  }
  // TODO replace with a polygon filler for thick lines
  // ------------

  // thick line, draw using fill rectangles
  float x = x2 - x1;
  float y = y2 - y1;
  float length = sqrt(x*x + y*y);
  float addx = x / length;
  float addy = y / length;
  x = x1;
  y = y1;
  SDL_Rect pixel = { .x = x, .y = y, .w = thickness, .h = thickness };

  // Draw think lines without blending for now
  SDL_SetRenderDrawBlendMode(render, SDL_BLENDMODE_NONE);
  // Draw the pixel on the canvas
  for (int i = 0; i < length; i += 1) {
    pixel.x = x;
    pixel.y = y;
    SDL_RenderFillRect(render, &pixel);
    x += addx;
    y += addy;
  }
  SDL_SetRenderDrawBlendMode(render, SDL_BLENDMODE_BLEND);
}