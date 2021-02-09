// input.c

#include "ruby2d.h"


/*
 * Get the mouse coordinates relative to the viewport
 */
void R2D_GetMouseOnViewport(R2D_Window *window, int wx, int wy, int *x, int *y) {

  double scale;  // viewport scale factor
  int w, h;      // width and height of scaled viewport

  switch (window->viewport.mode) {

    case R2D_FIXED: case R2D_EXPAND:
      *x = wx / (window->orig_width  / (double)window->viewport.width);
      *y = wy / (window->orig_height / (double)window->viewport.height);
      break;

    case R2D_SCALE:
      R2D_GL_GetViewportScale(window, &w, &h, &scale);
      *x = wx * 1 / scale - (window->width  - w) / (2.0 * scale);
      *y = wy * 1 / scale - (window->height - h) / (2.0 * scale);
      break;

    case R2D_STRETCH:
      *x = wx * window->viewport.width  / (double)window->width;
      *y = wy * window->viewport.height / (double)window->height;
      break;
  }
}


/*
 * Show the cursor over the window
 */
void R2D_ShowCursor() {
  SDL_ShowCursor(SDL_ENABLE);
}


/*
 * Hide the cursor over the window
 */
void R2D_HideCursor() {
  SDL_ShowCursor(SDL_DISABLE);
}
