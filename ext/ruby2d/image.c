// image.c

#include "ruby2d.h"


SDL_Surface *R2D_CreateImageSurface(const char *path) {
  R2D_Init();

  // Check if image file exists
  if (!R2D_FileExists(path)) {
    R2D_Error("R2D_CreateImageSurface", "Image file `%s` not found", path);
    return NULL;
  }

  // Load image from file as SDL_Surface
  SDL_Surface *surface = IMG_Load(path);

  int bits_per_color = surface->format->Amask == 0 ?
    surface->format->BitsPerPixel / 3 :
    surface->format->BitsPerPixel / 4;

  if (bits_per_color < 8) {
    R2D_Log(R2D_WARN, "`%s` has less than 8 bits per color and will likely not render correctly", path, bits_per_color);
  }

  return surface;
}

void R2D_ImageConvertToRGB(SDL_Surface *surface) {
  Uint32 r = surface->format->Rmask;
  Uint32 g = surface->format->Gmask;
  Uint32 a = surface->format->Amask;

  if (r&0xFF000000 || r&0xFF0000) {
    char *p = (char *)surface->pixels;
    int bpp = surface->format->BytesPerPixel;
    int w = surface->w;
    int h = surface->h;
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
}
