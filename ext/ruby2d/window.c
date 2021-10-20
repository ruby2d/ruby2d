// window.c

#include "ruby2d.h"


/*
 * Create a window
 */
R2D_Window *R2D_CreateWindow(const char *title, int width, int height,
                             R2D_Update update, R2D_Render render, int flags) {

  R2D_Init();

  SDL_DisplayMode dm;
  SDL_GetCurrentDisplayMode(0, &dm);
  R2D_Log(R2D_INFO, "Current display mode is %dx%dpx @ %dhz", dm.w, dm.h, dm.refresh_rate);

  width  = width  == R2D_DISPLAY_WIDTH  ? dm.w : width;
  height = height == R2D_DISPLAY_HEIGHT ? dm.h : height;

  // Allocate window and set default values
  R2D_Window *window      = (R2D_Window *) malloc(sizeof(R2D_Window));
  window->sdl             = NULL;
  window->glcontext       = NULL;
  window->title           = title;
  window->width           = width;
  window->height          = height;
  window->orig_width      = width;
  window->orig_height     = height;
  window->viewport.width  = width;
  window->viewport.height = height;
  window->viewport.mode   = R2D_SCALE;
  window->update          = update;
  window->render          = render;
  window->flags           = flags;
  window->on_key          = NULL;
  window->on_mouse        = NULL;
  window->on_controller   = NULL;
  window->vsync           = true;
  window->fps_cap         = 60;
  window->background.r    = 0.0;
  window->background.g    = 0.0;
  window->background.b    = 0.0;
  window->background.a    = 1.0;
  window->icon            = NULL;
  window->close           = true;

  // Return the window structure
  return window;
}


const Uint8 *key_state;

Uint32 frames;
Uint32 frames_last_sec;
Uint32 start_ms;
Uint32 next_second_ms;
Uint32 begin_ms;
Uint32 end_ms;
Uint32 elapsed_ms;
Uint32 loop_ms;
int delay_ms;
double decay_rate;
double fps;

R2D_Window *window;







void main_loop() {

  // Clear Frame /////////////////////////////////////////////////////////////

  R2D_GL_Clear(window->background);

  // Set FPS /////////////////////////////////////////////////////////////////

  frames++;
  frames_last_sec++;
  end_ms = SDL_GetTicks();
  elapsed_ms = end_ms - start_ms;

  // Calculate the frame rate using an exponential moving average
  if (next_second_ms < end_ms) {
    fps = decay_rate * fps + (1.0 - decay_rate) * frames_last_sec;
    frames_last_sec = 0;
    next_second_ms = SDL_GetTicks() + 1000;
  }

  loop_ms = end_ms - begin_ms;
  delay_ms = (1000 / window->fps_cap) - loop_ms;

  if (delay_ms < 0) delay_ms = 0;

  // Note: `loop_ms + delay_ms` should equal `1000 / fps_cap`

  #ifndef __EMSCRIPTEN__
    SDL_Delay(delay_ms);
  #endif

  begin_ms = SDL_GetTicks();

  // Handle Input and Window Events //////////////////////////////////////////

  int mx, my;  // mouse x, y coordinates

  SDL_Event e;
  while (SDL_PollEvent(&e)) {
    switch (e.type) {

      case SDL_KEYDOWN:
        if (window->on_key && e.key.repeat == 0) {
          R2D_Event event = {
            .type = R2D_KEY_DOWN, .key = SDL_GetScancodeName(e.key.keysym.scancode)
          };
          window->on_key(event);
        }
        break;

      case SDL_KEYUP:
        if (window->on_key) {
          R2D_Event event = {
            .type = R2D_KEY_UP, .key = SDL_GetScancodeName(e.key.keysym.scancode)
          };
          window->on_key(event);
        }
        break;

      case SDL_MOUSEBUTTONDOWN: case SDL_MOUSEBUTTONUP:
        if (window->on_mouse) {
          R2D_GetMouseOnViewport(window, e.button.x, e.button.y, &mx, &my);
          R2D_Event event = {
            .button = e.button.button, .x = mx, .y = my
          };
          event.type = e.type == SDL_MOUSEBUTTONDOWN ? R2D_MOUSE_DOWN : R2D_MOUSE_UP;
          event.dblclick = e.button.clicks == 2 ? true : false;
          window->on_mouse(event);
        }
        break;

      case SDL_MOUSEWHEEL:
        if (window->on_mouse) {
          R2D_Event event = {
            .type = R2D_MOUSE_SCROLL, .direction = e.wheel.direction,
            .delta_x = e.wheel.x, .delta_y = -e.wheel.y
          };
          window->on_mouse(event);
        }
        break;

      case SDL_MOUSEMOTION:
        if (window->on_mouse) {
          R2D_GetMouseOnViewport(window, e.motion.x, e.motion.y, &mx, &my);
          R2D_Event event = {
            .type = R2D_MOUSE_MOVE,
            .x = mx, .y = my, .delta_x = e.motion.xrel, .delta_y = e.motion.yrel
          };
          window->on_mouse(event);
        }
        break;

      case SDL_CONTROLLERAXISMOTION:
        if (window->on_controller) {
          R2D_Event event = {
            .which = e.caxis.which, .type = R2D_AXIS,
            .axis = e.caxis.axis, .value = e.caxis.value
          };
          window->on_controller(event);
        }
        break;

      case SDL_JOYAXISMOTION:
        if (window->on_controller && !R2D_IsController(e.jbutton.which)) {
          R2D_Event event = {
            .which = e.jaxis.which, .type = R2D_AXIS,
            .axis = e.jaxis.axis, .value = e.jaxis.value
          };
          window->on_controller(event);
        }
        break;

      case SDL_CONTROLLERBUTTONDOWN: case SDL_CONTROLLERBUTTONUP:
        if (window->on_controller) {
          R2D_Event event = {
            .which = e.cbutton.which, .button = e.cbutton.button
          };
          event.type = e.type == SDL_CONTROLLERBUTTONDOWN ? R2D_BUTTON_DOWN : R2D_BUTTON_UP;
          window->on_controller(event);
        }
        break;

      case SDL_JOYBUTTONDOWN: case SDL_JOYBUTTONUP:
        if (window->on_controller && !R2D_IsController(e.jbutton.which)) {
          R2D_Event event = {
            .which = e.jbutton.which, .button = e.jbutton.button
          };
          event.type = e.type == SDL_JOYBUTTONDOWN ? R2D_BUTTON_DOWN : R2D_BUTTON_UP;
          window->on_controller(event);
        }
        break;

      case SDL_JOYDEVICEADDED:
        R2D_Log(R2D_INFO, "Controller connected (%i total)", SDL_NumJoysticks());
        R2D_OpenControllers();
        break;

      case SDL_JOYDEVICEREMOVED:
        if (R2D_IsController(e.jdevice.which)) {
          R2D_Log(R2D_INFO, "Controller #%i: %s removed (%i remaining)", e.jdevice.which, SDL_GameControllerName(SDL_GameControllerFromInstanceID(e.jdevice.which)), SDL_NumJoysticks());
          SDL_GameControllerClose(SDL_GameControllerFromInstanceID(e.jdevice.which));
        } else {
          R2D_Log(R2D_INFO, "Controller #%i: %s removed (%i remaining)", e.jdevice.which, SDL_JoystickName(SDL_JoystickFromInstanceID(e.jdevice.which)), SDL_NumJoysticks());
          SDL_JoystickClose(SDL_JoystickFromInstanceID(e.jdevice.which));
        }
        break;

      case SDL_WINDOWEVENT:
        switch (e.window.event) {
          case SDL_WINDOWEVENT_RESIZED:
            // Store new window size, set viewport
            window->width  = e.window.data1;
            window->height = e.window.data2;
            R2D_GL_SetViewport(window);
            break;
        }
        break;

      case SDL_QUIT:
        R2D_Close(window);
        break;
    }
  }

  // Detect keys held down
  int num_keys;
  key_state = SDL_GetKeyboardState(&num_keys);

  for (int i = 0; i < num_keys; i++) {
    if (window->on_key) {
      if (key_state[i] == 1) {
        R2D_Event event = {
          .type = R2D_KEY_HELD, .key = SDL_GetScancodeName(i)
        };
        window->on_key(event);
      }
    }
  }

  // Get and store mouse position relative to the viewport
  int wx, wy;  // mouse x, y coordinates relative to the window
  SDL_GetMouseState(&wx, &wy);
  R2D_GetMouseOnViewport(window, wx, wy, &window->mouse.x, &window->mouse.y);

  // Update Window State /////////////////////////////////////////////////////

  // Store new values in the window
  window->frames     = frames;
  window->elapsed_ms = elapsed_ms;
  window->loop_ms    = loop_ms;
  window->delay_ms   = delay_ms;
  window->fps        = fps;

  // Call update and render callbacks
  if (window->update) window->update();
  if (window->render) window->render();

  // Draw Frame //////////////////////////////////////////////////////////////

  // Render and flush all OpenGL buffers
  R2D_GL_FlushBuffers();

  // Swap buffers to display drawn contents in the window
  SDL_GL_SwapWindow(window->sdl);
}












/*
 * Show the window
 */
int R2D_Show(R2D_Window *win) {

  window = win;

  if (!window) {
    R2D_Error("R2D_Show", "Window cannot be shown (because it's NULL)");
    return 1;
  }

  // Create SDL window
  window->sdl = SDL_CreateWindow(
    window->title,                                   // title
    SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED,  // window position
    window->width, window->height,                   // window size
    SDL_WINDOW_OPENGL | window->flags                // flags
  );

  if (!window->sdl) R2D_Error("SDL_CreateWindow", SDL_GetError());
  if (window->icon) R2D_SetIcon(window, window->icon);

  // The window created by SDL might not actually be the requested size.
  // If it's not the same, retrieve and store the actual window size.
  int actual_width, actual_height;
  SDL_GetWindowSize(window->sdl, &actual_width, &actual_height);

  if ((window->width != actual_width) || (window->height != actual_height)) {
    R2D_Log(R2D_INFO,
      "Scaling window to %ix%i (requested size was %ix%i)",
      actual_width, actual_height, window->width, window->height
    );
    window->width  = actual_width;
    window->height = actual_height;
    window->orig_width  = actual_width;
    window->orig_height = actual_height;
  }

  // Set Up OpenGL /////////////////////////////////////////////////////////////

  R2D_GL_Init(window);

  // SDL 2.0.10 and macOS 10.15 fix ////////////////////////////////////////////

  #if MACOS
    SDL_SetWindowSize(window->sdl, window->width, window->height);
  #endif

  // Set Main Loop Data ////////////////////////////////////////////////////////


  frames = 0;           // Total frames since start
  frames_last_sec = 0;  // Frames in the last second
  start_ms = SDL_GetTicks();  // Elapsed time since start
  next_second_ms = SDL_GetTicks(); // The last time plus a second
  begin_ms = start_ms;  // Time at beginning of loop
  end_ms;               // Time at end of loop
  elapsed_ms;           // Total elapsed time
  loop_ms;              // Elapsed time of loop
  delay_ms;                // Amount of delay to achieve desired frame rate
  decay_rate = 0.5;  // Determines how fast an average decays over time
  fps = window->fps_cap;   // Moving average of actual FPS, initial value a guess

  // Enable VSync
  if (window->vsync) {
    if (!SDL_SetHint(SDL_HINT_RENDER_VSYNC, "1")) {
      R2D_Log(R2D_WARN, "VSync cannot be enabled");
    }
  }

  window->close = false;

  // Main Loop /////////////////////////////////////////////////////////////////

  #ifdef __EMSCRIPTEN__
    emscripten_set_main_loop(main_loop, 0, true);
  #else
    while (!window->close) main_loop();
  #endif

  return 0;
}



/*
 * Set the icon for the window
 */
void R2D_SetIcon(R2D_Window *window, const char *icon) {
  SDL_Surface *iconSurface = R2D_CreateImageSurface(icon);
  if (iconSurface) {
    window->icon = icon;
    SDL_SetWindowIcon(window->sdl, iconSurface);
    SDL_FreeSurface(iconSurface);
  } else {
    R2D_Log(R2D_WARN, "Could not set window icon");
  }
}


/*
 * Take a screenshot of the window
 */
void R2D_Screenshot(R2D_Window *window, const char *path) {

  #if GLES
    R2D_Error("R2D_Screenshot", "Not supported in OpenGL ES");
  #else
    // Create a surface the size of the window
    SDL_Surface *surface = SDL_CreateRGBSurface(
      SDL_SWSURFACE, window->width, window->height, 24,
      0x000000FF, 0x0000FF00, 0x00FF0000, 0
    );

    // Grab the pixels from the front buffer, save to surface
    glReadBuffer(GL_FRONT);
    glReadPixels(0, 0, window->width, window->height, GL_RGB, GL_UNSIGNED_BYTE, surface->pixels);

    // Flip image vertically

    void *temp_row = (void *)malloc(surface->pitch);
    if (!temp_row) {
      R2D_Error("R2D_Screenshot", "Out of memory!");
      SDL_FreeSurface(surface);
      return;
    }

    int height_div_2 = (int) (surface->h * 0.5);

    for (int index = 0; index < height_div_2; index++) {
      memcpy((Uint8 *)temp_row,(Uint8 *)(surface->pixels) + surface->pitch * index, surface->pitch);
      memcpy((Uint8 *)(surface->pixels) + surface->pitch * index, (Uint8 *)(surface->pixels) + surface->pitch * (surface->h - index-1), surface->pitch);
      memcpy((Uint8 *)(surface->pixels) + surface->pitch * (surface->h - index-1), temp_row, surface->pitch);
    }

    free(temp_row);

    // Save image to disk
    IMG_SavePNG(surface, path);
    SDL_FreeSurface(surface);
  #endif
}


/*
 * Close the window
 */
int R2D_Close(R2D_Window *window) {
  if (!window->close) {
    R2D_Log(R2D_INFO, "Closing window");
    window->close = true;
  }
  return 0;
}


/*
 * Free all resources
 */
int R2D_FreeWindow(R2D_Window *window) {
  R2D_Close(window);
  SDL_GL_DeleteContext(window->glcontext);
  SDL_DestroyWindow(window->sdl);
  free(window);
  return 0;
}
