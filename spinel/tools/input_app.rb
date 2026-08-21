# Fixture for the `input` check: does input reach the app on this target?
#
# Real input cannot be driven headlessly, so the app injects SDL events into
# itself through `ffi_source` — a keypress, mouse motion, a click, a wheel tick
# and a quit — which then travel the same poll -> queue -> drain -> dispatch
# path a user's keyboard and mouse would. Every handler prints one line, and
# the check compares the lines against the order and values it expects.
#
# `__INCLUDE__` is the SDL3 include directory, filled in by `check.rb` when it
# copies this file into place; `ffi_cflags` takes only a compile-time string.

require 'ruby2d'

module Inject
  ffi_cflags '-I__INCLUDE__'
  ffi_source <<~C
    #include <SDL3/SDL.h>
    void inject_key(int scancode, int down) {
      SDL_Event e; SDL_zero(e);
      e.type = down ? SDL_EVENT_KEY_DOWN : SDL_EVENT_KEY_UP;
      e.key.scancode = (SDL_Scancode)scancode;
      e.key.down = down ? true : false;
      SDL_PushEvent(&e);
    }
    void inject_motion(int x, int y, int dx, int dy) {
      SDL_Event e; SDL_zero(e);
      e.type = SDL_EVENT_MOUSE_MOTION;
      e.motion.x = x; e.motion.y = y; e.motion.xrel = dx; e.motion.yrel = dy;
      SDL_PushEvent(&e);
    }
    void inject_button(int button, int down, int x, int y) {
      SDL_Event e; SDL_zero(e);
      e.type = down ? SDL_EVENT_MOUSE_BUTTON_DOWN : SDL_EVENT_MOUSE_BUTTON_UP;
      e.button.button = button; e.button.down = down ? true : false;
      e.button.x = x; e.button.y = y;
      SDL_PushEvent(&e);
    }
    void inject_wheel(int dx, int dy) {
      SDL_Event e; SDL_zero(e);
      e.type = SDL_EVENT_MOUSE_WHEEL;
      e.wheel.x = dx; e.wheel.y = dy;
      SDL_PushEvent(&e);
    }
    void inject_quit(void) {
      SDL_Event e; SDL_zero(e);
      e.type = SDL_EVENT_QUIT;
      SDL_PushEvent(&e);
    }
  C
  ffi_func :inject_key, [:int, :int], :void
  ffi_func :inject_motion, [:int, :int, :int, :int], :void
  ffi_func :inject_button, [:int, :int, :int, :int], :void
  ffi_func :inject_wheel, [:int, :int], :void
  ffi_func :inject_quit, [], :void
end

set title: 'Spinel input check', width: 320, height: 240, background: 'navy'
sq = Square.new(x: 120, y: 80, size: 80, color: 'red')

def say(line)
  puts line
  $stdout.flush
end

on(:key_down)         { |e| say "key_down #{e.key.inspect}" }
on(:key_up)           { |e| say "key_up #{e.key.inspect}" }
on(key_down: :r)      { say 'filter key_down: :r' }
on(:mouse_down)       { |e| say "mouse_down #{e.button.inspect} #{e.x} #{e.y}" }
on(:mouse_up)         { |e| say "mouse_up #{e.button.inspect}" }
on(mouse_down: :left) { |e| say "filter mouse_down: :left #{e.x},#{e.y}" }
on(:mouse_move)       { |e| say "mouse_move #{e.x} #{e.y} #{e.delta_x},#{e.delta_y}" }
on(:mouse_scroll)     { |e| say "mouse_scroll #{e.direction.inspect} #{e.delta_x},#{e.delta_y}" }
on(:close)            { say 'close' }
sq.on(:hover)         { |e| say "object hover #{e.x},#{e.y}" }
sq.on(:hover_out)     { say 'object hover_out' }
sq.on(:mouse_down)    { |e| say "object mouse_down #{e.button.inspect}" }
sq.on(:click)         { |e| say "object click #{e.button.inspect}" }
sq.on(click: :left)   { say 'object filter click: :left' }

# One injection per frame with a frame between, so each event is drained and
# dispatched on its own and the output order is the dispatch order.
n = 0
update do
  n += 1
  case n
  when 2  then Inject.inject_key(44, 1)                 # SDL_SCANCODE_SPACE
  when 4  then Inject.inject_key(44, 0)
  when 6  then Inject.inject_key(21, 1)                 # SDL_SCANCODE_R
  when 8  then Inject.inject_key(21, 0)
  when 10 then Inject.inject_motion(100, 50, 3, -2)     # outside the square
  when 12 then Inject.inject_button(1, 1, 100, 50)      # SDL_BUTTON_LEFT
  when 14 then Inject.inject_button(1, 0, 100, 50)
  when 16 then Inject.inject_wheel(0, 1)
  when 18 then Inject.inject_motion(160, 120, 60, 70)   # into the square
  when 20 then Inject.inject_button(1, 1, 160, 120)
  when 22 then Inject.inject_button(1, 0, 160, 120)
  when 24 then Inject.inject_motion(10, 10, -150, -110) # out of it again
  when 26 then Inject.inject_quit                       # closes through the event path
  when 60 then say 'TIMEOUT: the quit event never closed the window'; close
  end
end

show
