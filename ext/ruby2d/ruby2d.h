// ruby2d.h

#ifndef RUBY2D_H
#define RUBY2D_H

#ifdef __cplusplus
extern "C" {
#endif

#include <stdbool.h>

// Set Platform Constants //////////////////////////////////////////////////////

// Apple
#ifdef __APPLE__
  #ifndef __TARGETCONDITIONALS__
  #include "TargetConditionals.h"
  #endif
  #if TARGET_OS_OSX
    #define MACOS true
  #elif TARGET_OS_IOS
    #define IOS   true
  #elif TARGET_OS_TV
    #define TVOS  true
  #endif
#endif

// Windows
#ifdef _WIN32
  #define WINDOWS true
#endif

// Windows and MinGW
#ifdef __MINGW32__
  #define MINGW true
#endif



// #define GLES true

// ARM and GLES
#if defined(__arm__) || IOS || TVOS || __EMSCRIPTEN__
  #define GLES true
#else
  #define GLES false
#endif



// Includes ////////////////////////////////////////////////////////////////////

// Define to get GNU extension functions and types, like `vasprintf()` and M_PI
#ifndef _GNU_SOURCE
#define _GNU_SOURCE 1
#endif

#if WINDOWS && !MINGW
  #include <io.h>
  #define  F_OK 0  // For testing file existence
#else
  #include <unistd.h>
#endif

#if WINDOWS
  #include <stdio.h>
  #include <math.h>
  #include <windows.h>
  // For terminal colors
  #ifndef  ENABLE_VIRTUAL_TERMINAL_PROCESSING
  #define  ENABLE_VIRTUAL_TERMINAL_PROCESSING 0x0004
  #endif
#endif

// SDL
#if IOS || TVOS
  #include "SDL2/SDL.h"
#else
  #include <SDL2/SDL.h>
#endif

// If MinGW, undefine `main()` from SDL_main.c
#if MINGW
  #undef main
#endif

#ifdef __EMSCRIPTEN__
  #include <stdlib.h>
  #include <stdio.h>
  #include <string.h>
  #include <math.h>
  #include <emscripten.h>
  #include <SDL.h>
  #define GL_GLEXT_PROTOTYPES 1
  #include <SDL_opengles2.h>
#endif

// OpenGL
#if GLES
  #if IOS || TVOS
    #include "SDL2/SDL_opengles2.h"
  #else
    #include <SDL2/SDL_opengles2.h>
  #endif
#else
  #define GL_GLEXT_PROTOTYPES 1
  #if WINDOWS
    #include <glew.h>
  #endif
  #include <SDL2/SDL_opengl.h>
#endif

// SDL libraries
#if IOS || TVOS
  #include "SDL2/SDL_image.h"
  #include "SDL2/SDL_mixer.h"
  #include "SDL2/SDL_ttf.h"
#else
  #include <SDL2/SDL_image.h>
  #include <SDL2/SDL_mixer.h>
  #include <SDL2/SDL_ttf.h>
#endif

// Ruby 2D Definitions /////////////////////////////////////////////////////////

// Messages
#define R2D_INFO  1
#define R2D_WARN  2
#define R2D_ERROR 3

// Window attributes
#define R2D_RESIZABLE  SDL_WINDOW_RESIZABLE
#define R2D_BORDERLESS SDL_WINDOW_BORDERLESS
#define R2D_FULLSCREEN SDL_WINDOW_FULLSCREEN_DESKTOP
#define R2D_HIGHDPI    SDL_WINDOW_ALLOW_HIGHDPI
#define R2D_DISPLAY_WIDTH  0
#define R2D_DISPLAY_HEIGHT 0

// Viewport scaling modes
#define R2D_FIXED   1
#define R2D_EXPAND  2
#define R2D_SCALE   3
#define R2D_STRETCH 4

// Positions
#define R2D_CENTER       1
#define R2D_TOP_LEFT     2
#define R2D_TOP_RIGHT    3
#define R2D_BOTTOM_LEFT  4
#define R2D_BOTTOM_RIGHT 5

// Keyboard events
#define R2D_KEY_DOWN 1  // key is pressed
#define R2D_KEY_HELD 2  // key is held down
#define R2D_KEY_UP   3  // key is released

// Mouse events
#define R2D_MOUSE_DOWN   1  // mouse button pressed
#define R2D_MOUSE_UP     2  // mouse button released
#define R2D_MOUSE_SCROLL 3  // mouse scrolling or wheel movement
#define R2D_MOUSE_MOVE   4  // mouse movement
#define R2D_MOUSE_LEFT   SDL_BUTTON_LEFT
#define R2D_MOUSE_MIDDLE SDL_BUTTON_MIDDLE
#define R2D_MOUSE_RIGHT  SDL_BUTTON_RIGHT
#define R2D_MOUSE_X1     SDL_BUTTON_X1
#define R2D_MOUSE_X2     SDL_BUTTON_X2
#define R2D_MOUSE_SCROLL_NORMAL   SDL_MOUSEWHEEL_NORMAL
#define R2D_MOUSE_SCROLL_INVERTED SDL_MOUSEWHEEL_FLIPPED

// Controller events
#define R2D_AXIS        1
#define R2D_BUTTON_DOWN 2
#define R2D_BUTTON_UP   3

// Controller axis labels
#define R2D_AXIS_INVALID      SDL_CONTROLLER_AXIS_INVALID
#define R2D_AXIS_LEFTX        SDL_CONTROLLER_AXIS_LEFTX
#define R2D_AXIS_LEFTY        SDL_CONTROLLER_AXIS_LEFTY
#define R2D_AXIS_RIGHTX       SDL_CONTROLLER_AXIS_RIGHTX
#define R2D_AXIS_RIGHTY       SDL_CONTROLLER_AXIS_RIGHTY
#define R2D_AXIS_TRIGGERLEFT  SDL_CONTROLLER_AXIS_TRIGGERLEFT
#define R2D_AXIS_TRIGGERRIGHT SDL_CONTROLLER_AXIS_TRIGGERRIGHT
#define R2D_AXIS_MAX          SDL_CONTROLLER_AXIS_MAX

// Controller button labels
#define R2D_BUTTON_INVALID       SDL_CONTROLLER_BUTTON_INVALID
#define R2D_BUTTON_A             SDL_CONTROLLER_BUTTON_A
#define R2D_BUTTON_B             SDL_CONTROLLER_BUTTON_B
#define R2D_BUTTON_X             SDL_CONTROLLER_BUTTON_X
#define R2D_BUTTON_Y             SDL_CONTROLLER_BUTTON_Y
#define R2D_BUTTON_BACK          SDL_CONTROLLER_BUTTON_BACK
#define R2D_BUTTON_GUIDE         SDL_CONTROLLER_BUTTON_GUIDE
#define R2D_BUTTON_START         SDL_CONTROLLER_BUTTON_START
#define R2D_BUTTON_LEFTSTICK     SDL_CONTROLLER_BUTTON_LEFTSTICK
#define R2D_BUTTON_RIGHTSTICK    SDL_CONTROLLER_BUTTON_RIGHTSTICK
#define R2D_BUTTON_LEFTSHOULDER  SDL_CONTROLLER_BUTTON_LEFTSHOULDER
#define R2D_BUTTON_RIGHTSHOULDER SDL_CONTROLLER_BUTTON_RIGHTSHOULDER
#define R2D_BUTTON_DPAD_UP       SDL_CONTROLLER_BUTTON_DPAD_UP
#define R2D_BUTTON_DPAD_DOWN     SDL_CONTROLLER_BUTTON_DPAD_DOWN
#define R2D_BUTTON_DPAD_LEFT     SDL_CONTROLLER_BUTTON_DPAD_LEFT
#define R2D_BUTTON_DPAD_RIGHT    SDL_CONTROLLER_BUTTON_DPAD_RIGHT
#define R2D_BUTTON_MAX           SDL_CONTROLLER_BUTTON_MAX

// Internal Shared Data ////////////////////////////////////////////////////////

extern bool R2D_diagnostics;  // flag for whether to print diagnostics with R2D_Log

// Type Definitions ////////////////////////////////////////////////////////////

// R2D_Event
typedef struct {
  int which;
  int type;
  int button;
  bool dblclick;
  const char *key;
  int x;
  int y;
  int delta_x;
  int delta_y;
  int direction;
  int axis;
  int value;
} R2D_Event;

typedef void (*R2D_Update)();
typedef void (*R2D_Render)();
typedef void (*R2D_On_Key)(R2D_Event e);
typedef void (*R2D_On_Mouse)(R2D_Event e);
typedef void (*R2D_On_Controller)(R2D_Event e);

// R2D_GL_Point, for graphics calculations
typedef struct {
  GLfloat x;
  GLfloat y;
} R2D_GL_Point;

// R2D_Color
typedef struct {
  GLfloat r;
  GLfloat g;
  GLfloat b;
  GLfloat a;
} R2D_Color;

// R2D_Mouse
typedef struct {
  int visible;
  int x;
  int y;
} R2D_Mouse;

// R2D_Viewport
typedef struct {
  int width;
  int height;
  int mode;
} R2D_Viewport;

// R2D_Window
typedef struct {
  SDL_Window *sdl;
  SDL_GLContext glcontext;
  const GLubyte *R2D_GL_VENDOR;
  const GLubyte *R2D_GL_RENDERER;
  const GLubyte *R2D_GL_VERSION;
  GLint R2D_GL_MAJOR_VERSION;
  GLint R2D_GL_MINOR_VERSION;
  const GLubyte *R2D_GL_SHADING_LANGUAGE_VERSION;
  const char *title;
  int width;
  int height;
  int orig_width;
  int orig_height;
  R2D_Viewport viewport;
  R2D_Update update;
  R2D_Render render;
  int flags;
  R2D_Mouse mouse;
  R2D_On_Key on_key;
  R2D_On_Mouse on_mouse;
  R2D_On_Controller on_controller;
  bool vsync;
  int fps_cap;
  R2D_Color background;
  const char *icon;
  Uint32 frames;
  Uint32 elapsed_ms;
  Uint32 loop_ms;
  Uint32 delay_ms;
  double fps;
  bool close;
} R2D_Window;


// R2D_Sound
typedef struct {
  const char *path;
  Mix_Chunk *data;
} R2D_Sound;

// R2D_Music
typedef struct {
  const char *path;
  Mix_Music *data;
  int length; // Length of music track
} R2D_Music;

// Ruby 2D Functions ///////////////////////////////////////////////////////////

/*
 * Checks if a file exists and can be accessed
 */
bool R2D_FileExists(const char *path);

/*
 * Logs standard messages to the console
 */
void R2D_Log(int type, const char *msg, ...);

/*
 * Logs Ruby 2D errors to the console, with caller and message body
 */
void R2D_Error(const char *caller, const char *msg, ...);

/*
 * Enable/disable logging of diagnostics
 */
void R2D_Diagnostics(bool status);

/*
 * Enable terminal colors in Windows
 */
void R2D_Windows_EnableTerminalColors();

/*
* Initialize Ruby 2D subsystems
*/
bool R2D_Init();

/*
 * Gets the primary display's dimensions
 */
void R2D_GetDisplayDimensions(int *w, int *h);

/*
 * Quits Ruby 2D subsystems
 */
void R2D_Quit(void);

// Shapes //////////////////////////////////////////////////////////////////////

/*
 * Rotate a point around a given point
 * Params:
 *   p      The point to rotate
 *   angle  The angle in degrees
 *   rx     The x coordinate to rotate around
 *   ry     The y coordinate to rotate around
 */
R2D_GL_Point R2D_RotatePoint(R2D_GL_Point p, GLfloat angle, GLfloat rx, GLfloat ry);

/*
 * Get the point to be rotated around given a position in a rectangle
 */
R2D_GL_Point R2D_GetRectRotationPoint(int x, int y, int w, int h, int position);

/*
 * Draw a triangle
 */
void R2D_DrawTriangle(
  GLfloat x1, GLfloat y1,
  GLfloat r1, GLfloat g1, GLfloat b1, GLfloat a1,
  GLfloat x2, GLfloat y2,
  GLfloat r2, GLfloat g2, GLfloat b2, GLfloat a2,
  GLfloat x3, GLfloat y3,
  GLfloat r3, GLfloat g3, GLfloat b3, GLfloat a3
);

/*
 * Draw a quad, using two triangles
 */
void R2D_DrawQuad(
  GLfloat x1, GLfloat y1,
  GLfloat r1, GLfloat g1, GLfloat b1, GLfloat a1,
  GLfloat x2, GLfloat y2,
  GLfloat r2, GLfloat g2, GLfloat b2, GLfloat a2,
  GLfloat x3, GLfloat y3,
  GLfloat r3, GLfloat g3, GLfloat b3, GLfloat a3,
  GLfloat x4, GLfloat y4,
  GLfloat r4, GLfloat g4, GLfloat b4, GLfloat a4
);

/*
 * Draw a line from a quad
 */
void R2D_DrawLine(
  GLfloat x1, GLfloat y1, GLfloat x2, GLfloat y2,
  GLfloat width,
  GLfloat r1, GLfloat g1, GLfloat b1, GLfloat a1,
  GLfloat r2, GLfloat g2, GLfloat b2, GLfloat a2,
  GLfloat r3, GLfloat g3, GLfloat b3, GLfloat a3,
  GLfloat r4, GLfloat g4, GLfloat b4, GLfloat a4
);

/*
 * Draw a circle from triangles
 */
void R2D_DrawCircle(
  GLfloat x, GLfloat y, GLfloat radius, int sectors,
  GLfloat r, GLfloat g, GLfloat b, GLfloat a
);

// Image ///////////////////////////////////////////////////////////////////////

/*
 * Create a surface with image pixel data, given a file path
 */
SDL_Surface *R2D_CreateImageSurface(const char *path);

/*
 * Convert images to RGB format if they are in a different (BGR for example) format.
 */
void R2D_ImageConvertToRGB(SDL_Surface *surface);

// Font ////////////////////////////////////////////////////////////////////////

/*
 * Create a TTF_Font object given a path to a font and a size
 */
TTF_Font *R2D_FontCreateTTFFont(const char *path, int size, const char *style);

// Text ////////////////////////////////////////////////////////////////////////

/*
 * Create a SDL_Surface that contains the pixel data to render text, given a font and message
 */
SDL_Surface *R2D_TextCreateSurface(TTF_Font *font, const char *message);

// Sound ///////////////////////////////////////////////////////////////////////

/*
 * Create a sound, given an audio file path
 */
R2D_Sound *R2D_CreateSound(const char *path);

/*
 * Play the sound
 */
void R2D_PlaySound(R2D_Sound *snd);

/*
 * Get the sound's length
 */
int R2D_GetSoundLength(R2D_Sound *snd);

/*
 * Get the sound's volume
 */
int R2D_GetSoundVolume(R2D_Sound *snd);

/*
 * Set the sound's volume a given percentage
 */
void R2D_SetSoundVolume(R2D_Sound *snd, int volume);

/*
 * Get the sound mixer volume
 */
int R2D_GetSoundMixVolume();

/*
 * Set the sound mixer volume a given percentage
 */
void R2D_SetSoundMixVolume(int volume);

/*
 * Free the sound
 */
void R2D_FreeSound(R2D_Sound *snd);

// Music ///////////////////////////////////////////////////////////////////////

/*
 * Create the music, given an audio file path
 */
R2D_Music *R2D_CreateMusic(const char *path);

/*
 * Play the music
 */
void R2D_PlayMusic(R2D_Music *mus, bool loop);

/*
 * Pause the playing music
 */
void R2D_PauseMusic();

/*
 * Resume the current music
 */
void R2D_ResumeMusic();

/*
 * Stop the playing music; interrupts fader effects
 */
void R2D_StopMusic();

/*
 * Get the music volume
 */
int R2D_GetMusicVolume();

/*
 * Set the music volume a given percentage
 */
void R2D_SetMusicVolume(int volume);

/*
 * Fade out the playing music
 */
void R2D_FadeOutMusic(int ms);

/*
 * Get the length of the music in seconds
 */
int R2D_GetMusicLength(R2D_Music *mus);

/*
 * Free the music
 */
void R2D_FreeMusic(R2D_Music *mus);

// Input ///////////////////////////////////////////////////////////////////////

/*
 * Get the mouse coordinates relative to the viewport
 */
void R2D_GetMouseOnViewport(R2D_Window *window, int wx, int wy, int *x, int *y);

/*
 * Show the cursor over the window
 */
void R2D_ShowCursor();

/*
 * Hide the cursor over the window
 */
void R2D_HideCursor();

// Controllers /////////////////////////////////////////////////////////////////

/*
 * Add controller mapping from string
 */
void R2D_AddControllerMapping(const char *map);

/*
 * Load controller mappings from the specified file
 */
void R2D_AddControllerMappingsFromFile(const char *path);

/*
 * Check if joystick is a controller
 */
bool R2D_IsController(SDL_JoystickID id);

/*
 * Open controllers and joysticks
 */
void R2D_OpenControllers();

// Window //////////////////////////////////////////////////////////////////////

/*
 * Create a window
 */
R2D_Window *R2D_CreateWindow(
  const char *title, int width, int height, R2D_Update, R2D_Render, int flags
);

/*
 * Show the window
 */
int R2D_Show(R2D_Window *window);

/*
 * Set the icon for the window
 */
void R2D_SetIcon(R2D_Window *window, const char *icon);

/*
 * Take a screenshot of the window
 */
void R2D_Screenshot(R2D_Window *window, const char *path);

/*
 * Close the window
 */
int R2D_Close(R2D_Window *window);

/*
 * Free all resources
 */
int R2D_FreeWindow(R2D_Window *window);

// Ruby 2D OpenGL Functions ////////////////////////////////////////////////////

int R2D_GL_Init(R2D_Window *window);
void R2D_GL_PrintError(const char *error);
void R2D_GL_PrintContextInfo(R2D_Window *window);
void R2D_GL_StoreContextInfo(R2D_Window *window);
GLuint R2D_GL_LoadShader(GLenum type, const GLchar *shaderSrc, const char *shaderName);
int R2D_GL_CheckLinked(GLuint program, const char *name);
void R2D_GL_GetViewportScale(R2D_Window *window, int *w, int *h, double *scale);
void R2D_GL_SetViewport(R2D_Window *window);
void R2D_GL_CreateTexture(
  GLuint *id, GLint format,
  int w, int h,
  const GLvoid *data, GLint filter);
void R2D_GL_DrawTriangle(
  GLfloat x1, GLfloat y1,
  GLfloat r1, GLfloat g1, GLfloat b1, GLfloat a1,
  GLfloat x2, GLfloat y2,
  GLfloat r2, GLfloat g2, GLfloat b2, GLfloat a2,
  GLfloat x3, GLfloat y3,
  GLfloat r3, GLfloat g3, GLfloat b3, GLfloat a3);
void R2D_GL_DrawTexture(GLfloat coordinates[], GLfloat texture_coordinates[], GLfloat color[], int texture_id);
void R2D_GL_FreeTexture(GLuint *id);
void R2D_GL_Clear(R2D_Color clr);
void R2D_GL_FlushBuffers();

// OpenGL & GLES Internal Functions ////////////////////////////////////////////

#if GLES
  int R2D_GLES_Init();
  void R2D_GLES_ApplyProjection(GLfloat orthoMatrix[16]);
  void R2D_GLES_DrawTriangle(
    GLfloat x1, GLfloat y1,
    GLfloat r1, GLfloat g1, GLfloat b1, GLfloat a1,
    GLfloat x2, GLfloat y2,
    GLfloat r2, GLfloat g2, GLfloat b2, GLfloat a2,
    GLfloat x3, GLfloat y3,
    GLfloat r3, GLfloat g3, GLfloat b3, GLfloat a3);
  void R2D_GLES_DrawTexture(GLfloat coordinates[], GLfloat texture_coordinates[], GLfloat color[], int texture_id);
  void R2D_GLES_FlushBuffers();
#else
  int R2D_GL2_Init();
  int R2D_GL3_Init();
  void R2D_GL2_ApplyProjection(int w, int h);
  void R2D_GL3_ApplyProjection(GLfloat orthoMatrix[16]);
  void R2D_GL2_DrawTriangle(
    GLfloat x1, GLfloat y1,
    GLfloat r1, GLfloat g1, GLfloat b1, GLfloat a1,
    GLfloat x2, GLfloat y2,
    GLfloat r2, GLfloat g2, GLfloat b2, GLfloat a2,
    GLfloat x3, GLfloat y3,
    GLfloat r3, GLfloat g3, GLfloat b3, GLfloat a3);
  void R2D_GL3_DrawTriangle(
    GLfloat x1, GLfloat y1,
    GLfloat r1, GLfloat g1, GLfloat b1, GLfloat a1,
    GLfloat x2, GLfloat y2,
    GLfloat r2, GLfloat g2, GLfloat b2, GLfloat a2,
    GLfloat x3, GLfloat y3,
    GLfloat r3, GLfloat g3, GLfloat b3, GLfloat a3);
  void R2D_GL2_DrawTexture(GLfloat coordinates[], GLfloat texture_coordinates[], GLfloat color[], int texture_id);
  void R2D_GL3_DrawTexture(GLfloat coordinates[], GLfloat texture_coordinates[], GLfloat color[], int texture_id);
  void R2D_GL3_FlushBuffers();
#endif

#ifdef __cplusplus
}
#endif

#endif /* RUBY2D_H */
