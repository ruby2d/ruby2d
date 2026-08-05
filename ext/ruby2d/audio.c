// audio.c
//
// SDL_mixer wrappers + Ruby2D::Ext bindings for audio. The Audio Ruby class
// (lib/ruby2d/audio.rb) holds an opaque @ext_audio handle returned by
// Ext.audio_load and passes it back to the other Ext.audio_* methods.

#include "ruby2d.h"

R2D_DEFINE_DATA_TYPE(R2D_Audio);

// Mixer device — created once in R2D_Init, used by audio bindings.
static MIX_Mixer *r2d_mixer = NULL;

void R2D_SetMixer(MIX_Mixer *mixer) { r2d_mixer = mixer; }
MIX_Mixer *R2D_GetMixer(void)       { return r2d_mixer; }


/*
 * Lazily initialize SDL_mixer and open the default playback device. Separated
 * from R2D_Init so a machine with no/blocked audio device can still open a
 * graphics window — only actual audio use triggers (and can fail) here.
 * Idempotent: returns true immediately once a mixer exists.
 */
bool R2D_InitAudio() {
  if (r2d_mixer) return true;

  // Ensure SDL's subsystems (incl. the audio subsystem) are up first.
  if (!R2D_Init()) return false;

  // Initialize SDL_mixer (SDL3 style: returns true on success)
  if (!MIX_Init()) {
    R2D_Error("MIX_Init", "%s", SDL_GetError());
    return false;
  }

  // Open the default playback device (SDL3)
  MIX_Mixer *mixer = MIX_CreateMixerDevice(SDL_AUDIO_DEVICE_DEFAULT_PLAYBACK, NULL);
  if (!mixer) {
    R2D_Error("MIX_CreateMixerDevice", "%s", SDL_GetError());
    return false;
  }
  r2d_mixer = mixer;
  return true;
}


// Clamp a gain value to the SDL-accepted [0.0, 1.0] range.
static inline float clamp01(float v) {
  if (v < 0.0f) return 0.0f;
  if (v > 1.0f) return 1.0f;
  return v;
}


/*
 * Ruby2D::Ext.audio_load(path) → opaque handle (or raises on failure)
 */
R_VAL ruby2d_ext_audio_load(RUBY2D_METHOD_ARGS_VARIADIC) {
  RUBY2D_EXTRACT_VARIADIC;
  if (argc != 1) r_raise("Ruby2D::Ext.audio_load expects 1 arg (path), got %d", (int)argc);

  // Open the mixer device lazily if an Audio object is the first thing created.
  // R2D_InitAudio is idempotent; it fails only when no playback device exists.
  if (!R2D_InitAudio()) r_error("Failed to initialize audio: %s", SDL_GetError());

  const char *path = RSTRING_PTR(argv[0]);

  if (!R2D_FileExists(path)) {
    r_error("Audio file `%s` not found", path);
    return R_NIL;
  }

  R2D_Audio *aud = ALLOC(R2D_Audio);

  // On failure, raise rather than returning nil: the Audio object would
  // otherwise store a nil handle and segfault on the first play/pause/etc.
  // when the binding unwraps it.
  MIX_Audio *mix_audio = MIX_LoadAudio(r2d_mixer, path, false);
  if (!mix_audio) {
    xfree(aud);
    r_error("Failed to load audio `%s`: %s", path, SDL_GetError());
    return R_NIL;
  }

  MIX_Track *mix_track = MIX_CreateTrack(r2d_mixer);
  if (!mix_track) {
    MIX_DestroyAudio(mix_audio);
    xfree(aud);
    r_error("Failed to load audio `%s`: %s", path, SDL_GetError());
    return R_NIL;
  }

  aud->mix_audio = mix_audio;
  aud->mix_track = mix_track;

  return r_wrap_struct(R2D_Audio, aud);
}


/*
 * Ruby2D::Ext.audio_play(handle, loop)
 */
R_VAL ruby2d_ext_audio_play(RUBY2D_METHOD_ARGS_VARIADIC) {
  RUBY2D_EXTRACT_VARIADIC;
  if (argc != 2) r_raise("Ruby2D::Ext.audio_play expects 2 args, got %d", (int)argc);

  R2D_Audio *aud = r_unwrap_struct(argv[0], R2D_Audio);

  // Assign input to this track before playing (required in SDL3_mixer)
  if (!MIX_SetTrackAudio(aud->mix_track, aud->mix_audio)) {
    R2D_Error("MIX_SetTrackAudio", "%s", SDL_GetError());
  }

  // The loop count must be passed as a play option: MIX_PlayTrack's second arg
  // is an SDL_PropertiesID, not a loop count, and MIX_SetTrackLoops has no
  // effect on a stopped track. -1 loops forever, 0 plays once. A failed
  // property set degrades to play-once (props == 0 → default loops).
  SDL_PropertiesID props = SDL_CreateProperties();
  if (props) {
    SDL_SetNumberProperty(props, MIX_PROP_PLAY_LOOPS_NUMBER, r_test(argv[1]) ? -1 : 0);
  }
  if (!MIX_PlayTrack(aud->mix_track, props)) {
    R2D_Error("MIX_PlayTrack", "%s", SDL_GetError());
  }
  SDL_DestroyProperties(props);

  return R_TRUE;
}


/*
 * Ruby2D::Ext.audio_pause(handle)
 */
R_VAL ruby2d_ext_audio_pause(RUBY2D_METHOD_ARGS_VARIADIC) {
  RUBY2D_EXTRACT_VARIADIC;
  if (argc != 1) r_raise("Ruby2D::Ext.audio_pause expects 1 arg, got %d", (int)argc);

  R2D_Audio *aud = r_unwrap_struct(argv[0], R2D_Audio);

  if (!MIX_PauseTrack(aud->mix_track)) {
    R2D_Error("MIX_PauseTrack", "%s", SDL_GetError());
  }

  return R_TRUE;
}


/*
 * Ruby2D::Ext.audio_resume(handle)
 */
R_VAL ruby2d_ext_audio_resume(RUBY2D_METHOD_ARGS_VARIADIC) {
  RUBY2D_EXTRACT_VARIADIC;
  if (argc != 1) r_raise("Ruby2D::Ext.audio_resume expects 1 arg, got %d", (int)argc);

  R2D_Audio *aud = r_unwrap_struct(argv[0], R2D_Audio);

  if (!MIX_ResumeTrack(aud->mix_track)) {
    R2D_Error("MIX_ResumeTrack", "%s", SDL_GetError());
  }

  return R_TRUE;
}


/*
 * Ruby2D::Ext.audio_stop(handle, ms_fade)
 */
R_VAL ruby2d_ext_audio_stop(RUBY2D_METHOD_ARGS_VARIADIC) {
  RUBY2D_EXTRACT_VARIADIC;
  if (argc != 2) r_raise("Ruby2D::Ext.audio_stop expects 2 args, got %d", (int)argc);

  R2D_Audio *aud = r_unwrap_struct(argv[0], R2D_Audio);

  int fade_ms = NUM2INT(argv[1]);
  if (fade_ms < 0) fade_ms = 0;

  if (!MIX_StopTrack(aud->mix_track, MIX_TrackMSToFrames(aud->mix_track, fade_ms))) {
    R2D_Error("MIX_StopTrack", "%s", SDL_GetError());
  }

  return R_TRUE;
}


/*
 * Ruby2D::Ext.audio_set_loop(handle, loop)
 */
R_VAL ruby2d_ext_audio_set_loop(RUBY2D_METHOD_ARGS_VARIADIC) {
  RUBY2D_EXTRACT_VARIADIC;
  if (argc != 2) r_raise("Ruby2D::Ext.audio_set_loop expects 2 args, got %d", (int)argc);

  R2D_Audio *aud = r_unwrap_struct(argv[0], R2D_Audio);
  MIX_SetTrackLoops(aud->mix_track, r_test(argv[1]) ? -1 : 0);

  return argv[1];
}


/*
 * Ruby2D::Ext.audio_length(handle) → duration in seconds, 0 if unknown/infinite
 */
R_VAL ruby2d_ext_audio_length(RUBY2D_METHOD_ARGS_VARIADIC) {
  RUBY2D_EXTRACT_VARIADIC;
  if (argc != 1) r_raise("Ruby2D::Ext.audio_length expects 1 arg, got %d", (int)argc);

  R2D_Audio *aud = r_unwrap_struct(argv[0], R2D_Audio);

  Sint64 frames = MIX_GetAudioDuration(aud->mix_audio);
  if (frames == MIX_DURATION_UNKNOWN || frames == MIX_DURATION_INFINITE) {
    return INT2NUM(0);
  }

  Sint64 ms = MIX_AudioFramesToMS(aud->mix_audio, frames);
  // Round to nearest second instead of truncating
  int seconds = (int)((ms + 500) / 1000);

  return INT2NUM(seconds);
}


/*
 * Ruby2D::Ext.audio_get_volume(handle) → 0.0..1.0
 */
R_VAL ruby2d_ext_audio_get_volume(RUBY2D_METHOD_ARGS_VARIADIC) {
  RUBY2D_EXTRACT_VARIADIC;
  if (argc != 1) r_raise("Ruby2D::Ext.audio_get_volume expects 1 arg, got %d", (int)argc);

  R2D_Audio *aud = r_unwrap_struct(argv[0], R2D_Audio);

  float gain = clamp01(MIX_GetTrackGain(aud->mix_track));  // SDL gain, 0.0 .. 1.0

  return DBL2NUM(gain);
}


/*
 * Ruby2D::Ext.audio_set_volume(handle, volume) — volume 0.0..1.0
 */
R_VAL ruby2d_ext_audio_set_volume(RUBY2D_METHOD_ARGS_VARIADIC) {
  RUBY2D_EXTRACT_VARIADIC;
  if (argc != 2) r_raise("Ruby2D::Ext.audio_set_volume expects 2 args, got %d", (int)argc);

  R2D_Audio *aud = r_unwrap_struct(argv[0], R2D_Audio);

  float gain = clamp01((float) NUM2DBL(argv[1]));

  if (!MIX_SetTrackGain(aud->mix_track, gain)) {
    R2D_Error("MIX_SetTrackGain", "%s", SDL_GetError());
  }

  return R_NIL;
}


/*
 * Ruby2D::Ext.audio_get_mixer_volume → 0.0..1.0
 */
R_VAL ruby2d_ext_audio_get_mixer_volume(RUBY2D_METHOD_ARGS_VARIADIC) {
  RUBY2D_EXTRACT_VARIADIC;
  (void)argc; (void)argv;

  // Open the mixer device lazily. R2D_InitAudio is idempotent.
  if (!R2D_InitAudio()) r_error("Failed to initialize audio: %s", SDL_GetError());

  float gain = clamp01(MIX_GetMixerGain(r2d_mixer));

  return DBL2NUM(gain);
}


/*
 * Ruby2D::Ext.audio_set_mixer_volume(volume) — volume 0.0..1.0
 */
R_VAL ruby2d_ext_audio_set_mixer_volume(RUBY2D_METHOD_ARGS_VARIADIC) {
  RUBY2D_EXTRACT_VARIADIC;
  if (argc != 1) r_raise("Ruby2D::Ext.audio_set_mixer_volume expects 1 arg, got %d", (int)argc);

  // Open the mixer device lazily. R2D_InitAudio is idempotent.
  if (!R2D_InitAudio()) r_error("Failed to initialize audio: %s", SDL_GetError());

  float gain = clamp01((float) NUM2DBL(argv[0]));

  if (!MIX_SetMixerGain(r2d_mixer, gain)) {
    R2D_Error("MIX_SetMixerGain", "%s", SDL_GetError());
  }

  return R_NIL;
}


/*
 * Initialize — register Ext audio bindings.
 */
void R2D_Audio_Init() {
  r_define_class_method(ruby2d_ext_module, "audio_load",             ruby2d_ext_audio_load,             r_args_variadic);
  r_define_class_method(ruby2d_ext_module, "audio_play",             ruby2d_ext_audio_play,             r_args_variadic);
  r_define_class_method(ruby2d_ext_module, "audio_pause",            ruby2d_ext_audio_pause,            r_args_variadic);
  r_define_class_method(ruby2d_ext_module, "audio_resume",           ruby2d_ext_audio_resume,           r_args_variadic);
  r_define_class_method(ruby2d_ext_module, "audio_stop",             ruby2d_ext_audio_stop,             r_args_variadic);
  r_define_class_method(ruby2d_ext_module, "audio_set_loop",         ruby2d_ext_audio_set_loop,         r_args_variadic);
  r_define_class_method(ruby2d_ext_module, "audio_length",           ruby2d_ext_audio_length,           r_args_variadic);
  r_define_class_method(ruby2d_ext_module, "audio_get_volume",       ruby2d_ext_audio_get_volume,       r_args_variadic);
  r_define_class_method(ruby2d_ext_module, "audio_set_volume",       ruby2d_ext_audio_set_volume,       r_args_variadic);
  r_define_class_method(ruby2d_ext_module, "audio_get_mixer_volume", ruby2d_ext_audio_get_mixer_volume, r_args_variadic);
  r_define_class_method(ruby2d_ext_module, "audio_set_mixer_volume", ruby2d_ext_audio_set_mixer_volume, r_args_variadic);
}


/*
 * Free the audio
 */
static void R2D_Audio_free(void *p) {
  if (!p) return;
  R2D_Audio *aud = (R2D_Audio *)p;
  if (aud->mix_track) {
    MIX_DestroyTrack(aud->mix_track);
    aud->mix_track = NULL;
  }
  if (aud->mix_audio) {
    MIX_DestroyAudio(aud->mix_audio);
    aud->mix_audio = NULL;
  }
  xfree(aud);
}
