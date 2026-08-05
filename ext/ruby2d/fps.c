// fps.c

#include "ruby2d.h"


/*
 * Calculates and returns the average frames per second (FPS) over the last
 * FPS_SAMPLE_COUNT frames. Uses a circular buffer to store frame times and
 * computes the rolling average FPS based on the elapsed time between frames.
 */
#define FPS_SAMPLE_COUNT 60
static double frame_times[FPS_SAMPLE_COUNT];
static double running_total = 0.0;  // running sum of the entries in frame_times
static int frame_index = 0;
static int frame_count = 0;
static SDL_Time last_time;
static bool fps_initialized = false;

double R2D_GetFrameRate() {
  SDL_Time current_time;
  double avg_fps = 0.0;

  if (!SDL_GetCurrentTime(&current_time)) {
    return 0.0;
  }

  if (!fps_initialized) {
    // First call only seeds the timer — no delta yet, so we return 0.0
    last_time = current_time;
    fps_initialized = true;
  } else {
    // SDL_GetCurrentTime returns nanoseconds; convert to seconds
    double delta = (current_time - last_time) / 1e9;

    // Maintain a running sum instead of re-summing the whole window each frame:
    // swap the sample being overwritten out for the new one. frame_times is
    // zero-initialized, so the subtracted term is 0 until the window fills.
    running_total += delta - frame_times[frame_index];
    frame_times[frame_index] = delta;
    frame_index = (frame_index + 1) % FPS_SAMPLE_COUNT;
    if (frame_count < FPS_SAMPLE_COUNT) frame_count++;

    // Once per full window (on wrap), resync the sum from the buffer to shed any
    // floating-point drift the incremental add/subtract accumulates, so the
    // average stays exactly what a full re-sum would give. O(1) amortized.
    if (frame_index == 0) {
      running_total = 0.0;
      for (int i = 0; i < frame_count; i++) running_total += frame_times[i];
    }

    if (running_total > 0.0) avg_fps = frame_count / running_total;

    last_time = current_time;
  }

  return avg_fps;
}


#define FPS_LOGICAL_SCALE  3
#define FPS_MARGIN         5  // Offset from the top-left corner of the window

static R2D_BitmapText *fps_text = NULL;


/*
 * Draws the frame rate in the window using the internal bitmap font.
 * Controlled at runtime by R2D_GetInit*.diagnostics or R2D_GetInit*.show_fps.
 * The overlay texture is cached and only rebuilt when the displayed value changes.
 */
void R2D_DrawFrameRate(R2D_Window *window) {
  char fps_str[16];
  snprintf(fps_str, sizeof(fps_str), "%.0f", window->fps);

  if (!fps_text) {
    fps_text = R2D_CreateBitmapText();
    fps_text->background = true;
  }
  R2D_UpdateBitmapText(fps_text, window->sdl_renderer, fps_str, FPS_LOGICAL_SCALE);
  R2D_DrawBitmapText(fps_text, window->sdl_renderer, (float)FPS_MARGIN, (float)FPS_MARGIN);
}


/*
 * Free the cached FPS overlay resources. Called during window cleanup.
 */
void R2D_FreeFpsOverlay(void) {
  if (fps_text) {
    R2D_FreeBitmapText(fps_text);
    fps_text = NULL;
  }
}
