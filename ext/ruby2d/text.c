// text.c

#include "ruby2d.h"

R2D_DEFINE_DATA_TYPE(R2D_Text);

// Text-specific ivar IDs. Shared ivar IDs live in ext.c.
static R_ID id_font, id_size, id_style_flags;


/*
 * Initialize
 */
void R2D_Text_Init() {
  id_font        = r_id("@font");
  id_size        = r_id("@size");
  id_style_flags = r_id("@style_flags");

  r_define_class_method(ruby2d_ext_module, "text_create", ruby2d_ext_text_create, r_args_variadic);
  r_define_class_method(ruby2d_ext_module, "text_draw",   ruby2d_ext_text_draw,   r_args_variadic);
}


// Font Cache //////////////////////////////////////////////////////////////////
//
// Shares TTF_Font handles across R2D_Text objects with the same font path and
// size. Each entry is reference-counted; the font is only closed when the last
// reference is released AND the slot is needed for a new font.

#define R2D_FONT_CACHE_MAX 128

struct R2D_FontCacheEntry {
  char *path;
  int size;
  int style;        // TTF_FontStyleFlags (bold/italic/…) — part of the cache key
  TTF_Font *font;
  int ref_count;
  bool standalone;  // true => not in the cache array; freed when ref_count hits 0
};

static R2D_FontCacheEntry font_cache[R2D_FONT_CACHE_MAX];
static int font_cache_count = 0;


/*
 * Look up or open a font, returning a cache entry with ref_count incremented.
 * Returns NULL on failure (SDL error is set).
 */
static R2D_FontCacheEntry *R2D_FontCacheGet(const char *path, int size, int style) {
  // Search for existing entry
  for (int i = 0; i < font_cache_count; i++) {
    if (font_cache[i].size == size && font_cache[i].style == style &&
        strcmp(font_cache[i].path, path) == 0) {
      font_cache[i].ref_count++;
      return &font_cache[i];
    }
  }

  // Not found — open a new font and apply its style. Style is part of the
  // cache key, so each (path, size, style) owns its own TTF_Font and
  // TTF_SetFontStyle never mutates a handle shared by differently-styled text.
  TTF_Font *font = TTF_OpenFont(path, size);
  if (!font) return NULL;
  TTF_SetFontStyle(font, style);

  // Find a slot: append if room, otherwise evict an unreferenced entry
  R2D_FontCacheEntry *slot = NULL;
  if (font_cache_count < R2D_FONT_CACHE_MAX) {
    slot = &font_cache[font_cache_count++];
  } else {
    for (int i = 0; i < font_cache_count; i++) {
      if (font_cache[i].ref_count == 0) {
        TTF_CloseFont(font_cache[i].font);
        free(font_cache[i].path);
        slot = &font_cache[i];
        break;
      }
    }
  }

  if (!slot) {
    // Cache is full and every entry is referenced by a live Text. The font is
    // valid — fall back to a standalone, single-owner entry rather than
    // hard-failing a legitimate font. It isn't shared (no array slot to find
    // it), so its sole owner frees it via R2D_FontCacheRelease.
    R2D_FontCacheEntry *standalone = malloc(sizeof(R2D_FontCacheEntry));
    if (!standalone) {
      TTF_CloseFont(font);
      return NULL;
    }
    standalone->path = strdup(path);
    standalone->size = size;
    standalone->style = style;
    standalone->font = font;
    standalone->ref_count = 1;
    standalone->standalone = true;
    return standalone;
  }

  slot->path = strdup(path);
  slot->size = size;
  slot->style = style;
  slot->font = font;
  slot->ref_count = 1;
  slot->standalone = false;
  return slot;
}


/*
 * Release a reference to a cached font. The entry stays in the cache (with
 * ref_count 0) so it can be reused without reopening the file.
 */
static void R2D_FontCacheRelease(R2D_FontCacheEntry *entry) {
  if (!entry) return;
  if (entry->ref_count > 0) entry->ref_count--;

  // Standalone (degraded) entries aren't in the cache array, so nothing can
  // reuse them — close and free once the last reference is gone.
  if (entry->standalone && entry->ref_count == 0) {
    TTF_CloseFont(entry->font);
    free(entry->path);
    free(entry);
  }
}


// Text Surface Cache //////////////////////////////////////////////////////////
//
// Shares rendered SDL_Surface* handles across R2D_Text objects with the same
// (font entry, string) pair, avoiding duplicate TTF_RenderText_Blended calls
// for identical labels. Each slot is reference-counted and also holds a
// reference on its font entry so the font cache cannot evict a font while any
// cached surface is keyed against it.

#define R2D_TEXT_SURFACE_CACHE_MAX 256

typedef struct {
  R2D_FontCacheEntry *entry;
  char *text;
  size_t text_len;  // byte length of `text`; keys compared by length + memcmp
  SDL_Surface *surface;
  int ref_count;
  uint64_t last_used;
} R2D_TextSurfaceCacheEntry;

static R2D_TextSurfaceCacheEntry text_surface_cache[R2D_TEXT_SURFACE_CACHE_MAX];
static int text_surface_cache_count = 0;
static uint64_t text_surface_cache_tick = 0;


/*
 * Duplicate a byte buffer of exactly `len` bytes, NUL-terminating the copy.
 * Unlike strdup, this preserves embedded NULs so length-keyed text (which may
 * contain them) round-trips intact. Returns NULL on allocation failure.
 */
static char *R2D_TextDup(const char *text, size_t len) {
  char *copy = malloc(len + 1);
  if (!copy) return NULL;
  memcpy(copy, text, len);
  copy[len] = '\0';
  return copy;
}


/*
 * Split `len` bytes of content into the body SDL_ttf lays out (its length goes
 * to *body_len) and the number of trailing newlines, which is returned. The
 * wrapped renderer mislays trailing newlines: one widened the last line by a
 * glyph advance instead of adding a line, and two added only one line. So
 * the body is rasterized without them and each is added back as a blank line
 * of padding (see R2D_TextSurfaceCacheGet), giving the layout USAGE.md
 * documents: width is the widest line, height covers every line.
 */
static int R2D_TextTrailingNewlines(const char *msg, size_t len, size_t *body_len) {
  size_t body = len;
  int count = 0;
  while (body > 0 && msg[body - 1] == '\n') {
    body--;
    count++;
    // A CRLF terminator comes off whole: a '\r' left at the end of the body
    // would lay out as an inkless advance, the width this fix removes. A bare
    // '\r' anywhere else is left to SDL_ttf, which draws it that way.
    if (body > 0 && msg[body - 1] == '\r') body--;
  }
  *body_len = body;
  return count;
}


/*
 * Height in pixels of a block of `lines` laid-out lines of a plain glyph in
 * `font`, measured by SDL_ttf, for blank content. No metric reproduces it:
 * the first line's box isn't `TTF_GetFontHeight` for every font (Hiragino
 * lays out 30 where the metric says 20), and the second line adds more than
 * `TTF_GetFontLineSkip` for some (a pixel on the SF fonts, a whole line on
 * Apple Myungjo); from the third line on every font steps by the line skip.
 * Returns -1 if the measurement fails (SDL_ttf reports the glyph as zero
 * width at the smallest sizes of some fonts).
 */
static int R2D_TextLinesHeight(TTF_Font *font, int lines) {
  char stack_probe[64];
  size_t len = (size_t)lines * 2 - 1;  // "A\nA\n…A"
  char *probe = len < sizeof(stack_probe) ? stack_probe : malloc(len + 1);
  if (!probe) return -1;
  for (size_t i = 0; i < len; i++) probe[i] = (i % 2 == 0) ? 'A' : '\n';
  probe[len] = '\0';
  int w = 0, h = -1;
  if (!TTF_GetStringSizeWrapped(font, probe, len, 0, &w, &h)) h = -1;
  if (probe != stack_probe) free(probe);
  return h;
}


/*
 * Height of `body_len` bytes of content laid out with `trailing` blank lines
 * after it, as SDL_ttf would report it if blank lines could be measured
 * directly: the body is measured with the blank lines and one more line
 * holding a plain glyph, and that line's own contribution — a line skip,
 * which is what every font adds from its third line on — is taken back. The
 * blank lines are then the layout's own, including where a tall body line's
 * overhang is absorbed into the line below rather than added to it. Exact
 * whenever the probe glyph's ink sits inside the body's line box, which is
 * every font but a few symbol fonts at small sizes (Webdings, whose 'A' is
 * an ornament, overshoots by a pixel or two). Called only when a body is
 * rasterized with trailing newlines, so an ordinary text pays nothing.
 * Returns -1 if the measurement fails.
 */
static int R2D_TextBlockHeight(TTF_Font *font, const char *body, size_t body_len, int trailing) {
  size_t len = body_len + (size_t)trailing + 2;  // body, newlines, "\nA"
  char *probe = malloc(len + 1);
  if (!probe) return -1;
  memcpy(probe, body, body_len);
  memset(probe + body_len, '\n', (size_t)trailing + 1);
  probe[len - 1] = 'A';
  probe[len] = '\0';
  int w = 0, h = -1;
  bool ok = TTF_GetStringSizeWrapped(font, probe, len, 0, &w, &h);
  free(probe);
  if (!ok) return -1;
  return h - TTF_GetFontLineSkip(font);
}


/*
 * Number of lines in `len` bytes of body content: one plus its newlines.
 */
static int R2D_TextLineCount(const char *msg, size_t len) {
  int lines = 1;
  for (size_t i = 0; i < len; i++) {
    if (msg[i] == '\n') lines++;
  }
  return lines;
}


/*
 * Look up or rasterize a surface for (entry, msg) of msg_len bytes. The key is
 * length-aware so embedded NULs and prefix-equal strings stay distinct. The
 * body must be non-empty once trailing newlines are set aside; the caller
 * handles all-blank content itself (see R2D_TextRasterize).
 *
 * On success, returns a surface and sets *cached_out:
 *   - true  => surface is shared and ref-counted in the cache; caller must
 *              release via R2D_TextSurfaceCacheRelease(entry, msg, msg_len).
 *   - false => cache was full with all entries live; caller owns the surface
 *              and must SDL_DestroySurface it directly.
 *
 * Returns NULL on rasterization failure (SDL error is set).
 */
static SDL_Surface *R2D_TextSurfaceCacheGet(
  R2D_FontCacheEntry *entry, const char *msg, size_t msg_len, bool *cached_out) {

  // Fast path: existing cached surface. The key is compared by byte length and
  // memcmp (not strcmp) so content with embedded NULs — and prefix-equal strings
  // of different lengths — are distinguished correctly.
  for (int i = 0; i < text_surface_cache_count; i++) {
    R2D_TextSurfaceCacheEntry *e = &text_surface_cache[i];
    if (e->entry == entry && e->text_len == msg_len &&
        memcmp(e->text, msg, msg_len) == 0) {
      e->ref_count++;
      e->last_used = ++text_surface_cache_tick;
      *cached_out = true;
      return e->surface;
    }
  }

  // Pick a slot before rasterizing so we can fall back to degraded mode cleanly.
  // For an LRU-evicted slot, defer freeing the victim's contents until the new
  // surface rasterizes successfully — destroying it up front would leave the
  // still-live slot pointing at freed memory if the rasterize fails (a UAF on
  // the next lookup's memcmp, then a double-free on the next eviction).
  R2D_TextSurfaceCacheEntry *slot = NULL;
  bool is_new_slot = false;
  if (text_surface_cache_count < R2D_TEXT_SURFACE_CACHE_MAX) {
    slot = &text_surface_cache[text_surface_cache_count];
    is_new_slot = true;
  } else {
    uint64_t lowest_tick = UINT64_MAX;
    for (int i = 0; i < text_surface_cache_count; i++) {
      R2D_TextSurfaceCacheEntry *e = &text_surface_cache[i];
      if (e->ref_count == 0 && e->last_used < lowest_tick) {
        lowest_tick = e->last_used;
        slot = e;
      }
    }
  }

  SDL_Color color = { 255, 255, 255, 255 };
  // Wrapped renderer with wrap width 0 lays out embedded "\n" as hard line
  // breaks (the non-wrapped TTF_RenderText_Blended renders newlines as a
  // single garbled line). Wrap width 0 means "only break on explicit \n".
  // Pass the explicit byte length (not 0 = NUL-terminated) so content with an
  // embedded NUL renders in full rather than truncating at the first NUL.
  // Trailing newlines are left out of the rasterization and added back below.
  size_t body_len;
  int trailing = R2D_TextTrailingNewlines(msg, msg_len, &body_len);
  SDL_Surface *surface = TTF_RenderText_Blended_Wrapped(entry->font, msg, body_len, color, 0);
  if (!surface) return NULL;

  if (trailing > 0) {
    // Append the blank lines as transparent rows, up to the height SDL_ttf
    // lays this body out at with that many blank lines (measured, since no
    // metric reproduces it — see R2D_TextBlockHeight). The body is copied
    // verbatim (blend mode none), not composited over the padding.
    int block_h = R2D_TextBlockHeight(entry->font, msg, body_len, trailing);
    int pad;
    if (block_h < 0) {
      // Only an allocation failure gets here (the body just rendered, so its
      // probe measures): a line skip per blank line is what the layout adds
      // past its second line, so the estimate is exact but for that step.
      pad = trailing * TTF_GetFontLineSkip(entry->font);
    } else {
      pad = block_h > surface->h ? block_h - surface->h : 0;
    }
    SDL_Surface *padded = SDL_CreateSurface(surface->w, surface->h + pad, surface->format);
    if (!padded ||
        !SDL_FillSurfaceRect(padded, NULL, 0) ||
        !SDL_SetSurfaceBlendMode(surface, SDL_BLENDMODE_NONE) ||
        !SDL_BlitSurface(surface, NULL, padded, NULL)) {
      if (padded) SDL_DestroySurface(padded);
      SDL_DestroySurface(surface);
      return NULL;
    }
    SDL_DestroySurface(surface);
    surface = padded;
  }

#ifdef __EMSCRIPTEN__
  // Normalize to RGBA32: the web build's persistent text texture is created
  // RGBA32 (WebGL-native, like Canvas) and takes raw SDL_UpdateTexture
  // uploads, so the surface must match byte-for-byte. TTF renders ARGB8888;
  // converting once here costs far less than the rasterize itself, and cache
  // hits skip both. Web-only: native keeps the ARGB surface because Metal
  // prefers it — an RGBA32 surface forced a convert-back inside every
  // CreateTextureFromSurface, measurably slowing the dynamic-text bench.
  if (surface->format != SDL_PIXELFORMAT_RGBA32) {
    SDL_Surface *converted = SDL_ConvertSurface(surface, SDL_PIXELFORMAT_RGBA32);
    SDL_DestroySurface(surface);
    if (!converted) return NULL;
    surface = converted;
  }
#endif

  if (!slot) {
    // Degraded: every cached entry is live. Rasterize ad-hoc, don't insert.
    *cached_out = false;
    return surface;
  }

  // Rasterize succeeded — now it's safe to evict the LRU victim's contents
  // (reused slots only; a freshly appended slot has nothing to free).
  if (!is_new_slot) {
    SDL_DestroySurface(slot->surface);
    free(slot->text);
    R2D_FontCacheRelease(slot->entry);
  }

  // Hold our own ref on the font entry for the lifetime of this cache slot.
  entry->ref_count++;

  slot->entry = entry;
  slot->text = R2D_TextDup(msg, msg_len);
  slot->text_len = msg_len;
  slot->surface = surface;
  slot->ref_count = 1;
  slot->last_used = ++text_surface_cache_tick;
  if (is_new_slot) text_surface_cache_count++;

  *cached_out = true;
  return surface;
}


/*
 * Release one R2D_Text's reference on a cached surface. The entry stays in
 * the cache (with ref_count 0) so a future lookup can reuse it without
 * re-rasterizing; eviction happens lazily on the next cache miss.
 */
static void R2D_TextSurfaceCacheRelease(
  R2D_FontCacheEntry *entry, const char *text, size_t text_len) {
  for (int i = 0; i < text_surface_cache_count; i++) {
    R2D_TextSurfaceCacheEntry *e = &text_surface_cache[i];
    if (e->entry == entry && e->text_len == text_len &&
        memcmp(e->text, text, text_len) == 0) {
      if (e->ref_count > 0) e->ref_count--;
      return;
    }
  }
}


/*
 * Release the surface/font references a Text currently holds, leaving the
 * fields NULL. A no-op on a freshly allocated struct (all fields NULL).
 * Shared by R2D_TextRasterize (before installing new resources) and
 * R2D_Text_free (final teardown). The GPU texture is deliberately NOT
 * released here: it persists across re-rasterizes as a grow-only allocation
 * (text_draw uploads the new surface into it), and is destroyed only in
 * R2D_Text_free.
 */
static void R2D_TextReleaseResources(R2D_Text *txt) {
  if (txt->cached_text) {
    R2D_TextSurfaceCacheRelease(txt->font_entry, txt->cached_text, txt->cached_text_len);
    free(txt->cached_text);
    txt->cached_text = NULL;
    txt->cached_text_len = 0;
    txt->surface = NULL;  // owned by cache — don't destroy
  } else if (txt->surface) {
    SDL_DestroySurface(txt->surface);
    txt->surface = NULL;
  }
  R2D_FontCacheRelease(txt->font_entry);
  txt->font_entry = NULL;
}


/*
 * (Re)rasterize a Text's surface at the current asset scale and update its
 * logical width/height, marking the persistent texture stale so text_draw
 * re-uploads it.
 *
 * All fallible work (open font, render surface, copy the cache key) is done
 * into local temporaries first; only once every step succeeds are the old
 * resources released and the new ones installed. On any failure the existing
 * txt->surface/font_entry/cached_text are left untouched (so a previously valid
 * Text keeps drawing) and false is returned (SDL error is set).
 *
 * Called from text_create (initial build) and from text_draw when the asset
 * scale has changed since the surface was built — e.g. a Text constructed
 * before the window opened, when R2D_GetAssetScale() was still 1.0.
 */
static bool R2D_TextRasterize(R_VAL obj, R2D_Text *txt) {
  const char *font = obj_str(obj, id_font);
  const char *msg  = obj_str(obj, id_content);
  size_t msg_len   = obj_str_len(obj, id_content);
  int size         = obj_int(obj, id_size);
  int style        = obj_int(obj, id_style_flags);

  float scale = R2D_GetAssetScale();
  int effective_size = (int)(size * scale);

  // --- Build the new resources into locals (nothing on txt is touched yet) ---
  R2D_FontCacheEntry *new_entry = R2D_FontCacheGet(font, effective_size, style);
  if (!new_entry) return false;

  // Rasterize unless the content is blank — empty, or nothing but newlines.
  // A body SDL_ttf refuses (only zero-advance characters, or a font that
  // measures zero width at this size) fails the same way with a trailing
  // newline as without one; it used to render as a blank box behind the
  // newline's phantom advance, and blanking real content silently is worse
  // than the error the same content raises without the newline.
  size_t body_len;
  int trailing = R2D_TextTrailingNewlines(msg, msg_len, &body_len);
  bool cached = false;
  SDL_Surface *new_surface = NULL;
  if (body_len > 0) {
    new_surface = R2D_TextSurfaceCacheGet(new_entry, msg, msg_len, &cached);
    if (!new_surface) {
      R2D_FontCacheRelease(new_entry);
      return false;
    }
  }

  // Blank content: report a zero-width box as tall as a block of one line per
  // newline plus one (measured the way a rendered block is, see
  // R2D_TextLinesHeight), with no surface or texture. The draw paths key off
  // txt->empty to treat this as "nothing to draw" rather than a failure.
  // Width and height are derived from the new font, so it's safe to set them
  // once the (only fallible) font open above has succeeded.
  if (!new_surface) {
    int lines = R2D_TextLineCount(msg, body_len) + trailing;
    int lines_px = R2D_TextLinesHeight(new_entry->font, lines);
    if (lines_px < 0) {
      lines_px = TTF_GetFontHeight(new_entry->font) +
                 (lines - 1) * TTF_GetFontLineSkip(new_entry->font);
    }
    int new_height = (int)((float)lines_px / scale);

    R2D_TextReleaseResources(txt);
#ifndef __EMSCRIPTEN__
    // Native: drop the texture here, during the update phase, exactly like
    // the pre-persistent-texture code — destroying at draw time instead
    // (mid-render, per text) breaks the renderer's command batching and
    // measurably slowed the dynamic-text bench.
    if (txt->texture) {
      if (R2D_RendererAlive()) SDL_DestroyTexture(txt->texture);
      txt->texture = NULL;
    }
#endif
    txt->font_entry = new_entry;
    txt->surface = NULL;
    txt->cached_text = NULL;
    txt->cached_text_len = 0;
    txt->empty = true;
    txt->rendered_scale = scale;
    obj_set_int(obj, id_width, 0);
    obj_set_int(obj, id_height, new_height);
    return true;
  }

  char *new_cached_text = NULL;
  if (cached) {
    // Ownership of a cache-shared surface is tracked solely via cached_text. If
    // the copy fails (OOM), keeping the surface would later SDL_DestroySurface a
    // cache-owned handle (double-free), so release our refs and fail instead.
    new_cached_text = R2D_TextDup(msg, msg_len);
    if (!new_cached_text) {
      R2D_TextSurfaceCacheRelease(new_entry, msg, msg_len);
      R2D_FontCacheRelease(new_entry);
      return false;
    }
  }

  // --- All fallible steps succeeded: release the old, install the new --------
  R2D_TextReleaseResources(txt);
#ifndef __EMSCRIPTEN__
  // Native: destroy during the update phase, not at draw time — see the
  // matching block in the empty-content path above.
  if (txt->texture) {
    if (R2D_RendererAlive()) SDL_DestroyTexture(txt->texture);
    txt->texture = NULL;
  }
#endif
  txt->font_entry = new_entry;
  txt->surface = new_surface;
  txt->cached_text = new_cached_text;
  txt->cached_text_len = new_cached_text ? msg_len : 0;
  txt->texture_stale = true;  // text_draw uploads the new surface
  txt->empty = false;
  txt->rendered_scale = scale;

  /* The surface dimensions are in renderer pixels. To present sizes in
     window/logical coordinates (so R2D_WindowToRendererCoordinatesRect()
     scales them correctly on HiDPI displays), divide by the asset scale. */
  int logical_w = (int) ((float)new_surface->w / scale);
  int logical_h = (int) ((float)new_surface->h / scale);
  obj_set_int(obj, id_width, logical_w);
  obj_set_int(obj, id_height, logical_h);

  return true;
}


/*
 * Ruby2D::Text#ext_create
 */
R_VAL ruby2d_ext_text_create(RUBY2D_METHOD_ARGS_VARIADIC) {
  RUBY2D_EXTRACT_VARIADIC;
  if (argc != 1) r_raise("Ruby2D::Ext.text_create expects 1 arg (text), got %d", (int)argc);
  R_VAL obj = argv[0];
  // Ensure SDL subsystems are initialized (display_scale is set in R2D_Init)
  if (!R2D_Init()) r_raise("Ruby2D: failed to initialize: %s", SDL_GetError());

  // The font path's existence is validated Ruby-side in `normalize_font_path`
  // before any `text_create` (construction and `font=` both route through it),
  // so re-stating it here on every content=/size= reassignment would be a
  // per-frame syscall for nothing (~one stat per Text per frame under a dynamic
  // HUD). A font deleted at runtime between `font=` and a later create still
  // fails cleanly below via `TTF_OpenFont` (the `font` name feeds that error).
  const char *font = obj_str(obj, id_font);

  // Reuse the existing struct if present (e.g. a content=/size= reassignment),
  // otherwise allocate and initialize a fresh one. R2D_TextRasterize releases
  // any old resources before building the new surface.
  R2D_Text *txt = NULL;
  bool is_new = false;
  R_VAL existing = r_iv_get(obj, "@ext_text");
  if (r_test(existing)) {
    obj_struct(obj, id_ext_text, R2D_Text, txt);
  }
  if (!txt) {
    txt = ALLOC(R2D_Text);
    memset(txt, 0, sizeof(R2D_Text));
    is_new = true;
  }

  if (!R2D_TextRasterize(obj, txt)) {
    if (is_new) xfree(txt);
    r_error("Failed to render text (font `%s`): %s", font, SDL_GetError());
    return R_NIL;
  }

  // Only set the struct on the Ruby object if we allocated new
  if (is_new) {
    obj_set_struct(obj, id_ext_text, R2D_Text, txt);
  }

  return R_TRUE;
}


/*
 * Ruby2D::Text#ext_draw
 */
R_VAL ruby2d_ext_text_draw(RUBY2D_METHOD_ARGS_VARIADIC) {
  RUBY2D_EXTRACT_VARIADIC;
  if (argc != 3) r_raise("Ruby2D::Ext.text_draw expects 3 args (text, rx, ry), got %d", (int)argc);
  R_VAL obj = argv[0];
  float crx = NUM2DBL(argv[1]);
  float cry = NUM2DBL(argv[2]);
  R2D_Text *txt;
  obj_struct(obj, id_ext_text, R2D_Text, txt);

  // Re-rasterize if the asset scale changed since the surface was built — e.g.
  // the Text was created before the window opened (scale 1.0) and the window
  // then opened on a HiDPI display without pixel_scale (scale = display_scale).
  if (txt->rendered_scale != R2D_GetAssetScale()) {
    if (!R2D_TextRasterize(obj, txt)) {
      r_error("Failed to render text: %s", SDL_GetError());
      return R_NIL;
    }
  }

  if (txt->empty) return R_NIL;  // empty content: nothing to draw

  /* Refresh the GPU texture from the (re)rasterized surface. The strategy is
     platform-split, and both arms were measured on the dynamic-text bench —
     intuition points the wrong way on each side:

     - Web (WebGL): a persistent grow-only texture updated in place. Fresh
       glTexImage2D texture objects every frame churn the browser GPU
       pipeline; switching to SDL_UpdateTexture cut the wasm render slice by
       ~60% (and SwiftShader understates the real-browser win).
     - Native: destroy + SDL_CreateTextureFromSurface per change. Metal is
       far faster at create-fresh than at updating a live texture — the
       persistent path measured +75% frame cost (~18µs per SDL_UpdateTexture
       across 360 texts/frame). */
  if (txt->texture == NULL || txt->texture_stale) {
    SDL_Surface *s = txt->surface;
#ifdef __EMSCRIPTEN__
    if (txt->texture == NULL || s->w > txt->tex_w || s->h > txt->tex_h) {
      int new_w = s->w > txt->tex_w ? s->w : txt->tex_w;
      int new_h = s->h > txt->tex_h ? s->h : txt->tex_h;
      if (txt->texture) SDL_DestroyTexture(txt->texture);
      txt->texture = SDL_CreateTexture(R2D_GetRenderer(), SDL_PIXELFORMAT_RGBA32,
                                       SDL_TEXTUREACCESS_STREAMING, new_w, new_h);
      if (!txt->texture) {
        txt->tex_w = 0;
        txt->tex_h = 0;
        r_raise("SDL_CreateTexture failed: %s", SDL_GetError());
        return R_NIL;
      }
      SDL_SetTextureBlendMode(txt->texture, SDL_BLENDMODE_BLEND);
      txt->applied_scale_mode = SDL_SCALEMODE_INVALID;
      txt->tex_w = new_w;
      txt->tex_h = new_h;
    }
    SDL_Rect upload_rect = { 0, 0, s->w, s->h };
    R2D_CheckSDL(SDL_UpdateTexture(txt->texture, &upload_rect, s->pixels, s->pitch),
                 "SDL_UpdateTexture");
#else
    // Rasterize already destroyed the old texture (update phase), so this is
    // always a fresh create — the exact pre-persistent-texture flow.
    if (txt->texture == NULL) {
      txt->texture = SDL_CreateTextureFromSurface(R2D_GetRenderer(), s);
      if (!txt->texture) {
        r_raise("SDL_CreateTextureFromSurface failed: %s", SDL_GetError());
        return R_NIL;
      }
      SDL_SetTextureBlendMode(txt->texture, SDL_BLENDMODE_BLEND);
      txt->applied_scale_mode = SDL_SCALEMODE_INVALID;
    }
#endif
    txt->texture_stale = false;
    // Keep surface alive for canvas blitting; R2D_Text_free handles cleanup
  }

  R2D_ApplyScaleMode(txt->texture, obj, &txt->applied_scale_mode);

#ifdef __EMSCRIPTEN__
  // The persistent texture's capacity can exceed the content — clip to it.
  // Native textures are always content-sized, so NULL (whole texture) is
  // equivalent and keeps that path identical to what was benchmarked.
  SDL_FRect src_rect = { 0, 0, (float)txt->surface->w, (float)txt->surface->h };
  const SDL_FRect *src = &src_rect;
#else
  const SDL_FRect *src = NULL;
#endif
  SDL_FRect dst_rect = {
    obj_float(obj, id_x),
    obj_float(obj, id_y),
    obj_float(obj, id_width),
    obj_float(obj, id_height)
  };

  R_VAL color_obj = r_ivar_get(obj, id_color);
  SDL_SetTextureColorModFloat(txt->texture,
    NUM2DBL(r_ivar_get(color_obj, id_r)),
    NUM2DBL(r_ivar_get(color_obj, id_g)),
    NUM2DBL(r_ivar_get(color_obj, id_b))
  );
  SDL_SetTextureAlphaModFloat(txt->texture, NUM2DBL(r_ivar_get(color_obj, id_a)));

  SDL_FPoint center = {
    crx - obj_float(obj, id_x),
    cry - obj_float(obj, id_y)
  };

  R2D_CheckSDL(SDL_RenderTextureRotated(
    R2D_GetRenderer(),
    txt->texture,
    src,
    &dst_rect,
    obj_float(obj, id_rotate),
    &center,
    SDL_FLIP_NONE
  ), "SDL_RenderTextureRotated");

  return R_TRUE;
}


/*
 * Free the memory and resources associated with an R2D_Text object
 */
static void R2D_Text_free(void *p) {
  if (!p) return;
  R2D_Text *txt = (R2D_Text *)p;
  R2D_TextReleaseResources(txt);
  if (txt->texture) {
    if (R2D_RendererAlive()) SDL_DestroyTexture(txt->texture);
    txt->texture = NULL;
  }
  xfree(txt);
}
