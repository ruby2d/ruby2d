// text.c

#include "ruby2d.h"


/*
 * Create text, given a font file path, the message, and size
 */
R2D_Text *R2D_CreateText(const char *font, const char *msg, int size) {
  R2D_Init();

  // Check if font file exists
  if (!R2D_FileExists(font)) {
    R2D_Error("R2D_CreateText", "Font file `%s` not found", font);
    return NULL;
  }

  // `msg` cannot be an empty string or NULL for TTF_SizeText
  if (msg == NULL || strlen(msg) == 0) msg = " ";

  // Allocate the text structure
  R2D_Text *txt = (R2D_Text *) malloc(sizeof(R2D_Text));
  if (!txt) {
    R2D_Error("R2D_CreateText", "Out of memory!");
    return NULL;
  }

  // Open the font
  txt->font_data = TTF_OpenFont(font, size);
  if (!txt->font_data) {
    R2D_Error("TTF_OpenFont", TTF_GetError());
    free(txt);
    return NULL;
  }

  // Initialize values
  txt->font = font;
  txt->msg = (char *) malloc(strlen(msg) + 1 * sizeof(char));
  strcpy(txt->msg, msg);
  txt->x = 0;
  txt->y = 0;
  txt->color.r = 1.f;
  txt->color.g = 1.f;
  txt->color.b = 1.f;
  txt->color.a = 1.f;
  txt->rotate = 0;
  txt->rx = 0;
  txt->ry = 0;
  txt->texture_id = 0;

  // Save the width and height of the text
  TTF_SizeUTF8(txt->font_data, txt->msg, &txt->width, &txt->height);

  return txt;
}


/*
 * Set the text message
 */
void R2D_SetText(R2D_Text *txt, const char *msg, ...) {
  if (!txt) return;

  // `msg` cannot be an empty string or NULL for TTF_SizeUTF8
  if (msg == NULL || strlen(msg) == 0) msg = " ";

  // Format and store new text string
  va_list args;
  va_start(args, msg);
  free(txt->msg);
  vasprintf(&txt->msg, msg, args);
  va_end(args);

  // Save the width and height of the text
  TTF_SizeUTF8(txt->font_data, txt->msg, &txt->width, &txt->height);

  // Delete the current texture so a new one can be generated
  R2D_GL_FreeTexture(&txt->texture_id);
}


/*
 * Rotate text
 */
void R2D_RotateText(R2D_Text *txt, GLfloat angle, int position) {

  R2D_GL_Point p = R2D_GetRectRotationPoint(
    txt->x, txt->y, txt->width, txt->height, position
  );

  txt->rotate = angle;
  txt->rx = p.x;
  txt->ry = p.y;
}


/*
 * Draw text
 */
void R2D_DrawText(R2D_Text *txt) {
  if (!txt) return;

  if (txt->texture_id == 0) {
    SDL_Color color = { 255, 255, 255 };
    txt->surface = TTF_RenderUTF8_Blended(txt->font_data, txt->msg, color);
    if (!txt->surface) {
      R2D_Error("TTF_RenderUTF8_Blended", TTF_GetError());
      return;
    }
    R2D_GL_CreateTexture(&txt->texture_id, GL_RGBA,
                         txt->width, txt->height,
                         txt->surface->pixels, GL_NEAREST);
    SDL_FreeSurface(txt->surface);
  }

  R2D_GL_DrawText(txt);
}


/*
 * Free the text
 */
void R2D_FreeText(R2D_Text *txt) {
  if (!txt) return;
  free(txt->msg);
  R2D_GL_FreeTexture(&txt->texture_id);
  TTF_CloseFont(txt->font_data);
  free(txt);
}
