// text.c

#include "ruby2d.h"

#ifndef RUBY2D_NO_RUBY
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
#endif


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
 * Look up or rasterize a surface for (entry, msg) of msg_len bytes. The key is
 * length-aware so embedded NULs and prefix-equal strings stay distinct.
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
  SDL_Surface *surface = TTF_RenderText_Blended_Wrapped(entry->font, msg, msg_len, color, 0);
  if (!surface) return NULL;

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
/*
 * Rasterize `msg` with `font` at `size` and `style` into `txt`, replacing what
 * was there. Ruby-free: the Ruby bridge reads these off the Text's ivars and
 * copies the resulting `width`/`height` back; the Spinel build passes them in
 * and reads the size through R2D_TextWidth / R2D_TextHeight. Returns false on
 * failure with the SDL error set, leaving `txt` as it was.
 */
static bool R2D_TextRasterizeWith(R2D_Text *txt, const char *font,
                                  const char *msg, size_t msg_len,
                                  int size, int style) {
  float scale = R2D_GetAssetScale();
  int effective_size = (int)(size * scale);

  // --- Build the new resources into locals (nothing on txt is touched yet) ---
  R2D_FontCacheEntry *new_entry = R2D_FontCacheGet(font, effective_size, style);
  if (!new_entry) return false;

  // Empty content: report a zero-width box at the font's natural line height and
  // skip rasterization entirely (no surface or texture). The draw paths key off
  // txt->empty to treat this as "nothing to draw" rather than a failure. Width
  // and height are derived from the new font, so it's safe to set them once the
  // (only fallible) font open above has succeeded.
  if (msg_len == 0) {
    int new_height = (int)((float)TTF_GetFontHeight(new_entry->font) / scale);

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
    txt->width = 0;
    txt->height = new_height;
    return true;
  }

  bool cached = false;
  SDL_Surface *new_surface = R2D_TextSurfaceCacheGet(new_entry, msg, msg_len, &cached);
  if (!new_surface) {
    R2D_FontCacheRelease(new_entry);
    return false;
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
  txt->width  = (int) ((float)new_surface->w / scale);
  txt->height = (int) ((float)new_surface->h / scale);

  return true;
}


/*
 * Upload the rasterized surface to the GPU if it changed, then draw it at
 * (x, y) at the text's own size, rotated about (crx, cry), tinted by the color.
 * Ruby-free core behind Ext.text_draw. Returns false on a texture failure with
 * the SDL error set. Does not re-rasterize on an asset-scale change — callers
 * check R2D_TextStale first, since only they hold the font and content.
 */
static bool R2D_TextDrawWith(R2D_Text *txt, float x, float y, float rotate,
                             float crx, float cry,
                             float r, float g, float b, float a,
                             SDL_ScaleMode scale_mode) {
  if (txt->empty) return true;  // empty content: nothing to draw

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
        return false;
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
      if (!txt->texture) return false;
      SDL_SetTextureBlendMode(txt->texture, SDL_BLENDMODE_BLEND);
      txt->applied_scale_mode = SDL_SCALEMODE_INVALID;
    }
#endif
    txt->texture_stale = false;
    // Keep surface alive for canvas blitting; R2D_Text_free handles cleanup
  }

  if (scale_mode != txt->applied_scale_mode) {
    SDL_SetTextureScaleMode(txt->texture, scale_mode);
    txt->applied_scale_mode = scale_mode;
  }

#ifdef __EMSCRIPTEN__
  // The persistent texture's capacity can exceed the content — clip to it.
  // Native textures are always content-sized, so NULL (whole texture) is
  // equivalent and keeps that path identical to what was benchmarked.
  SDL_FRect src_rect = { 0, 0, (float)txt->surface->w, (float)txt->surface->h };
  const SDL_FRect *src = &src_rect;
#else
  const SDL_FRect *src = NULL;
#endif
  SDL_FRect dst_rect = { x, y, (float)txt->width, (float)txt->height };

  SDL_SetTextureColorModFloat(txt->texture, r, g, b);
  SDL_SetTextureAlphaModFloat(txt->texture, a);

  SDL_FPoint center = { crx - x, cry - y };

  R2D_CheckSDL(SDL_RenderTextureRotated(
    R2D_GetRenderer(), txt->texture, src, &dst_rect, rotate, &center, SDL_FLIP_NONE
  ), "SDL_RenderTextureRotated");

  return true;
}


/*
 * Release everything a text holds, then the text itself
 */
static void R2D_TextDestroy(R2D_Text *txt) {
  if (!txt) return;
  R2D_TextReleaseResources(txt);
  if (txt->texture) {
    if (R2D_RendererAlive()) SDL_DestroyTexture(txt->texture);
    txt->texture = NULL;
  }
  free(txt);
}


// Ruby-free text API //////////////////////////////////////////////////////////
//
// What the Spinel build calls over FFI, since it cannot hand a Ruby object to
// C: a text is an opaque handle, its font and content arrive as arguments, and
// its measured size is read back. The Ruby bindings below share every core
// these call.

void *R2D_TextNew(void) {
  if (!R2D_Init()) return NULL;
  R2D_Text *txt = (R2D_Text *)calloc(1, sizeof(R2D_Text));
  return txt;
}

bool R2D_TextUpdate(void *text, const char *font, const char *content,
                    int size, int style) {
  if (!text || !font || !content) return false;
  return R2D_TextRasterizeWith((R2D_Text *)text, font, content, strlen(content),
                               size, style);
}

int R2D_TextWidth(void *text)  { return text ? ((R2D_Text *)text)->width  : 0; }
int R2D_TextHeight(void *text) { return text ? ((R2D_Text *)text)->height : 0; }

// True when the asset scale moved since the last rasterization — e.g. the
// text was built before a HiDPI window opened — and the caller should update
// before drawing, as the Ruby bridge does on its own.
bool R2D_TextStale(void *text) {
  return text && ((R2D_Text *)text)->rendered_scale != R2D_GetAssetScale();
}

bool R2D_TextDraw(void *text, float x, float y, float rotate,
                  float crx, float cry,
                  float r, float g, float b, float a,
                  const char *scale_mode) {
  if (!text) return false;
  R2D_Window *window = R2D_GetWindow();
  SDL_ScaleMode fallback = window ? window->scale_mode : SDL_SCALEMODE_LINEAR;
  return R2D_TextDrawWith((R2D_Text *)text, x, y, rotate, crx, cry, r, g, b, a,
                          R2D_ParseScaleModeName(scale_mode, fallback));
}

void R2D_TextFree(void *text) {
  R2D_TextDestroy((R2D_Text *)text);
}


#ifndef RUBY2D_NO_RUBY
/*
 * Rasterize from the Text's ivars and write the measured size back onto it
 */
static bool R2D_TextRasterize(R_VAL obj, R2D_Text *txt) {
  if (!R2D_TextRasterizeWith(txt,
                             obj_str(obj, id_font),
                             obj_str(obj, id_content), obj_str_len(obj, id_content),
                             obj_int(obj, id_size), obj_int(obj, id_style_flags))) {
    return false;
  }
  obj_set_int(obj, id_width, txt->width);
  obj_set_int(obj, id_height, txt->height);
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

  SDL_ScaleMode mode = R2D_ResolveScaleMode(obj);
  R_VAL color_obj = r_ivar_get(obj, id_color);
  if (!R2D_TextDrawWith(txt,
                        obj_float(obj, id_x), obj_float(obj, id_y),
                        obj_float(obj, id_rotate), crx, cry,
                        NUM2DBL(r_ivar_get(color_obj, id_r)),
                        NUM2DBL(r_ivar_get(color_obj, id_g)),
                        NUM2DBL(r_ivar_get(color_obj, id_b)),
                        NUM2DBL(r_ivar_get(color_obj, id_a)),
                        mode)) {
    r_raise("Failed to draw text: %s", SDL_GetError());
    return R_NIL;
  }

  return R_TRUE;
}


/*
 * Free the memory and resources associated with an R2D_Text object
 */
static void R2D_Text_free(void *p) {
  R2D_TextDestroy((R2D_Text *)p);
}
#endif
