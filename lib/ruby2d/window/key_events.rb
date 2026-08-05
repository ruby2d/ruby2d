# Ruby2D::Window::KeyEvents

module Ruby2D
  class Window
    # Keyboard input event handling
    module KeyEvents
      # Key down event method for class pattern
      def key_pressed?(key)
        @keys_down.include? key
      end

      # Key held event method for class pattern
      def key_held?(key)
        @keys_held.include? key
      end

      # Key up event method for class pattern
      def key_released?(key)
        @keys_up.include? key
      end

      # Key callback method. `key` arrives already normalized (lowercased):
      # from `dispatch_events` via the cached scancode-name table, or from a
      # direct caller passing a lowercase key name.
      def key_callback(type, key)
        # All key events
        fire_event_handlers(:key) { KeyEvent.new(type, key) }

        case type
        # When key is pressed, fired once
        when :down
          handle_key_down type, key
        # When key is being held down, fired every frame
        when :held
          handle_key_held type, key
        # When key released, fired once
        when :up
          handle_key_up type, key
        end
      end

      private

      def handle_key_down(type, key)
        close if @close_on_esc && key == 'escape'

        @keys_down << key unless @keys_down.include? key

        fire_event_handlers(:key_down) { KeyEvent.new(type, key) }
      end

      def handle_key_held(type, key)
        @keys_held << key unless @keys_held.include? key

        fire_event_handlers(:key_held) { KeyEvent.new(type, key) }
      end

      def handle_key_up(type, key)
        @keys_up << key unless @keys_up.include? key

        fire_event_handlers(:key_up) { KeyEvent.new(type, key) }
      end

      def init_key_event_stores
        # Event stores for class pattern
        @keys_down = []
        @keys_held = []
        @keys_up   = []
        # Scancode → frozen lowercased name, filled lazily by `key_name`
        @key_names = []
      end
    end
  end
end
