// keyboard.c

#include "ruby2d.h"

/*
 * Initialize
 */
void R2D_Keyboard_Init() {
  r_define_class_method(ruby2d_ext_module, "key_names", ruby2d_ext_keyboard_key_names, r_args_variadic);
}


// Ruby 2D owns the keyboard's names rather than passing through SDL's
// SDL_GetScancodeName, which SDL documents as unsuitable for a stable name
// mapping: its names differ per platform (SDL_SCANCODE_LGUI is "Left GUI" on
// Linux but "Left Windows" on Windows), scancodes 40 and 158 both report
// "Return", and some report no name at all. These names are the same on every
// platform, and are what Ruby sees as `event.key`.
//
// Scancodes are physical key positions, so "a" is wherever QWERTY puts A
// regardless of the user's layout. Gaps in the range stay NULL and resolve to
// R2D_KEY_UNKNOWN.
static const char *const r2d_key_names[SDL_SCANCODE_COUNT] = {
  // Letters
  [SDL_SCANCODE_A] = "a",
  [SDL_SCANCODE_B] = "b",
  [SDL_SCANCODE_C] = "c",
  [SDL_SCANCODE_D] = "d",
  [SDL_SCANCODE_E] = "e",
  [SDL_SCANCODE_F] = "f",
  [SDL_SCANCODE_G] = "g",
  [SDL_SCANCODE_H] = "h",
  [SDL_SCANCODE_I] = "i",
  [SDL_SCANCODE_J] = "j",
  [SDL_SCANCODE_K] = "k",
  [SDL_SCANCODE_L] = "l",
  [SDL_SCANCODE_M] = "m",
  [SDL_SCANCODE_N] = "n",
  [SDL_SCANCODE_O] = "o",
  [SDL_SCANCODE_P] = "p",
  [SDL_SCANCODE_Q] = "q",
  [SDL_SCANCODE_R] = "r",
  [SDL_SCANCODE_S] = "s",
  [SDL_SCANCODE_T] = "t",
  [SDL_SCANCODE_U] = "u",
  [SDL_SCANCODE_V] = "v",
  [SDL_SCANCODE_W] = "w",
  [SDL_SCANCODE_X] = "x",
  [SDL_SCANCODE_Y] = "y",
  [SDL_SCANCODE_Z] = "z",

  // Number row
  [SDL_SCANCODE_1] = "digit_1",
  [SDL_SCANCODE_2] = "digit_2",
  [SDL_SCANCODE_3] = "digit_3",
  [SDL_SCANCODE_4] = "digit_4",
  [SDL_SCANCODE_5] = "digit_5",
  [SDL_SCANCODE_6] = "digit_6",
  [SDL_SCANCODE_7] = "digit_7",
  [SDL_SCANCODE_8] = "digit_8",
  [SDL_SCANCODE_9] = "digit_9",
  [SDL_SCANCODE_0] = "digit_0",

  // Return, escape, and whitespace
  [SDL_SCANCODE_RETURN] = "return",
  [SDL_SCANCODE_ESCAPE] = "escape",
  [SDL_SCANCODE_BACKSPACE] = "backspace",
  [SDL_SCANCODE_TAB] = "tab",
  [SDL_SCANCODE_SPACE] = "space",

  // Punctuation and caps lock
  [SDL_SCANCODE_MINUS] = "minus",
  [SDL_SCANCODE_EQUALS] = "equals",
  [SDL_SCANCODE_LEFTBRACKET] = "left_bracket",
  [SDL_SCANCODE_RIGHTBRACKET] = "right_bracket",
  [SDL_SCANCODE_BACKSLASH] = "backslash",
  [SDL_SCANCODE_NONUSHASH] = "nonus_hash",
  [SDL_SCANCODE_SEMICOLON] = "semicolon",
  [SDL_SCANCODE_APOSTROPHE] = "apostrophe",
  [SDL_SCANCODE_GRAVE] = "grave",
  [SDL_SCANCODE_COMMA] = "comma",
  [SDL_SCANCODE_PERIOD] = "period",
  [SDL_SCANCODE_SLASH] = "slash",
  [SDL_SCANCODE_CAPSLOCK] = "caps_lock",

  // Function keys F1-F12
  [SDL_SCANCODE_F1] = "f1",
  [SDL_SCANCODE_F2] = "f2",
  [SDL_SCANCODE_F3] = "f3",
  [SDL_SCANCODE_F4] = "f4",
  [SDL_SCANCODE_F5] = "f5",
  [SDL_SCANCODE_F6] = "f6",
  [SDL_SCANCODE_F7] = "f7",
  [SDL_SCANCODE_F8] = "f8",
  [SDL_SCANCODE_F9] = "f9",
  [SDL_SCANCODE_F10] = "f10",
  [SDL_SCANCODE_F11] = "f11",
  [SDL_SCANCODE_F12] = "f12",

  // Navigation, editing, and arrows
  [SDL_SCANCODE_PRINTSCREEN] = "print_screen",
  [SDL_SCANCODE_SCROLLLOCK] = "scroll_lock",
  [SDL_SCANCODE_PAUSE] = "pause",
  [SDL_SCANCODE_INSERT] = "insert",
  [SDL_SCANCODE_HOME] = "home",
  [SDL_SCANCODE_PAGEUP] = "page_up",
  [SDL_SCANCODE_DELETE] = "delete",
  [SDL_SCANCODE_END] = "end",
  [SDL_SCANCODE_PAGEDOWN] = "page_down",
  [SDL_SCANCODE_RIGHT] = "right",
  [SDL_SCANCODE_LEFT] = "left",
  [SDL_SCANCODE_DOWN] = "down",
  [SDL_SCANCODE_UP] = "up",

  // Num lock and the main keypad block
  [SDL_SCANCODE_NUMLOCKCLEAR] = "num_lock",
  [SDL_SCANCODE_KP_DIVIDE] = "keypad_divide",
  [SDL_SCANCODE_KP_MULTIPLY] = "keypad_multiply",
  [SDL_SCANCODE_KP_MINUS] = "keypad_minus",
  [SDL_SCANCODE_KP_PLUS] = "keypad_plus",
  [SDL_SCANCODE_KP_ENTER] = "keypad_enter",
  [SDL_SCANCODE_KP_1] = "keypad_1",
  [SDL_SCANCODE_KP_2] = "keypad_2",
  [SDL_SCANCODE_KP_3] = "keypad_3",
  [SDL_SCANCODE_KP_4] = "keypad_4",
  [SDL_SCANCODE_KP_5] = "keypad_5",
  [SDL_SCANCODE_KP_6] = "keypad_6",
  [SDL_SCANCODE_KP_7] = "keypad_7",
  [SDL_SCANCODE_KP_8] = "keypad_8",
  [SDL_SCANCODE_KP_9] = "keypad_9",
  [SDL_SCANCODE_KP_0] = "keypad_0",
  [SDL_SCANCODE_KP_PERIOD] = "keypad_period",

  // Non-US layout keys, application/menu, power, keypad equals
  [SDL_SCANCODE_NONUSBACKSLASH] = "nonus_backslash",
  [SDL_SCANCODE_APPLICATION] = "application",
  [SDL_SCANCODE_POWER] = "power",
  [SDL_SCANCODE_KP_EQUALS] = "keypad_equals",

  // Function keys F13-F24
  [SDL_SCANCODE_F13] = "f13",
  [SDL_SCANCODE_F14] = "f14",
  [SDL_SCANCODE_F15] = "f15",
  [SDL_SCANCODE_F16] = "f16",
  [SDL_SCANCODE_F17] = "f17",
  [SDL_SCANCODE_F18] = "f18",
  [SDL_SCANCODE_F19] = "f19",
  [SDL_SCANCODE_F20] = "f20",
  [SDL_SCANCODE_F21] = "f21",
  [SDL_SCANCODE_F22] = "f22",
  [SDL_SCANCODE_F23] = "f23",
  [SDL_SCANCODE_F24] = "f24",

  // Editing commands and volume
  [SDL_SCANCODE_EXECUTE] = "execute",
  [SDL_SCANCODE_HELP] = "help",
  [SDL_SCANCODE_MENU] = "menu",
  [SDL_SCANCODE_SELECT] = "select",
  [SDL_SCANCODE_STOP] = "stop",
  [SDL_SCANCODE_AGAIN] = "again",
  [SDL_SCANCODE_UNDO] = "undo",
  [SDL_SCANCODE_CUT] = "cut",
  [SDL_SCANCODE_COPY] = "copy",
  [SDL_SCANCODE_PASTE] = "paste",
  [SDL_SCANCODE_FIND] = "find",
  [SDL_SCANCODE_MUTE] = "mute",
  [SDL_SCANCODE_VOLUMEUP] = "volume_up",
  [SDL_SCANCODE_VOLUMEDOWN] = "volume_down",

  // Keypad comma and the AS/400 keypad equals
  [SDL_SCANCODE_KP_COMMA] = "keypad_comma",
  [SDL_SCANCODE_KP_EQUALSAS400] = "keypad_equals_as400",

  // International and language keys (IME / non-US keyboards)
  [SDL_SCANCODE_INTERNATIONAL1] = "international_1",
  [SDL_SCANCODE_INTERNATIONAL2] = "international_2",
  [SDL_SCANCODE_INTERNATIONAL3] = "international_3",
  [SDL_SCANCODE_INTERNATIONAL4] = "international_4",
  [SDL_SCANCODE_INTERNATIONAL5] = "international_5",
  [SDL_SCANCODE_INTERNATIONAL6] = "international_6",
  [SDL_SCANCODE_INTERNATIONAL7] = "international_7",
  [SDL_SCANCODE_INTERNATIONAL8] = "international_8",
  [SDL_SCANCODE_INTERNATIONAL9] = "international_9",
  [SDL_SCANCODE_LANG1] = "language_1",
  [SDL_SCANCODE_LANG2] = "language_2",
  [SDL_SCANCODE_LANG3] = "language_3",
  [SDL_SCANCODE_LANG4] = "language_4",
  [SDL_SCANCODE_LANG5] = "language_5",
  [SDL_SCANCODE_LANG6] = "language_6",
  [SDL_SCANCODE_LANG7] = "language_7",
  [SDL_SCANCODE_LANG8] = "language_8",
  [SDL_SCANCODE_LANG9] = "language_9",

  // Legacy terminal and selection keys
  [SDL_SCANCODE_ALTERASE] = "alt_erase",
  [SDL_SCANCODE_SYSREQ] = "sys_req",
  [SDL_SCANCODE_CANCEL] = "cancel",
  [SDL_SCANCODE_CLEAR] = "clear",
  [SDL_SCANCODE_PRIOR] = "prior",
  [SDL_SCANCODE_RETURN2] = "return2",
  [SDL_SCANCODE_SEPARATOR] = "separator",
  [SDL_SCANCODE_OUT] = "out",
  [SDL_SCANCODE_OPER] = "oper",
  [SDL_SCANCODE_CLEARAGAIN] = "clear_again",
  [SDL_SCANCODE_CRSEL] = "cr_sel",
  [SDL_SCANCODE_EXSEL] = "ex_sel",

  // Extended keypad: calculator-style operators and memory keys
  [SDL_SCANCODE_KP_00] = "keypad_00",
  [SDL_SCANCODE_KP_000] = "keypad_000",
  [SDL_SCANCODE_THOUSANDSSEPARATOR] = "thousands_separator",
  [SDL_SCANCODE_DECIMALSEPARATOR] = "decimal_separator",
  [SDL_SCANCODE_CURRENCYUNIT] = "currency_unit",
  [SDL_SCANCODE_CURRENCYSUBUNIT] = "currency_subunit",
  [SDL_SCANCODE_KP_LEFTPAREN] = "keypad_left_paren",
  [SDL_SCANCODE_KP_RIGHTPAREN] = "keypad_right_paren",
  [SDL_SCANCODE_KP_LEFTBRACE] = "keypad_left_brace",
  [SDL_SCANCODE_KP_RIGHTBRACE] = "keypad_right_brace",
  [SDL_SCANCODE_KP_TAB] = "keypad_tab",
  [SDL_SCANCODE_KP_BACKSPACE] = "keypad_backspace",
  [SDL_SCANCODE_KP_A] = "keypad_a",
  [SDL_SCANCODE_KP_B] = "keypad_b",
  [SDL_SCANCODE_KP_C] = "keypad_c",
  [SDL_SCANCODE_KP_D] = "keypad_d",
  [SDL_SCANCODE_KP_E] = "keypad_e",
  [SDL_SCANCODE_KP_F] = "keypad_f",
  [SDL_SCANCODE_KP_XOR] = "keypad_xor",
  [SDL_SCANCODE_KP_POWER] = "keypad_power",
  [SDL_SCANCODE_KP_PERCENT] = "keypad_percent",
  [SDL_SCANCODE_KP_LESS] = "keypad_less",
  [SDL_SCANCODE_KP_GREATER] = "keypad_greater",
  [SDL_SCANCODE_KP_AMPERSAND] = "keypad_ampersand",
  [SDL_SCANCODE_KP_DBLAMPERSAND] = "keypad_double_ampersand",
  [SDL_SCANCODE_KP_VERTICALBAR] = "keypad_vertical_bar",
  [SDL_SCANCODE_KP_DBLVERTICALBAR] = "keypad_double_vertical_bar",
  [SDL_SCANCODE_KP_COLON] = "keypad_colon",
  [SDL_SCANCODE_KP_HASH] = "keypad_hash",
  [SDL_SCANCODE_KP_SPACE] = "keypad_space",
  [SDL_SCANCODE_KP_AT] = "keypad_at",
  [SDL_SCANCODE_KP_EXCLAM] = "keypad_exclam",
  [SDL_SCANCODE_KP_MEMSTORE] = "keypad_mem_store",
  [SDL_SCANCODE_KP_MEMRECALL] = "keypad_mem_recall",
  [SDL_SCANCODE_KP_MEMCLEAR] = "keypad_mem_clear",
  [SDL_SCANCODE_KP_MEMADD] = "keypad_mem_add",
  [SDL_SCANCODE_KP_MEMSUBTRACT] = "keypad_mem_subtract",
  [SDL_SCANCODE_KP_MEMMULTIPLY] = "keypad_mem_multiply",
  [SDL_SCANCODE_KP_MEMDIVIDE] = "keypad_mem_divide",
  [SDL_SCANCODE_KP_PLUSMINUS] = "keypad_plus_minus",
  [SDL_SCANCODE_KP_CLEAR] = "keypad_clear",
  [SDL_SCANCODE_KP_CLEARENTRY] = "keypad_clear_entry",
  [SDL_SCANCODE_KP_BINARY] = "keypad_binary",
  [SDL_SCANCODE_KP_OCTAL] = "keypad_octal",
  [SDL_SCANCODE_KP_DECIMAL] = "keypad_decimal",
  [SDL_SCANCODE_KP_HEXADECIMAL] = "keypad_hexadecimal",

  // Modifiers (left and right are distinct physical keys)
  [SDL_SCANCODE_LCTRL] = "left_ctrl",
  [SDL_SCANCODE_LSHIFT] = "left_shift",
  [SDL_SCANCODE_LALT] = "left_alt",
  [SDL_SCANCODE_LGUI] = "left_gui",
  [SDL_SCANCODE_RCTRL] = "right_ctrl",
  [SDL_SCANCODE_RSHIFT] = "right_shift",
  [SDL_SCANCODE_RALT] = "right_alt",
  [SDL_SCANCODE_RGUI] = "right_gui",

  // AltGr / mode switch
  [SDL_SCANCODE_MODE] = "mode",

  // Sleep, wake, and media transport
  [SDL_SCANCODE_SLEEP] = "sleep",
  [SDL_SCANCODE_WAKE] = "wake",
  [SDL_SCANCODE_CHANNEL_INCREMENT] = "channel_increment",
  [SDL_SCANCODE_CHANNEL_DECREMENT] = "channel_decrement",
  [SDL_SCANCODE_MEDIA_PLAY] = "media_play",
  [SDL_SCANCODE_MEDIA_PAUSE] = "media_pause",
  [SDL_SCANCODE_MEDIA_RECORD] = "media_record",
  [SDL_SCANCODE_MEDIA_FAST_FORWARD] = "media_fast_forward",
  [SDL_SCANCODE_MEDIA_REWIND] = "media_rewind",
  [SDL_SCANCODE_MEDIA_NEXT_TRACK] = "media_next_track",
  [SDL_SCANCODE_MEDIA_PREVIOUS_TRACK] = "media_previous_track",
  [SDL_SCANCODE_MEDIA_STOP] = "media_stop",
  [SDL_SCANCODE_MEDIA_EJECT] = "media_eject",
  [SDL_SCANCODE_MEDIA_PLAY_PAUSE] = "media_play_pause",
  [SDL_SCANCODE_MEDIA_SELECT] = "media_select",

  // Application control (browser and document commands)
  [SDL_SCANCODE_AC_NEW] = "ac_new",
  [SDL_SCANCODE_AC_OPEN] = "ac_open",
  [SDL_SCANCODE_AC_CLOSE] = "ac_close",
  [SDL_SCANCODE_AC_EXIT] = "ac_exit",
  [SDL_SCANCODE_AC_SAVE] = "ac_save",
  [SDL_SCANCODE_AC_PRINT] = "ac_print",
  [SDL_SCANCODE_AC_PROPERTIES] = "ac_properties",
  [SDL_SCANCODE_AC_SEARCH] = "ac_search",
  [SDL_SCANCODE_AC_HOME] = "ac_home",
  [SDL_SCANCODE_AC_BACK] = "ac_back",
  [SDL_SCANCODE_AC_FORWARD] = "ac_forward",
  [SDL_SCANCODE_AC_STOP] = "ac_stop",
  [SDL_SCANCODE_AC_REFRESH] = "ac_refresh",
  [SDL_SCANCODE_AC_BOOKMARKS] = "ac_bookmarks",

  // Mobile and phone keys
  [SDL_SCANCODE_SOFTLEFT] = "soft_left",
  [SDL_SCANCODE_SOFTRIGHT] = "soft_right",
  [SDL_SCANCODE_CALL] = "call",
  [SDL_SCANCODE_ENDCALL] = "end_call",
};

#define R2D_KEY_UNKNOWN "unknown"

// Name for a scancode, never NULL.
const char *R2D_KeyName(int scancode) {
  if (scancode < 0 || scancode >= SDL_SCANCODE_COUNT) return R2D_KEY_UNKNOWN;
  const char *name = r2d_key_names[scancode];
  return name ? name : R2D_KEY_UNKNOWN;
}


/*
 * Ext.key_names → Array of Symbols
 *
 * Every key name this build can report, including :unknown. Ruby calls this
 * once to build its key vocabulary, so the name list has a single home — here,
 * next to the SDL scancodes it maps.
 */
R_VAL ruby2d_ext_keyboard_key_names(RUBY2D_METHOD_ARGS_VARIADIC) {
  RUBY2D_EXTRACT_VARIADIC;
  (void)argc; (void)argv;

  R_VAL ary = r_ary_new();
  r_ary_push(ary, r_char_to_sym(R2D_KEY_UNKNOWN));
  for (int i = 0; i < SDL_SCANCODE_COUNT; i++) {
    if (r2d_key_names[i]) r_ary_push(ary, r_char_to_sym(r2d_key_names[i]));
  }
  return ary;
}
