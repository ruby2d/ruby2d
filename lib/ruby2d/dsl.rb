module Ruby2D
  # Domain-specific language methods for the top-level Ruby2D interface
  module DSL
    # Get the DSL window instance, constructing a default on first access
    def self.window
      @window ||= Ruby2D::Window.new
    end

    # Set the DSL window instance
    def self.window=(window)
      @window = window
    end

    # Whether a DSL window already exists, without constructing one. Used to
    # enforce the single-window rule (reading `window` would auto-create one).
    def self.window?
      !@window.nil?
    end

    # Get a window attribute by name
    def get(sym)
      DSL.window.get(sym)
    end

    # Set window attributes
    def set(opts)
      DSL.window.set(opts)
    end

    # Take a screenshot, saving to `path` (or a timestamped file if omitted)
    def screenshot(path = nil)
      DSL.window.screenshot(path)
    end

    # Register an event handler
    def on(event = nil, **filters, &proc)
      DSL.window.on(event, **filters, &proc)
    end

    # Remove an event handler
    def off(event_descriptor)
      DSL.window.off(event_descriptor)
    end

    # Set the update callback
    def update(&proc)
      DSL.window.update(&proc)
    end

    # Set the render callback. `z:` positions the block in the scene's
    # z-order — `:foreground` (default), `:background`, or a number.
    def render(z: :foreground, &proc)
      DSL.window.render(z: z, &proc)
    end

    # Monotonic seconds since the engine started (see `Window#elapsed`)
    def elapsed
      DSL.window.elapsed
    end

    # Clear all objects from the window
    def clear
      DSL.window.clear
    end

    # The connected gamepads, in connect order
    def gamepads
      DSL.window.gamepads
    end

    # Load a gamepad mapping from a file path or a single mapping string
    def add_gamepad_mapping(path_or_string)
      DSL.window.add_gamepad_mapping(path_or_string)
    end

    # Show the window
    def show
      DSL.window.show
    end

    # Close the window
    def close
      DSL.window.close
    end

    # Request a render on the next tick (for :on_demand render mode)
    def request_render
      DSL.window.request_render
    end
  end
end
