// font.c

#include "ruby2d.h"


/*
 * Free the font
 */
void R2D_FreeFont(R2D_Music *mus) {
  if (!mus) return;
  Mix_FreeMusic(mus->data);
  free(mus);
}