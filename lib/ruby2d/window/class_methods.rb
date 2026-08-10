# Ruby2D::Window::ClassMethods

module Ruby2D
  class Window
    # Class-level accessors that delegate to the DSL window instance
    module ClassMethods
      # Get the current window instance
      def current
        DSL.window
      end

      # Get the window title
      def title
        DSL.window.title
      end

      # Get the background color
      def background
        DSL.window.background
      end

      # Get the window width
      def width
        DSL.window.width
      end

      # Get the window height
      def height
        DSL.window.height
      end

      # Get the viewport width
      def viewport_width
        DSL.window.viewport_width
      end

      # Get the viewport height
      def viewport_height
        DSL.window.viewport_height
      end

      # Get the viewport scaling mode
      def viewport_mode
        DSL.window.viewport_mode
      end

      # Get the window-wide texture scaling mode
      def scale_mode
        DSL.window.scale_mode
      end

      # Get the display width
      def display_width
        DSL.window.display_width
      end

      # Get the display height
      def display_height
        DSL.window.display_height
      end

      # Get the display width in physical pixels
      def display_pixel_width
        DSL.window.display_pixel_width
      end

      # Get the display height in physical pixels
      def display_pixel_height
        DSL.window.display_pixel_height
      end

      # Get whether the window is resizable
      def resizable
        DSL.window.resizable
      end

      # Get whether high DPI mode is enabled
      def highdpi
        DSL.window.highdpi
      end

      # Get the pixel scale
      def pixel_scale
        DSL.window.pixel_scale
      end

      # Get the total number of rendered frames
      def frames
        DSL.window.frames
      end

      # Get the current frames per second
      def fps
        DSL.window.fps
      end

      # Get the most recent frame's delta time, in seconds (clamped to 0.1s).
      # The same value passed to an `update do |dt|` block; the time source
      # every animation advances on.
      def delta_time
        DSL.window.delta_time
      end

      # Get the FPS cap
      def fps_cap
        DSL.window.fps_cap
      end

      # Get the mouse x position
      def mouse_x
        DSL.window.mouse_x
      end

      # Get the mouse y position
      def mouse_y
        DSL.window.mouse_y
      end

      # Get the mouse position as [x, y]
      def mouse_position
        DSL.window.mouse_position
      end

      # Get whether diagnostics are enabled
      def diagnostics
        DSL.window.diagnostics
      end

      # Get whether FPS display is enabled
      def show_fps
        DSL.window.show_fps
      end

      # Take a screenshot, saving to `path` (or a timestamped file if omitted)
      def screenshot(path = nil)
        DSL.window.screenshot(path)
      end

      # Get a window attribute by name
      def get(sym)
        DSL.window.get(sym)
      end

      # Set window attributes
      def set(opts)
        DSL.window.set(opts)
      end

      # Register an event handler
      def on(event = nil, **filters, &proc)
        DSL.window.on(event, **filters, &proc)
      end

      # Remove an event handler
      def off(event_descriptor)
        DSL.window.off(event_descriptor)
      end

      # Add an object to the window
      def add(object)
        DSL.window.add(object)
      end

      # Remove an object from the window
      def remove(object)
        DSL.window.remove(object)
      end

      # Register an interactive object
      def register_interactive(object)
        DSL.window.register_interactive(object)
      end

      # Unregister an interactive object
      def unregister_interactive(object)
        DSL.window.unregister_interactive(object)
      end

      # Clear all objects from the window
      def clear
        DSL.window.clear
      end

      # Set the update callback
      def update(&proc)
        DSL.window.update(&proc)
      end

      # Set the render callback
      def render(&proc)
        DSL.window.render(&proc)
      end

      # Show the window
      def show
        DSL.window.show
      end

      # Get the current cursor state
      def cursor
        DSL.window.cursor
      end

      # Set the cursor: `:visible`, `:hidden`, or a system cursor name
      def cursor=(name)
        DSL.window.cursor = name
      end

      # Close the window
      def close
        DSL.window.close
      end

      # Check if the window is ready for rendering
      def render_ready_check
        return if shown?

        raise Error,
              'Attempting to draw before the window is ready. Please put calls to render() inside of a render block.'
      end
    end
  end
end
