# Ruby2D::Window::KeyEvents

module Ruby2D
  class Window
    # Keyboard input event handling
    module KeyEvents
      # Key down event method for class pattern
      def key_pressed?(key)
        @keys_down.include? Keyboard.validate!(key)
      end

      # Key held event method for class pattern
      def key_held?(key)
        @keys_held.include? Keyboard.validate!(key)
      end

      # Key up event method for class pattern
      def key_released?(key)
        @keys_up.include? Keyboard.validate!(key)
      end

      # Key callback method. `key` is a key name symbol, supplied by the
      # extension with the event or passed directly by a caller.
      def key_callback(type, key)
        update_key_held(type, key)

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

      # Held state lasts from press to release and changes before any handler
      # runs, the `:key` catch-all included, so `key_held?` inside a `:key_down`
      # handler already includes this key and everything pressed earlier (a
      # modifier held since a previous frame, say). The extension's per-frame
      # `:held` events mostly confirm what is already here; they also add a key
      # that was already down when the window opened.
      def update_key_held(type, key)
        case type
        when :down, :held
          @keys_held << key unless @keys_held.include? key
        when :up
          @keys_held.delete(key)
        end
      end

      def handle_key_down(type, key)
        close if @close_on_esc && key == :escape

        @keys_down << key unless @keys_down.include? key

        fire_event_handlers(:key_down) { KeyEvent.new(type, key) }
      end

      def handle_key_held(type, key)
        fire_event_handlers(:key_held) { KeyEvent.new(type, key) }
      end

      def handle_key_up(type, key)
        @keys_up << key unless @keys_up.include? key

        fire_event_handlers(:key_up) { KeyEvent.new(type, key) }
      end

      def init_key_event_stores
        # Event stores for class pattern. Down and up live one frame; held
        # lasts from press to release (see `update_key_held`).
        @keys_down = []
        @keys_held = []
        @keys_up   = []
      end
    end
  end
end
