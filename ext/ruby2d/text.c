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

  return surface;
}