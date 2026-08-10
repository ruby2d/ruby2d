// font.c — Internal bitmap font for diagnostic overlays
//
// Provides a reusable 5x7 bitmap font covering printable ASCII (0x20–0x7E).
// Text is rendered to a cached SDL_Texture at physical-pixel resolution so it
// stays crisp on HiDPI displays, then drawn at logical coordinates.

#include "ruby2d.h"


// Glyph Data //////////////////////////////////////////////////////////////////
//
// 95 glyphs for printable ASCII (space 0x20 through tilde 0x7E).
// Each glyph is 7 rows of uint8_t. Bits 4..0 encode columns left-to-right
// (bit 4 = leftmost, bit 0 = rightmost).

static const uint8_t r2d_font_glyphs[R2D_FONT_NUM_GLYPHS][R2D_FONT_GLYPH_HEIGHT] = {
  // 0x20  ' ' (space)
  { 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 },
  // 0x21  '!'
  { 0x04, 0x04, 0x04, 0x04, 0x04, 0x00, 0x04 },
  // 0x22  '"'
  { 0x0A, 0x0A, 0x0A, 0x00, 0x00, 0x00, 0x00 },
  // 0x23  '#'
  { 0x0A, 0x0A, 0x1F, 0x0A, 0x1F, 0x0A, 0x0A },
  // 0x24  '$'
  { 0x04, 0x0F, 0x14, 0x0E, 0x05, 0x1E, 0x04 },
  // 0x25  '%'
  { 0x18, 0x19, 0x02, 0x04, 0x08, 0x13, 0x03 },
  // 0x26  '&'
  { 0x0C, 0x12, 0x14, 0x08, 0x15, 0x12, 0x0D },
  // 0x27  '''
  { 0x0C, 0x04, 0x08, 0x00, 0x00, 0x00, 0x00 },
  // 0x28  '('
  { 0x02, 0x04, 0x08, 0x08, 0x08, 0x04, 0x02 },
  // 0x29  ')'
  { 0x08, 0x04, 0x02, 0x02, 0x02, 0x04, 0x08 },
  // 0x2A  '*'
  { 0x00, 0x04, 0x15, 0x0E, 0x15, 0x04, 0x00 },
  // 0x2B  '+'
  { 0x00, 0x04, 0x04, 0x1F, 0x04, 0x04, 0x00 },
  // 0x2C  ','
  { 0x00, 0x00, 0x00, 0x00, 0x0C, 0x04, 0x08 },
  // 0x2D  '-'
  { 0x00, 0x00, 0x00, 0x1F, 0x00, 0x00, 0x00 },
  // 0x2E  '.'
  { 0x00, 0x00, 0x00, 0x00, 0x00, 0x0C, 0x0C },
  // 0x2F  '/'
  { 0x00, 0x01, 0x02, 0x04, 0x08, 0x10, 0x00 },
  // 0x30  '0'
  { 0x0E, 0x11, 0x13, 0x15, 0x19, 0x11, 0x0E },
  // 0x31  '1'
  { 0x04, 0x0C, 0x04, 0x04, 0x04, 0x04, 0x0E },
  // 0x32  '2'
  { 0x0E, 0x11, 0x01, 0x02, 0x04, 0x08, 0x1F },
  // 0x33  '3'
  { 0x1F, 0x02, 0x04, 0x02, 0x01, 0x11, 0x0E },
  // 0x34  '4'
  { 0x02, 0x06, 0x0A, 0x12, 0x1F, 0x02, 0x02 },
  // 0x35  '5'
  { 0x1F, 0x10, 0x1E, 0x01, 0x01, 0x11, 0x0E },
  // 0x36  '6'
  { 0x06, 0x08, 0x10, 0x1E, 0x11, 0x11, 0x0E },
  // 0x37  '7'
  { 0x1F, 0x01, 0x02, 0x04, 0x08, 0x08, 0x08 },
  // 0x38  '8'
  { 0x0E, 0x11, 0x11, 0x0E, 0x11, 0x11, 0x0E },
  // 0x39  '9'
  { 0x0E, 0x11, 0x11, 0x0F, 0x01, 0x02, 0x0C },
  // 0x3A  ':'
  { 0x00, 0x0C, 0x0C, 0x00, 0x0C, 0x0C, 0x00 },
  // 0x3B  ';'
  { 0x00, 0x0C, 0x0C, 0x00, 0x0C, 0x04, 0x08 },
  // 0x3C  '<'
  { 0x02, 0x04, 0x08, 0x10, 0x08, 0x04, 0x02 },
  // 0x3D  '='
  { 0x00, 0x00, 0x1F, 0x00, 0x1F, 0x00, 0x00 },
  // 0x3E  '>'
  { 0x08, 0x04, 0x02, 0x01, 0x02, 0x04, 0x08 },
  // 0x3F  '?'
  { 0x0E, 0x11, 0x01, 0x02, 0x04, 0x00, 0x04 },
  // 0x40  '@'
  { 0x0E, 0x11, 0x17, 0x15, 0x17, 0x10, 0x0E },
  // 0x41  'A'
  { 0x0E, 0x11, 0x11, 0x1F, 0x11, 0x11, 0x11 },
  // 0x42  'B'
  { 0x1E, 0x11, 0x11, 0x1E, 0x11, 0x11, 0x1E },
  // 0x43  'C'
  { 0x0E, 0x11, 0x10, 0x10, 0x10, 0x11, 0x0E },
  // 0x44  'D'
  { 0x1C, 0x12, 0x11, 0x11, 0x11, 0x12, 0x1C },
  // 0x45  'E'
  { 0x1F, 0x10, 0x10, 0x1E, 0x10, 0x10, 0x1F },
  // 0x46  'F'
  { 0x1F, 0x10, 0x10, 0x1E, 0x10, 0x10, 0x10 },
  // 0x47  'G'
  { 0x0E, 0x11, 0x10, 0x17, 0x11, 0x11, 0x0F },
  // 0x48  'H'
  { 0x11, 0x11, 0x11, 0x1F, 0x11, 0x11, 0x11 },
  // 0x49  'I'
  { 0x0E, 0x04, 0x04, 0x04, 0x04, 0x04, 0x0E },
  // 0x4A  'J'
  { 0x07, 0x02, 0x02, 0x02, 0x02, 0x12, 0x0C },
  // 0x4B  'K'
  { 0x11, 0x12, 0x14, 0x18, 0x14, 0x12, 0x11 },
  // 0x4C  'L'
  { 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x1F },
  // 0x4D  'M'
  { 0x11, 0x1B, 0x15, 0x15, 0x11, 0x11, 0x11 },
  // 0x4E  'N'
  { 0x11, 0x11, 0x19, 0x15, 0x13, 0x11, 0x11 },
  // 0x4F  'O'
  { 0x0E, 0x11, 0x11, 0x11, 0x11, 0x11, 0x0E },
  // 0x50  'P'
  { 0x1E, 0x11, 0x11, 0x1E, 0x10, 0x10, 0x10 },
  // 0x51  'Q'
  { 0x0E, 0x11, 0x11, 0x11, 0x15, 0x12, 0x0D },
  // 0x52  'R'
  { 0x1E, 0x11, 0x11, 0x1E, 0x14, 0x12, 0x11 },
  // 0x53  'S'
  { 0x0F, 0x10, 0x10, 0x0E, 0x01, 0x01, 0x1E },
  // 0x54  'T'
  { 0x1F, 0x04, 0x04, 0x04, 0x04, 0x04, 0x04 },
  // 0x55  'U'
  { 0x11, 0x11, 0x11, 0x11, 0x11, 0x11, 0x0E },
  // 0x56  'V'
  { 0x11, 0x11, 0x11, 0x11, 0x11, 0x0A, 0x04 },
  // 0x57  'W'
  { 0x11, 0x11, 0x11, 0x15, 0x15, 0x1B, 0x11 },
  // 0x58  'X'
  { 0x11, 0x11, 0x0A, 0x04, 0x0A, 0x11, 0x11 },
  // 0x59  'Y'
  { 0x11, 0x11, 0x0A, 0x04, 0x04, 0x04, 0x04 },
  // 0x5A  'Z'
  { 0x1F, 0x01, 0x02, 0x04, 0x08, 0x10, 0x1F },
  // 0x5B  '['
  { 0x0E, 0x08, 0x08, 0x08, 0x08, 0x08, 0x0E },
  // 0x5C  '\'
  { 0x00, 0x10, 0x08, 0x04, 0x02, 0x01, 0x00 },
  // 0x5D  ']'
  { 0x0E, 0x02, 0x02, 0x02, 0x02, 0x02, 0x0E },
  // 0x5E  '^'
  { 0x04, 0x0A, 0x11, 0x00, 0x00, 0x00, 0x00 },
  // 0x5F  '_'
  { 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x1F },
  // 0x60  '`'
  { 0x08, 0x04, 0x02, 0x00, 0x00, 0x00, 0x00 },
  // 0x61  'a'
  { 0x00, 0x00, 0x0E, 0x01, 0x0F, 0x11, 0x0F },
  // 0x62  'b'
  { 0x10, 0x10, 0x16, 0x19, 0x11, 0x11, 0x1E },
  // 0x63  'c'
  { 0x00, 0x00, 0x0E, 0x10, 0x10, 0x11, 0x0E },
  // 0x64  'd'
  { 0x01, 0x01, 0x0D, 0x13, 0x11, 0x11, 0x0F },
  // 0x65  'e'
  { 0x00, 0x00, 0x0E, 0x11, 0x1F, 0x10, 0x0E },
  // 0x66  'f'
  { 0x06, 0x09, 0x08, 0x1C, 0x08, 0x08, 0x08 },
  // 0x67  'g'
  { 0x00, 0x0F, 0x11, 0x11, 0x0F, 0x01, 0x0E },
  // 0x68  'h'
  { 0x10, 0x10, 0x16, 0x19, 0x11, 0x11, 0x11 },
  // 0x69  'i'
  { 0x04, 0x00, 0x0C, 0x04, 0x04, 0x04, 0x0E },
  // 0x6A  'j'
  { 0x02, 0x00, 0x06, 0x02, 0x02, 0x12, 0x0C },
  // 0x6B  'k'
  { 0x10, 0x10, 0x12, 0x14, 0x18, 0x14, 0x12 },
  // 0x6C  'l'
  { 0x0C, 0x04, 0x04, 0x04, 0x04, 0x04, 0x0E },
  // 0x6D  'm'
  { 0x00, 0x00, 0x1A, 0x15, 0x15, 0x11, 0x11 },
  // 0x6E  'n'
  { 0x00, 0x00, 0x16, 0x19, 0x11, 0x11, 0x11 },
  // 0x6F  'o'
  { 0x00, 0x00, 0x0E, 0x11, 0x11, 0x11, 0x0E },
  // 0x70  'p'
  { 0x00, 0x00, 0x1E, 0x11, 0x1E, 0x10, 0x10 },
  // 0x71  'q'
  { 0x00, 0x00, 0x0D, 0x13, 0x0F, 0x01, 0x01 },
  // 0x72  'r'
  { 0x00, 0x00, 0x16, 0x19, 0x10, 0x10, 0x10 },
  // 0x73  's'
  { 0x00, 0x00, 0x0E, 0x10, 0x0E, 0x01, 0x1E },
  // 0x74  't'
  { 0x08, 0x08, 0x1C, 0x08, 0x08, 0x09, 0x06 },
  // 0x75  'u'
  { 0x00, 0x00, 0x11, 0x11, 0x11, 0x13, 0x0D },
  // 0x76  'v'
  { 0x00, 0x00, 0x11, 0x11, 0x11, 0x0A, 0x04 },
  // 0x77  'w'
  { 0x00, 0x00, 0x11, 0x11, 0x15, 0x15, 0x0A },
  // 0x78  'x'
  { 0x00, 0x00, 0x11, 0x0A, 0x04, 0x0A, 0x11 },
  // 0x79  'y'
  { 0x00, 0x00, 0x11, 0x11, 0x0F, 0x01, 0x0E },
  // 0x7A  'z'
  { 0x00, 0x00, 0x1F, 0x02, 0x04, 0x08, 0x1F },
  // 0x7B  '{'
  { 0x02, 0x04, 0x04, 0x08, 0x04, 0x04, 0x02 },
  // 0x7C  '|'
  { 0x04, 0x04, 0x04, 0x04, 0x04, 0x04, 0x04 },
  // 0x7D  '}'
  { 0x08, 0x04, 0x04, 0x02, 0x04, 0x04, 0x08 },
  // 0x7E  '~'
  { 0x00, 0x00, 0x08, 0x15, 0x02, 0x00, 0x00 },
};


// Padding inside the semi-transparent background (in logical pixels)
#define R2D_FONT_PADDING_H  8
#define R2D_FONT_PADDING_V  10


// Bitmap Text API /////////////////////////////////////////////////////////////


/*
 * Allocate a new bitmap text handle. All fields are zeroed so the first call
 * to R2D_UpdateBitmapText will create the texture.
 */
R2D_BitmapText *R2D_CreateBitmapText(void) {
  R2D_BitmapText *bt = (R2D_BitmapText *)calloc(1, sizeof(R2D_BitmapText));
  return bt;
}


/*
 * Free a bitmap text handle and its cached resources.
 */
void R2D_FreeBitmapText(R2D_BitmapText *bt) {
  if (!bt) return;
  if (bt->texture) SDL_DestroyTexture(bt->texture);
  free(bt->text);
  free(bt);
}


// Drop the cached texture and rendered string so the next draw rebuilds them.
// Used for full re-inits (ext_create reuse, teardown) — content changes go
// through R2D_UpdateBitmapText, which keeps the texture and uploads in place.
static void R2D_InvalidateBitmapText(R2D_BitmapText *bt) {
  if (bt->texture) {
    SDL_DestroyTexture(bt->texture);
    bt->texture = NULL;
  }
  bt->tex_w = 0;
  bt->tex_h = 0;
  bt->content_w = 0;
  bt->content_h = 0;
  free(bt->text);
  bt->text = NULL;
}


/*
 * Render a string to a cached texture. If the string is identical to the
 * previously rendered one, this is a no-op (cache hit). Otherwise the old
 * texture is destroyed and a new one is built at physical-pixel resolution
 * for HiDPI crispness.
 *
 * Parameters:
 *   bt        Bitmap text handle (from R2D_CreateBitmapText)
 *   renderer  The SDL renderer to create the texture on
 *   text      The string to render (printable ASCII only)
 *   scale     Logical pixel multiplier per glyph pixel (e.g. 3)
 */
void R2D_UpdateBitmapText(R2D_BitmapText *bt, SDL_Renderer *renderer,
                          const char *text, int scale) {
  if (!bt || !text) return;

  // Cache hit — string and scale unchanged
  if (bt->text && strcmp(text, bt->text) == 0 && bt->scale == scale) return;

  // Drop only the cache key; the texture persists as a grow-only allocation
  // and the new string is uploaded into it below.
  free(bt->text);
  bt->text = NULL;

  // Each byte renders one glyph cell — a real glyph for printable ASCII, or a
  // placeholder for anything out of range (non-ASCII, control chars). Counting
  // bytes (not just printable ones) keeps the width consistent with ext_create
  // and makes unsupported characters visible instead of silently vanishing.
  int len = (int)strlen(text);
  if (len == 0) {
    // Nothing to render: cache the empty key and zero the content dims so the
    // draw paths skip the (still-allocated) texture with its stale pixels.
    bt->text = strdup(text);
    bt->scale = scale;
    bt->content_w = 0;
    bt->content_h = 0;
    bt->logical_w = 0.0f;
    bt->logical_h = 0.0f;
    return;
  }

  // Build surface at physical-pixel resolution for HiDPI crispness
  float ds = R2D_GetDisplayScale();
  int surface_scale = (int)(scale * ds);
  if (surface_scale < scale) surface_scale = scale;

  int glyph_w = R2D_FONT_GLYPH_WIDTH * surface_scale;
  int glyph_h = R2D_FONT_GLYPH_HEIGHT * surface_scale;
  int char_spacing = surface_scale;
  int pad_h = bt->background ? (int)(R2D_FONT_PADDING_H * ds) : 0;
  int pad_v = bt->background ? (int)(R2D_FONT_PADDING_V * ds) : 0;
  int surface_w = len * glyph_w + (len - 1) * char_spacing + pad_h;
  int surface_h = glyph_h + pad_v;

  SDL_Surface *surface = SDL_CreateSurface(surface_w, surface_h, SDL_PIXELFORMAT_RGBA32);
  if (!surface) return;

  // Semi-transparent black background, or fully transparent when disabled
  Uint8 bg_alpha = bt->background ? 180 : 0;
  SDL_FillSurfaceRect(surface, NULL,
    SDL_MapRGBA(SDL_GetPixelFormatDetails(surface->format), NULL, 0, 0, 0, bg_alpha));

  int x_offset = bt->background ? (int)(R2D_FONT_PADDING_H * 0.5f * ds) : 0;
  int y_offset = bt->background ? (int)(R2D_FONT_PADDING_V * 0.5f * ds) : 0;
  uint32_t white = SDL_MapRGBA(SDL_GetPixelFormatDetails(surface->format), NULL, 255, 255, 255, 255);

  for (const char *p = text; *p; p++) {
    unsigned char ch = (unsigned char)*p;
    // Substitute a visible placeholder for unsupported bytes (the font only
    // covers printable ASCII), so dropped characters are noticeable.
    if (ch < R2D_FONT_FIRST_CHAR || ch > R2D_FONT_LAST_CHAR) ch = '?';

    int glyph_idx = ch - R2D_FONT_FIRST_CHAR;
    const uint8_t *glyph = r2d_font_glyphs[glyph_idx];

    for (int row = 0; row < R2D_FONT_GLYPH_HEIGHT; row++) {
      for (int col = 0; col < R2D_FONT_GLYPH_WIDTH; col++) {
        if (glyph[row] & (1 << (R2D_FONT_GLYPH_WIDTH - 1 - col))) {
          SDL_Rect pixel = {
            x_offset + col * surface_scale,
            y_offset + row * surface_scale,
            surface_scale,
            surface_scale
          };
          SDL_FillSurfaceRect(surface, &pixel, white);
        }
      }
    }

    x_offset += glyph_w + char_spacing;
  }

  /* Refresh the GPU texture — platform-split exactly like text.c's ext_draw
     (see the comment there for the measurements): the web build updates a
     persistent grow-only texture in place, native recreates from the surface
     each change because Metal is faster at create-fresh. */
#ifdef __EMSCRIPTEN__
  if (bt->texture == NULL || surface_w > bt->tex_w || surface_h > bt->tex_h) {
    int new_w = surface_w > bt->tex_w ? surface_w : bt->tex_w;
    int new_h = surface_h > bt->tex_h ? surface_h : bt->tex_h;
    if (bt->texture) SDL_DestroyTexture(bt->texture);
    bt->texture = SDL_CreateTexture(renderer, SDL_PIXELFORMAT_RGBA32,
                                    SDL_TEXTUREACCESS_STREAMING, new_w, new_h);
    R2D_CheckSDL(bt->texture != NULL, "SDL_CreateTexture");
    if (bt->texture) {
      SDL_SetTextureBlendMode(bt->texture, SDL_BLENDMODE_BLEND);
      bt->applied_scale_mode = SDL_SCALEMODE_INVALID;
      bt->tex_w = new_w;
      bt->tex_h = new_h;
    } else {
      bt->tex_w = 0;
      bt->tex_h = 0;
    }
  }
  if (bt->texture) {
    SDL_Rect upload_rect = { 0, 0, surface_w, surface_h };
    R2D_CheckSDL(SDL_UpdateTexture(bt->texture, &upload_rect, surface->pixels, surface->pitch),
                 "SDL_UpdateTexture");
    bt->content_w = surface_w;
    bt->content_h = surface_h;
  }
#else
  if (bt->texture) SDL_DestroyTexture(bt->texture);
  bt->texture = SDL_CreateTextureFromSurface(renderer, surface);
  R2D_CheckSDL(bt->texture != NULL, "SDL_CreateTextureFromSurface");
  if (bt->texture) {
    bt->applied_scale_mode = SDL_SCALEMODE_INVALID;
    bt->content_w = surface_w;
    bt->content_h = surface_h;
  }
#endif
  SDL_DestroySurface(surface);

  // If texture creation failed (R2D_CheckSDL only logs), leave the cache key
  // (bt->text / bt->scale) unset so the next draw retries, rather than
  // committing a permanently blank glyph via the cache-hit short-circuit above.
  if (!bt->texture) return;

  // Compute the logical (window-coordinate) size for rendering
  int logical_glyph_w = R2D_FONT_GLYPH_WIDTH * scale;
  int logical_glyph_h = R2D_FONT_GLYPH_HEIGHT * scale;
  int logical_spacing = scale;
  int logical_pad_h = bt->background ? R2D_FONT_PADDING_H : 0;
  int logical_pad_v = bt->background ? R2D_FONT_PADDING_V : 0;
  bt->logical_w = (float)(len * logical_glyph_w + (len - 1) * logical_spacing + logical_pad_h);
  bt->logical_h = (float)(logical_glyph_h + logical_pad_v);

  bt->text = strdup(text);
  bt->scale = scale;
}


/*
 * Draw the cached bitmap text texture at the given logical coordinates.
 */
void R2D_DrawBitmapText(R2D_BitmapText *bt, SDL_Renderer *renderer,
                        float x, float y) {
  if (!bt || !bt->texture || bt->content_w <= 0) return;

#ifdef __EMSCRIPTEN__
  // Clip to the content within the (possibly larger) persistent texture;
  // native textures are content-sized, so NULL is equivalent (see text.c).
  SDL_FRect src = { 0, 0, (float)bt->content_w, (float)bt->content_h };
  const SDL_FRect *src_p = &src;
#else
  const SDL_FRect *src_p = NULL;
#endif
  SDL_FRect dst = { x, y, bt->logical_w, bt->logical_h };
  R2D_CheckSDL(SDL_RenderTexture(renderer, bt->texture, src_p, &dst),
               "SDL_RenderTexture");
}


// Ruby Bindings ///////////////////////////////////////////////////////////////

R2D_DEFINE_DATA_TYPE(R2D_BitmapText);

// BitmapText-specific ivar IDs. Shared ivar IDs live in ext.c.
static R_ID id_bt_scale, id_bt_ext;


/*
 * Initialize Ruby2D::BitmapText native bindings
 */
void R2D_BitmapText_Init() {
  id_bt_scale  = r_id("@scale");
  id_bt_ext    = r_id("@ext_bitmap_text");

  r_define_class_method(ruby2d_ext_module, "bitmap_text_create", ruby2d_ext_bitmap_text_create, r_args_variadic);
  r_define_class_method(ruby2d_ext_module, "bitmap_text_draw",   ruby2d_ext_bitmap_text_draw,   r_args_variadic);
}


/*
 * Ruby2D::BitmapText#ext_create
 *
 * Allocates (or reuses) the internal R2D_BitmapText struct and computes the
 * logical width/height from the string length and scale. No renderer is
 * needed — the texture is built lazily in ext_draw.
 */
R_VAL ruby2d_ext_bitmap_text_create(RUBY2D_METHOD_ARGS_VARIADIC) {
  RUBY2D_EXTRACT_VARIADIC;
  if (argc != 1) r_raise("Ruby2D::Ext.bitmap_text_create expects 1 arg (text), got %d", (int)argc);
  R_VAL obj = argv[0];
  R2D_Init();

  const char *msg = obj_str(obj, id_content);
  int scale       = obj_int(obj, id_bt_scale);

  // Check for existing struct — reuse it if present, otherwise allocate new
  R2D_BitmapText *bt = NULL;
  bool is_new = false;
  R_VAL existing = r_iv_get(obj, "@ext_bitmap_text");
  if (r_test(existing)) {
    obj_struct(obj, id_bt_ext, R2D_BitmapText, bt);
    if (bt) {
      R2D_InvalidateBitmapText(bt);
    }
  }

  // Allocate new struct only if we don't have one to reuse
  if (!bt) {
    bt = ALLOC(R2D_BitmapText);
    memset(bt, 0, sizeof(R2D_BitmapText));
    is_new = true;
  }

  // One glyph cell per byte (out-of-range bytes draw a placeholder at draw
  // time), matching R2D_UpdateBitmapText so the reported width agrees with
  // what's rendered.
  int len = (msg == NULL) ? 0 : (int)strlen(msg);

  // Compute logical dimensions (no background padding for user-facing text).
  // Empty content reports a zero-width box at the glyph height — the draw path
  // already no-ops on empty, so no texture is built.
  int logical_w = (len == 0) ? 0
                             : len * (R2D_FONT_GLYPH_WIDTH * scale) + (len - 1) * scale;
  int logical_h = R2D_FONT_GLYPH_HEIGHT * scale;

  // Only set the struct on the Ruby object if we allocated new
  if (is_new) {
    obj_set_struct(obj, id_bt_ext, R2D_BitmapText, bt);
  }

  obj_set_int(obj, id_width, logical_w);
  obj_set_int(obj, id_height, logical_h);

  return R_TRUE;
}


/*
 * Ruby2D::BitmapText#ext_draw
 *
 * Unwraps the struct, lazily builds/caches the texture via
 * R2D_UpdateBitmapText, applies color and alpha modulation, and draws.
 */
R_VAL ruby2d_ext_bitmap_text_draw(RUBY2D_METHOD_ARGS_VARIADIC) {
  RUBY2D_EXTRACT_VARIADIC;
  if (argc != 3) r_raise("Ruby2D::Ext.bitmap_text_draw expects 3 args (text, rx, ry), got %d", (int)argc);
  R_VAL obj = argv[0];
  float crx = NUM2DBL(argv[1]);
  float cry = NUM2DBL(argv[2]);
  R2D_BitmapText *bt;
  obj_struct(obj, id_bt_ext, R2D_BitmapText, bt);

  const char *msg = obj_str(obj, id_content);
  int scale = obj_int(obj, id_bt_scale);

  R2D_UpdateBitmapText(bt, R2D_GetRenderer(), msg, scale);

  if (!bt->texture || bt->content_w <= 0) return R_NIL;

  SDL_SetTextureBlendMode(bt->texture, SDL_BLENDMODE_BLEND);

  // The glyph grid is rasterized at the target scale, so this only applies
  // when the renderer resamples the frame.
  R2D_ApplyScaleMode(bt->texture, obj, &bt->applied_scale_mode);

  // Apply color and alpha modulation
  R_VAL color_obj = r_ivar_get(obj, id_color);
  SDL_SetTextureColorModFloat(bt->texture,
    NUM2DBL(r_ivar_get(color_obj, id_r)),
    NUM2DBL(r_ivar_get(color_obj, id_g)),
    NUM2DBL(r_ivar_get(color_obj, id_b))
  );
  SDL_SetTextureAlphaModFloat(bt->texture,
    NUM2DBL(r_ivar_get(color_obj, id_a)));

  // Rotate about (rx, ry), expressed relative to the texture's top-left — the
  // same convention as Text (see text.c). Reuses the cached texture; only the
  // blit is rotated.
  float x = obj_float(obj, id_x);
  float y = obj_float(obj, id_y);
#ifdef __EMSCRIPTEN__
  // Clip to the content within the (possibly larger) persistent texture;
  // native textures are content-sized, so NULL is equivalent (see text.c).
  SDL_FRect src = { 0, 0, (float)bt->content_w, (float)bt->content_h };
  const SDL_FRect *src_p = &src;
#else
  const SDL_FRect *src_p = NULL;
#endif
  SDL_FRect dst = { x, y, bt->logical_w, bt->logical_h };
  SDL_FPoint center = { crx - x, cry - y };

  R2D_CheckSDL(SDL_RenderTextureRotated(
    R2D_GetRenderer(),
    bt->texture,
    src_p,
    &dst,
    obj_float(obj, id_rotate),
    &center,
    SDL_FLIP_NONE
  ), "SDL_RenderTextureRotated");

  return R_TRUE;
}


/*
 * Free the memory and resources associated with an R2D_BitmapText object
 */
static void R2D_BitmapText_free(void *p) {
  if (!p) return;
  R2D_BitmapText *bt = (R2D_BitmapText *)p;
  if (bt->texture) {
    if (R2D_RendererAlive()) SDL_DestroyTexture(bt->texture);
    bt->texture = NULL;
  }
  free(bt->text);
  xfree(bt);
}
