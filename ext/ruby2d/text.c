// text.c

#include "ruby2d.h"


/*
 * Create a SDL_Surface that contains the pixel data to render text, given a font and message
 */
SDL_Surface *R2D_TextCreateSurface(TTF_Font *font, const char *message) {
  // `msg` cannot be an empty string or NULL for TTF_SizeText
  if (message == NULL || strlen(message) == 0) message = " ";

  SDL_Color color = {255, 255, 255};
  SDL_Surface *surface = TTF_RenderUTF8_Blended(font, message, color);
  if (!surface)
  {
    R2D_Error("TTF_RenderUTF8_Blended", TTF_GetError());
    return NULL;
  }

  // Re-pack surface for OpenGL
  // See: https://discourse.libsdl.org/t/sdl-ttf-2-0-18-surface-to-opengl-texture-not-consistent-with-ttf-2-0-15
  Sint32 i;
  Uint32 len = surface->w * surface->format->BytesPerPixel;
  Uint8 *src = surface->pixels;
  Uint8 *dst = surface->pixels;
  for (i = 0; i < surface->h; i++) {
    SDL_memmove(dst, src, len);
    dst += len;
    src += surface->pitch;
  }
  surface->pitch = len;

  return surface;
}
