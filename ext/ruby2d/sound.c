// sound.c

#include "ruby2d.h"


/*
 * Create a sound, given an audio file path
 */
R2D_Sound *R2D_CreateSound(const char *path) {
  R2D_Init();

  // Check if sound file exists
  if (!R2D_FileExists(path)) {
    R2D_Error("R2D_CreateSound", "Sound file `%s` not found", path);
    return NULL;
  }

  // Allocate the sound structure
  R2D_Sound *snd = (R2D_Sound *) malloc(sizeof(R2D_Sound));
  if (!snd) {
    R2D_Error("R2D_CreateSound", "Out of memory!");
    return NULL;
  }

  // Load the sound data from file
  snd->data = Mix_LoadWAV(path);
  if (!snd->data) {
    R2D_Error("Mix_LoadWAV", Mix_GetError());
    free(snd);
    return NULL;
  }

  // Initialize values
  snd->path = path;

  return snd;
}


/*
 * Play the sound
 */
void R2D_PlaySound(R2D_Sound *snd, bool loop) {
  if (!snd) return;

  // If looping, set to -1 times; else 0
  int times = loop ? -1 : 0;

  // times: 0 == once, -1 == forever
  Mix_PlayChannel(-1, snd->data, times);
}


/*
 * Get the sound's length in seconds
 */
int R2D_GetSoundLength(R2D_Sound *snd) {
  float points = 0;
  float frames = 0;
  int frequency = 0;
  Uint16 format = 0;
  int channels = 0;

  // Populate the frequency, format and channel variables
  if (!Mix_QuerySpec(&frequency, &format, &channels)) return -1; // Querying audio details failed
  if (!snd) return -1;

  // points = bytes / samplesize
  points = (snd->data->alen / ((format & 0xFF) / 8));

  // frames = sample points / channels
  frames = (points / channels);

  // frames / frequency is seconds of audio
  return ceil(frames / frequency);
}


/*
 * Get the sound's volume
 */
int R2D_GetSoundVolume(R2D_Sound *snd) {
  if (!snd) return -1;
  return ceil(Mix_VolumeChunk(snd->data, -1) * (100.0 / MIX_MAX_VOLUME));
}


/*
 * Set the sound's volume a given percentage
 */
void R2D_SetSoundVolume(R2D_Sound *snd, int volume) {
  if (!snd) return;
  // Set volume to be a percentage of the maximum mix volume
  Mix_VolumeChunk(snd->data, (volume / 100.0) * MIX_MAX_VOLUME);
}


/*
 * Get the sound mixer volume
 */
int R2D_GetSoundMixVolume() {
  return ceil(Mix_Volume(-1, -1) * (100.0 / MIX_MAX_VOLUME));
}


/*
 * Set the sound mixer volume a given percentage
 */
void R2D_SetSoundMixVolume(int volume) {
  // This sets the volume value across all channels
  // Set volume to be a percentage of the maximum mix volume
  Mix_Volume(-1, (volume / 100.0) * MIX_MAX_VOLUME);
}


/*
 * Free the sound
 */
void R2D_FreeSound(R2D_Sound *snd) {
  if (!snd) return;
  Mix_FreeChunk(snd->data);
  free(snd);
}
