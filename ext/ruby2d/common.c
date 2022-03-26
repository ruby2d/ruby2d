// Ruby 2D Shared functions and data

#include "ruby2d.h"

// Initalize shared data
bool R2D_diagnostics = false;

// Initialization status
static bool initted = false;


/*
 * Provide a `vasprintf()` implementation for Windows
 */
#if WINDOWS && !MINGW
int vasprintf(char **strp, const char *fmt, va_list ap) {
  int r = -1, size = _vscprintf(fmt, ap);
  if ((size >= 0) && (size < INT_MAX)) {
    *strp = (char *)malloc(size + 1);
    if (*strp) {
      r = vsnprintf(*strp, size + 1, fmt, ap);
      if (r == -1) free(*strp);
    }
  } else { *strp = 0; }
  return(r);
}
#endif


/*
 * Checks if a file exists and can be accessed
 */
bool R2D_FileExists(const char *path) {
  if (!path) return false;

  if (access(path, F_OK) != -1) {
    return true;
  } else {
    return false;
  }
}


/*
 * Logs standard messages to the console
 */
void R2D_Log(int type, const char *msg, ...) {

  // Always log if diagnostics set, or if a warning or error message
  if (R2D_diagnostics || type != R2D_INFO) {

    va_list args;
    va_start(args, msg);

    switch (type) {
      case R2D_INFO:
        #if WASM  // don't print terminal colors, browser doesn't support it
          printf("Info: ");
        #else
          printf("\033[1;36mInfo:\033[0m ");
        #endif
        break;
      case R2D_WARN:
        #if WASM
          printf("Warning: ");
        #else
          printf("\033[1;33mWarning:\033[0m ");
        #endif
        break;
      case R2D_ERROR:
        #if WASM
          printf("Error: ");
        #else
          printf("\033[1;31mError:\033[0m ");
        #endif
        break;
    }

    vprintf(msg, args);
    printf("\n");
    va_end(args);
  }
}


/*
 * Logs Ruby 2D errors to the console, with caller and message body
 */
void R2D_Error(const char *caller, const char *msg, ...) {
  va_list args;
  va_start(args, msg);
  char *fmsg;
  vasprintf(&fmsg, msg, args);
  R2D_Log(R2D_ERROR, "(%s) %s", caller, fmsg);
  free(fmsg);
  va_end(args);
}


/*
 * Enable/disable logging of diagnostics
 */
void R2D_Diagnostics(bool status) {
  R2D_diagnostics = status;
}


/*
 * Enable terminal colors in Windows
 */
void R2D_Windows_EnableTerminalColors() {
  #if WINDOWS
    HANDLE hOut = GetStdHandle(STD_OUTPUT_HANDLE);
    DWORD dwMode = 0;
    GetConsoleMode(hOut, &dwMode);
    dwMode |= ENABLE_VIRTUAL_TERMINAL_PROCESSING;
    SetConsoleMode(hOut, dwMode);
  #endif
}


/*
 * Initialize Ruby 2D subsystems
 */
bool R2D_Init() {
  if (initted) return true;

  // Enable terminal colors in Windows
  R2D_Windows_EnableTerminalColors();

  R2D_Log(R2D_INFO, "Initializing Ruby 2D");

  // Initialize SDL
  if (SDL_Init(SDL_INIT_EVERYTHING) != 0) {
    R2D_Error("SDL_Init", SDL_GetError());
    return false;
  }

  // Initialize SDL_ttf
  if (TTF_Init() != 0) {
    R2D_Error("TTF_Init", TTF_GetError());
    return false;
  }

  // Initialize SDL_mixer
  int mix_flags = MIX_INIT_FLAC | MIX_INIT_OGG | MIX_INIT_MP3;
  int mix_initted = Mix_Init(mix_flags);

  // Bug in SDL2_mixer 2.0.2:
  //   Mix_Init should return OR'ed flags if successful, but returns 0 instead.
  //   Fixed in: https://hg.libsdl.org/SDL_mixer/rev/7fa15b556953
  const SDL_version *linked_version = Mix_Linked_Version();
  if (linked_version->major == 2 && linked_version->minor == 0 && linked_version->patch == 2) {
    // It's version 2.0.2, don't check for Mix_Init errors
  } else {
    if ((mix_initted&mix_flags) != mix_flags) {
      R2D_Error("Mix_Init", Mix_GetError());
    }
  }

  if (Mix_OpenAudio(44100, MIX_DEFAULT_FORMAT, 2, 4096) != 0) {
    R2D_Error("Mix_OpenAudio", Mix_GetError());
    return false;
  }

  // Call `R2D_Quit` at program exit
  atexit(R2D_Quit);

  // All subsystems initted
  initted = true;
  return true;
}


/*
 * Gets the primary display's dimensions
 */
void R2D_GetDisplayDimensions(int *w, int *h) {
  R2D_Init();
  SDL_DisplayMode dm;
  SDL_GetCurrentDisplayMode(0, &dm);
  *w = dm.w;
  *h = dm.h;
}


/*
 * Quits Ruby 2D subsystems
 */
void R2D_Quit() {
  IMG_Quit();
  Mix_CloseAudio();
  Mix_Quit();
  TTF_Quit();
  SDL_Quit();
  initted = false;
}
