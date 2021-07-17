// tileset.c

#include "ruby2d.h"

/*
 * Draw an image
 */
void R2D_DrawTile(R2D_Image *img, int tw, int th, int padding, int spacing, int tx, int ty, int x, int y) {
  if (!img) return;

  if (img->texture_id == 0) {
    R2D_GL_CreateTexture(&img->texture_id, img->format,
                         img->width, img->height,
                         img->surface->pixels, GL_NEAREST);
    SDL_FreeSurface(img->surface);
  }

  GLfloat tx1 = (double)(padding + ((spacing + tw) * tx)) / (double) img->width ;
  GLfloat tx2 = tx1 + ((double)tw / (double) img->width);
  GLfloat tx3 = tx2;
  GLfloat tx4 = tx1;

  GLfloat ty1 = (double)(padding + ((spacing + th) * ty)) / (double) img ->height;
  GLfloat ty2 = ty1;
  GLfloat ty3 = ty1 + ((double)th / (double) img->height);
  GLfloat ty4 = ty3;

  printf("\n\ntw: %d th: %d padding: %d spacing: %d tx: %d ty: %d\n", tw, th, padding, spacing, tx, ty);
  printf("img->width %d img->height %d x: %d y: %d tx1: %f tx2: %f tx2: %f ty2: %f tx3: %f ty3: %f tx4: %f ty4: %f\n", img->width, img->height, x, y, tx1, ty1, tx2, ty2, tx3, ty3, tx4, ty4);

  R2D_GL_DrawTile(img, x, y, tw, th, tx1, ty1, tx2, ty2, tx3, ty3, tx4, ty4);
}
