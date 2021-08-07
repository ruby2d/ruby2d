// image.c

#include "ruby2d.h"


/*
 * Create an image, given a file path
 */
R2D_Image *R2D_CreateImage(const char *path) {
  R2D_Init();

  // Check if image file exists
  if (!R2D_FileExists(path)) {
    R2D_Error("R2D_CreateImage", "Image file `%s` not found", path);
    return NULL;
  }

  // Allocate the image structure
  R2D_Image *img = (R2D_Image *) malloc(sizeof(R2D_Image));
  if (!img) {
    R2D_Error("R2D_CreateImage", "Out of memory!");
    return NULL;
  }

  // Load image from file as SDL_Surface
  img->surface = IMG_Load(path);
  if (!img->surface) {
    R2D_Error("IMG_Load", IMG_GetError());
    free(img);
    return NULL;
  }

  int bits_per_color = img->surface->format->Amask == 0 ?
    img->surface->format->BitsPerPixel / 3 :
    img->surface->format->BitsPerPixel / 4;

  if (bits_per_color < 8) {
    R2D_Log(R2D_WARN, "`%s` has less than 8 bits per color and will likely not render correctly", path, bits_per_color);
  }

  // Initialize values
  img->path = path;
  img->x = 0;
  img->y = 0;
  img->color.r = 1.f;
  img->color.g = 1.f;
  img->color.b = 1.f;
  img->color.a = 1.f;
  img->orig_width  = img->surface->w;
  img->orig_height = img->surface->h;
  img->width  = img->orig_width;
  img->height = img->orig_height;
  img->rotate = 0;
  img->rx = 0;
  img->ry = 0;
  img->texture_id = 0;

  // Detect image mode
  img->format = GL_RGB;
  if (img->surface->format->BytesPerPixel == 4) {
    img->format = GL_RGBA;
  }

  // Flip image bits if BGA

  Uint32 r = img->surface->format->Rmask;
  Uint32 g = img->surface->format->Gmask;
  Uint32 a = img->surface->format->Amask;

  if (r&0xFF000000 || r&0xFF0000) {
    char *p = (char *)img->surface->pixels;
    int bpp = img->surface->format->BytesPerPixel;
    int w = img->surface->w;
    int h = img->surface->h;
    char tmp;
    for (int i = 0; i < bpp * w * h; i += bpp) {
      if (a&0xFF) {
        tmp = p[i];
        p[i] = p[i+3];
        p[i+3] = tmp;
      }
      if (g&0xFF0000) {
        tmp = p[i+1];
        p[i+1] = p[i+2];
        p[i+2] = tmp;
      }
      if (r&0xFF0000) {
        tmp = p[i];
        p[i] = p[i+2];
        p[i+2] = tmp;
      }
    }
  }

  return img;
}


/*
 * Free an image
 */
void R2D_FreeImage(R2D_Image *img) {
  if (!img) return;
  R2D_GL_FreeTexture(&img->texture_id);
  free(img);
}
