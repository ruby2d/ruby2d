// font.c

#include "ruby2d.h"


/*
 * Create a TTF_Font object given a path to a font and a size
 */
TTF_Font *R2D_FontCreateTTFFont(const char *path, int size) {

 // Check if font file exists
  if (!R2D_FileExists(path)) {
    R2D_Error("R2D_FontCreateTTFFont", "Font file `%s` not found", path);
    return NULL;
  }

  TTF_Font *font = TTF_OpenFont(path, size);

  if (!font) {
    R2D_Error("TTF_OpenFont", TTF_GetError());
    return NULL;
  }

  return font;
}
