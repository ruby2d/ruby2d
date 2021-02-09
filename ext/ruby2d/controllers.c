// controllers.c

#include "ruby2d.h"

// Stores the last joystick instance ID seen by the system. These instance IDs
// are unique and increment with each new joystick connected.
static int last_intance_id = -1;


/*
 * Add controller mapping from string
 */
void R2D_AddControllerMapping(const char *map) {
  int result = SDL_GameControllerAddMapping(map);

  char guid[33];
  strncpy(guid, map, 32);

  switch (result) {
    case 1:
      R2D_Log(R2D_INFO, "Mapping added for GUID: %s", guid);
      break;
    case 0:
      R2D_Log(R2D_INFO, "Mapping updated for GUID: %s", guid);
      break;
    case -1:
      R2D_Error("SDL_GameControllerAddMapping", SDL_GetError());
      break;
  }
}


/*
 * Add controller mappings from the specified file
 */
void R2D_AddControllerMappingsFromFile(const char *path) {
  if (!R2D_FileExists(path)) {
    R2D_Log(R2D_WARN, "Controller mappings file not found: %s", path);
    return;
  }

  int mappings_added = SDL_GameControllerAddMappingsFromFile(path);
  if (mappings_added == -1) {
    R2D_Error("SDL_GameControllerAddMappingsFromFile", SDL_GetError());
  } else {
    R2D_Log(R2D_INFO, "Added %i controller mapping(s)", mappings_added);
  }
}


/*
 * Check if joystick is a controller
 */
bool R2D_IsController(SDL_JoystickID id) {
  return SDL_GameControllerFromInstanceID(id) == NULL ? false : true;
}


/*
 * Open controllers and joysticks
 */
void R2D_OpenControllers() {

  char guid_str[33];

  // Enumerate joysticks
  for (int device_index = 0; device_index < SDL_NumJoysticks(); ++device_index) {

    // Check if joystick supports SDL's game controller interface (a mapping is available)
    if (SDL_IsGameController(device_index)) {
      SDL_GameController *controller = SDL_GameControllerOpen(device_index);
      SDL_JoystickID intance_id = SDL_JoystickInstanceID(SDL_GameControllerGetJoystick(controller));

      SDL_JoystickGetGUIDString(
        SDL_JoystickGetGUID(SDL_GameControllerGetJoystick(controller)),
        guid_str, 33
      );

      if (intance_id > last_intance_id) {
        if (controller) {
          R2D_Log(R2D_INFO, "Controller #%i: %s\n      GUID: %s", intance_id, SDL_GameControllerName(controller), guid_str);
        } else {
          R2D_Log(R2D_ERROR, "Could not open controller #%i: %s", intance_id, SDL_GetError());
        }
        last_intance_id = intance_id;
      }

    // Controller interface not supported, try to open as joystick
    } else {
      SDL_Joystick *joy = SDL_JoystickOpen(device_index);
      SDL_JoystickID intance_id = SDL_JoystickInstanceID(joy);

      if (!joy) {
        R2D_Log(R2D_ERROR, "Could not open controller");
      } else if(intance_id > last_intance_id) {
        SDL_JoystickGetGUIDString(
          SDL_JoystickGetGUID(joy),
          guid_str, 33
        );
        R2D_Log(R2D_INFO,
          "Controller #%i: %s\n      GUID: %s\n      Axes: %d\n      Buttons: %d\n      Balls: %d",
          intance_id, SDL_JoystickName(joy), guid_str, SDL_JoystickNumAxes(joy),
          SDL_JoystickNumButtons(joy), SDL_JoystickNumBalls(joy)
        );
        R2D_Log(R2D_WARN, "Controller #%i does not have a mapping available", intance_id);
        last_intance_id = intance_id;
      }
    }
  }
}
