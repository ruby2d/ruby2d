// font.c

#include "ruby2d.h"


/*
 * Create a TTF_Font object given a path to a font and a size
 */
TTF_Font *R2D_FontCreateTTFFont(const char *path, int size, const char *style) {

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

  if(strncmp(style, "bold", 4) == 0) {
    TTF_SetFontStyle(font, TTF_STYLE_BOLD);
  } else if(strncmp(style, "italic", 6) == 0) {
    TTF_SetFontStyle(font, TTF_STYLE_ITALIC);
  } else if(strncmp(style, "underline", 9) == 0) {
    TTF_SetFontStyle(font, TTF_STYLE_UNDERLINE);
  } else if(strncmp(style, "strikethrough", 13) == 0) {
    TTF_SetFontStyle(font, TTF_STYLE_STRIKETHROUGH);
  }

  return font;
}
