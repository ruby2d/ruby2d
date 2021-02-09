// sprite.c

#include "ruby2d.h"


/*
 * Create a sprite, given an image file path
 */
R2D_Sprite *R2D_CreateSprite(const char *path) {

  // Check if image file exists
  if (!R2D_FileExists(path)) {
    R2D_Error("R2D_CreateSprite", "Sprite image file `%s` not found", path);
    return NULL;
  }

  // Allocate the sprite structure
  R2D_Sprite *spr = (R2D_Sprite *) malloc(sizeof(R2D_Sprite));
  if (!spr) {
    R2D_Error("R2D_CreateSprite", "Out of memory!");
    return NULL;
  }

  // Load the sprite image file
  spr->img = R2D_CreateImage(path);
  if (!spr->img) {
    R2D_Error("R2D_CreateSprite", "Cannot create sprite image `%s`", path);
    free(spr);
    return NULL;
  }

  // Initialize values
  spr->path = path;
  spr->x = 0;
  spr->y = 0;
  spr->color.r = 1.f;
  spr->color.g = 1.f;
  spr->color.b = 1.f;
  spr->color.a = 1.f;
  spr->width  = spr->img->width;
  spr->height = spr->img->height;
  spr->clip_width  = spr->img->width;
  spr->clip_height = spr->img->height;
  spr->rotate = 0;
  spr->rx = 0;
  spr->ry = 0;
  spr->tx1 = 0.f;
  spr->ty1 = 0.f;
  spr->tx2 = 1.f;
  spr->ty2 = 0.f;
  spr->tx3 = 1.f;
  spr->ty3 = 1.f;
  spr->tx4 = 0.f;
  spr->ty4 = 1.f;

  return spr;
}


/*
 * Clip a sprite
 */
void R2D_ClipSprite(R2D_Sprite *spr, int x, int y, int w, int h) {
  if (!spr) return;

  // Calculate ratios
  // rw = ratio width; rh = ratio height
  double rw = w / (double)spr->img->width;
  double rh = h / (double)spr->img->height;

  // Apply ratios to x, y coordinates
  // cx = crop x coord; cy = crop y coord
  double cx = x * rw;
  double cy = y * rh;

  // Convert given width, height to doubles
  // cw = crop width; ch = crop height
  double cw = (double)w;
  double ch = (double)h;

  // Apply ratio to texture width and height
  // tw = texture width; th = texture height
  double tw = rw * w;
  double th = rh * h;

  // Calculate and store sprite texture values

  spr->tx1 =  cx       / cw;
  spr->ty1 =  cy       / ch;

  spr->tx2 = (cx + tw) / cw;
  spr->ty2 =  cy       / ch;

  spr->tx3 = (cx + tw) / cw;
  spr->ty3 = (cy + th) / ch;

  spr->tx4 =  cx       / cw;
  spr->ty4 = (cy + th) / ch;

  // Store the sprite dimensions
  spr->width  = (spr->width  / (double)spr->clip_width ) * w;
  spr->height = (spr->height / (double)spr->clip_height) * h;
  spr->clip_width  = w;
  spr->clip_height = h;
}


/*
 * Rotate a sprite
 */
void R2D_RotateSprite(R2D_Sprite *spr, GLfloat angle, int position) {

  R2D_GL_Point p = R2D_GetRectRotationPoint(
    spr->x, spr->y, spr->width, spr->height, position
  );

  spr->rotate = angle;
  spr->rx = p.x;
  spr->ry = p.y;
}


/*
 * Draw a sprite
 */
void R2D_DrawSprite(R2D_Sprite *spr) {
  if (!spr) return;

  if (spr->img->texture_id == 0) {
    R2D_GL_CreateTexture(&spr->img->texture_id, spr->img->format,
                         spr->img->width, spr->img->height,
                         spr->img->surface->pixels, GL_NEAREST);
    SDL_FreeSurface(spr->img->surface);
  }

  R2D_GL_DrawSprite(spr);
}


/*
 * Free a sprite
 */
void R2D_FreeSprite(R2D_Sprite *spr) {
  if (!spr) return;
  R2D_FreeImage(spr->img);
  free(spr);
}
