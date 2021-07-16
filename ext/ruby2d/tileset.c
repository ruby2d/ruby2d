// tileset.c

#include "ruby2d.h"

/*
 * Draw an image
 */
void R2D_DrawTile(R2D_Image *img, int tw, int th, int padding, int spacing, int tx, int ty, int x, int y) {
  if (!img) return;

  if (img->texture_id == 0) {
    R2D_GL_CreateTexture(&img->texture_id, img->format,
                         img->orig_width, img->orig_height,
                         img->surface->pixels, GL_NEAREST);
    SDL_FreeSurface(img->surface);
  }

  int tx1 = padding + ((spacing + tw) * tx);
  int tx2 = tx1 + tw;
  int tx3 = tx2;
  int tx4 = tx1;

  int ty1 = padding + ((spacing + th) * ty);
  int ty2 = ty1;
  int ty3 = ty1 + th;
  int ty4 = ty3;

  R2D_GL_DrawTile(img, x, y, tx1, ty1, tx2, ty2, tx3, ty3, tx4, ty4);
}
