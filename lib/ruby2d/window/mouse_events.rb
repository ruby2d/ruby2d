# Ruby2D::Window::MouseEvents

module Ruby2D
  class Window
    # Mouse input event handling
    module MouseEvents
      # Mouse down event method for class pattern
      def mouse_pressed?(btn)
        @mouse_buttons_down.include? btn
      end

      # Mouse up event method for class pattern
      def mouse_released?(btn)
        @mouse_buttons_up.include? btn
      end

      # Mouse held event method for class pattern
      def mouse_held?(btn)
        @mouse_buttons_held.include? btn
      end

      # Current mouse position as a [x, y] pair, for the common case where
      # both coordinates are needed together.
      def mouse_position
        [@mouse_x, @mouse_y]
      end

      # True while the cursor is over the window. Toggles on :mouse_enter /
      # :mouse_leave; starts false until SDL reports the first enter event.
      def mouse_inside?
        @mouse_inside
      end

      # Mouse scroll event method for class pattern
      def mouse_scrolled?
        @mouse_scroll_event
      end

      # Get the scroll direction
      def mouse_scroll_direction
        @mouse_scroll_direction
      end

      # Get the scroll delta x
      def mouse_scroll_delta_x
        @mouse_scroll_delta_x
      end

      # Get the scroll delta y
      def mouse_scroll_delta_y
        @mouse_scroll_delta_y
      end

      # Mouse move event method for class pattern
      def mouse_moved?
        @mouse_move_event
      end

      # Get the mouse move delta x
      def mouse_move_delta_x
        @mouse_move_delta_x
      end

      # Get the mouse move delta y
      def mouse_move_delta_y
        @mouse_move_delta_y
      end

      # Mouse callback method, called by the native and web extentions
      def mouse_callback(type, button, direction, x, y, delta_x, delta_y)
        # All mouse events
        fire_event_handlers(:mouse) { MouseEvent.new(type, button, direction, x, y, delta_x, delta_y) }

        case type
        # When mouse button pressed
        when :down
          handle_mouse_down type, button, x, y
        # When mouse button released
        when :up
          handle_mouse_up type, button, x, y
        # When mouse button is being held down, fired every frame
        when :held
          handle_mouse_held type, button, x, y
        # When mouse scrolling, wheel or trackpad
        when :scroll
          handle_mouse_scroll type, direction, delta_x, delta_y
        # When mouse motion / movement
        when :move
          handle_mouse_move type, x, y, delta_x, delta_y
        # When cursor enters the window
        when :enter
          handle_mouse_enter type
        # When cursor leaves the window
        when :leave
          handle_mouse_leave type
        end
      end

      private

      def handle_mouse_down(type, button, x, y)
        @mouse_buttons_down << button unless @mouse_buttons_down.include? button

        fire_event_handlers(:mouse_down) { MouseEvent.new(type, button, nil, x, y, nil, nil) }

        dispatch_object_mouse_down(button, x, y)
      end

      def handle_mouse_up(type, button, x, y)
        @mouse_buttons_up << button unless @mouse_buttons_up.include? button

        fire_event_handlers(:mouse_up) { MouseEvent.new(type, button, nil, x, y, nil, nil) }

        dispatch_object_mouse_up(button, x, y)
      end

      def handle_mouse_held(type, button, x, y)
        @mouse_buttons_held << button unless @mouse_buttons_held.include? button

        fire_event_handlers(:mouse_held) { MouseEvent.new(type, button, nil, x, y, nil, nil) }

        dispatch_object_mouse_held(button, x, y)
      end

      def handle_mouse_scroll(type, direction, delta_x, delta_y)
        @mouse_scroll_event     = true
        @mouse_scroll_direction = direction
        @mouse_scroll_delta_x   = delta_x
        @mouse_scroll_delta_y   = delta_y

        fire_event_handlers(:mouse_scroll) { MouseEvent.new(type, nil, direction, nil, nil, delta_x, delta_y) }

        dispatch_object_mouse_scroll(@mouse_x, @mouse_y, direction, delta_x, delta_y)
      end

      def handle_mouse_move(type, x, y, delta_x, delta_y)
        @mouse_move_event   = true
        @mouse_move_delta_x = delta_x
        @mouse_move_delta_y = delta_y

        fire_event_handlers(:mouse_move) { MouseEvent.new(type, nil, nil, x, y, delta_x, delta_y) }

        dispatch_object_mouse_move(x, y, delta_x, delta_y)
      end

      def handle_mouse_enter(type)
        @mouse_inside = true
        fire_event_handlers(:mouse_enter) { MouseEvent.new(type, nil, nil, nil, nil, nil, nil) }
      end

      def handle_mouse_leave(type)
        @mouse_inside = false
        fire_event_handlers(:mouse_leave) { MouseEvent.new(type, nil, nil, nil, nil, nil, nil) }
      end

      def init_mouse_event_stores
        @mouse_buttons_down = []
        @mouse_buttons_up   = []
        @mouse_buttons_held = []
        @mouse_scroll_event     = false
        @mouse_scroll_direction = nil
        @mouse_scroll_delta_x   = 0
        @mouse_scroll_delta_y   = 0
        @mouse_move_event   = false
        @mouse_move_delta_x = 0
        @mouse_move_delta_y = 0
        @mouse_inside       = false
      end
    end
  end
end
