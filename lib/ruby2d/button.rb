# Ruby2D::Button

module Ruby2D
  # A clickable region with optional visual and label. Button is itself the
  # interactive entity: it registers directly with `Window`'s interactive
  # registry and holds its own event handlers. The optional `@visual` is a
  # rendering concern, never an event-routing one.
  #
  # The visual is the button's geometry. Position, size, depth, visibility,
  # and scene membership are read from it live, so a wrapped shape the caller
  # moves, resizes, or restacks directly stays in step with the hit region and
  # the label; the button only keeps its own box when it has no visual. The
  # label is drawn by the visual, right after it and centered on its current
  # bounding box, so it sits on the visual at the visual's depth however the
  # visual changes.
  class Button
    include Interactive

    # Create a button. Three forms:
    #
    # Self-rendered:
    #   Button.new(x:, y:, width:, height:, label:, color:, hover_color:) { ... }
    #
    # Wrap a custom visual (any shape with an `x`/`y` position and `contains?`):
    #   Button.new(some_shape) { ... }
    #
    # Visual-less hit area (nothing rendered):
    #   Button.new(x:, y:, width:, height:) { ... }
    #
    # `hover_color:` and `pressed_color:` are opt-in. Pass an explicit color,
    # or `:auto` (lightens for hover, darkens for pressed). Omit for no tint.
    # When both are set and the user is hovering+pressed, pressed wins.
    def initialize(visual = nil, x: 0, y: 0, z: 0, width: 200, height: 50,
                   label: nil, color: nil, colour: nil,
                   hover_color: nil, hover_colour: nil,
                   pressed_color: nil, pressed_colour: nil,
                   label_color: nil, label_colour: nil,
                   hover_label_color: nil, hover_label_colour: nil,
                   pressed_label_color: nil, pressed_label_colour: nil,
                   stroke_color: nil, stroke_colour: nil, stroke_width: 0,
                   label_size: 20, add: true, visible: true,
                   padding: nil, padding_top: nil, padding_right: nil,
                   padding_bottom: nil, padding_left: nil, &on_click)
      base_color_input = color || colour
      hover_input = hover_color || hover_colour
      pressed_input = pressed_color || pressed_colour
      hover_label_input = hover_label_color || hover_label_colour
      pressed_label_input = pressed_label_color || pressed_label_colour
      stroke_input = stroke_color || stroke_colour

      # Label tints only make sense with a label to tint. Without one they would
      # silently install no-op hover/press handlers and force the button
      # interactive for no effect, so reject the combination up front.
      if (hover_label_input || pressed_label_input) && !label
        raise ArgumentError,
              '`hover_label_color`/`pressed_label_color` require a `label:` to tint'
      end

      if visual
        # A `Line` has endpoints but no position, so the button could neither
        # move it nor center a label on it.
        unless visual.respond_to?(:x=) && visual.respond_to?(:y=)
          raise ArgumentError,
                "`Button` can't wrap a `#{visual.class}`: it has no `x`/`y` position to move it by or to center a label on"
        end

        @visual = visual
        # Wrapping makes the visual the button's, so the button's `add:`
        # decides whether it is in the scene.
        (add ? @visual.add : @visual.remove) if @visual.respond_to?(:add)
      elsif label || base_color_input || stroke_input
        # Self-rendered: own a Rectangle for drawing.
        @visual = Rectangle.new(x: x, y: y, width: width, height: height, z: z,
                                color: base_color_input || '#333',
                                stroke_color: stroke_input,
                                stroke_width: stroke_width,
                                add: add, visible: visible,
                                padding: padding, padding_top: padding_top,
                                padding_right: padding_right,
                                padding_bottom: padding_bottom,
                                padding_left: padding_left)
      else
        # Visual-less: no rendering, no @visual. Just an interactive region,
        # whose box and scene membership (which `on` honors: handlers attached
        # while removed, or built with `add: false`, wait for `add`) live here.
        @visual = nil
        @x = x.is_a?(Symbol) ? 0 : x
        @y = y.is_a?(Symbol) ? 0 : y
        @z = z
        @width = width
        @height = height
        @visible = visible
        mark_added(add)
      end

      if label
        @label = Text.new(label, size: label_size,
                          color: label_color || label_colour || 'white', add: false)
        draw_label_with_visual
        center_label
      end

      if @visual && (hover_input || pressed_input || hover_label_input || pressed_label_input)
        install_state_tint(hover_input, pressed_input,
                           hover_label_input, pressed_label_input)
      end

      on(:click) { |e| on_click.call(e) } if on_click
    end

    # Remove the button: drop the visual (and with it the label) from the
    # scene and unregister from the interactive registry.
    def remove
      @visual ? @visual.remove : mark_added(false)
      Window.unregister_interactive(self)
    end

    # Re-add the button after `remove`. Restores rendering and re-registers in
    # the interactive registry if any handlers are attached.
    def add
      @visual ? @visual.add : mark_added(true)
      Window.register_interactive(self) if interactive?
    end

    # Mark the button visible.
    def show
      @visual ? @visual.show : (@visible = true)
    end

    # Mark the button hidden. Like any hidden object it keeps receiving events.
    def hide
      @visual ? @visual.hide : (@visible = false)
    end

    # Whether the button is currently visible.
    def visible?
      @visual ? @visual.visible? : @visible
    end

    # The visual drawn for this button, which decides where it ranks among
    # equal-z objects for hit-testing, and whether it is hit-tested at all: a
    # button whose visual is out of the scene is not. Nil for a visual-less
    # button, which is hit-tested whenever it is registered.
    def _scene_visual
      @visual
    end

    # Hit-test the button. With a visual the test is the visual's, so
    # non-rectangular shapes (Circle, Polygon, …) test against their actual
    # geometry. The visual-less box test is half-open like `Rectangle`'s: the
    # right and bottom edges are outside.
    def contains?(x, y)
      return @visual.contains?(x, y) if @visual

      x >= @x && x < (@x + @width) && y >= @y && y < (@y + @height)
    end

    def x
      @visual ? @visual.x : @x
    end

    # Set the x position. With a visual the value goes to it, so a symbol
    # (`:left`, `:center`, `:right`) sets alignment intent on a visual that
    # supports it and raises on one that doesn't, as it would on the shape
    # itself. A visual-less button has nothing to align and ignores a symbol.
    def x=(x)
      if @visual
        @visual.x = x
        center_label if @label
      elsif !x.is_a?(Symbol)
        @x = x
      end
    end

    def y
      @visual ? @visual.y : @y
    end

    # Set the y position. See `x=`.
    def y=(y)
      if @visual
        @visual.y = y
        center_label if @label
      elsif !y.is_a?(Symbol)
        @y = y
      end
    end

    def z
      return @z unless @visual

      @visual.respond_to?(:z) ? @visual.z : 0
    end

    # Set the depth. With a visual the visual moves in the scene, and the
    # label with it; a visual-less button only re-sorts among the interactive
    # objects it is hit-tested with.
    def z=(z)
      if @visual
        @visual.z = z if @visual.respond_to?(:z=)
      else
        @z = z
        Window.reorder(self)
      end
    end

    def width
      return @width unless @visual

      @visual.respond_to?(:width) ? @visual.width : 0
    end

    def height
      return @height unless @visual

      @visual.respond_to?(:height) ? @visual.height : 0
    end

    # Horizontal alignment intent of the visual, or nil.
    def x_align
      @visual.respond_to?(:x_align) ? @visual.x_align : nil
    end

    # Vertical alignment intent of the visual, or nil.
    def y_align
      @visual.respond_to?(:y_align) ? @visual.y_align : nil
    end

    # Alignment belongs to the visual, which resolves it when it draws; these
    # forward to it, and are no-ops on a visual-less button.
    def x_align=(sym)
      @visual.x_align = sym if @visual.respond_to?(:x_align=)
    end

    def y_align=(sym)
      @visual.y_align = sym if @visual.respond_to?(:y_align=)
    end

    # Get the label string.
    def label
      @label ? @label.content : nil
    end

    # Set the label string.
    def label=(text)
      return unless @label

      @label.content = text
      center_label
    end

    # Get the button's fill color. When a hover/pressed tint is configured this
    # returns the resting (base) color you set — not the transient tint while
    # hovered or pressed — so it stays symmetric with `color=`. Otherwise it
    # delegates to the visual. Returns nil when there is no colorable visual.
    def color
      return @base_color if @base_color

      @visual.respond_to?(:color) ? @visual.color : nil
    end

    # Set the button's fill color. When a hover/pressed tint is configured this
    # updates the resting (base) color and re-applies the current state so the
    # change survives the next hover/press cycle; otherwise it sets the visual
    # directly. Accepts a single color or a gradient (`Color::Set`). A no-op on
    # a visual-less button.
    def color=(c)
      return unless @visual.respond_to?(:color=)

      if @base_color
        @base_color = Color.set(c)
        apply_state
      else
        @visual.color = c
      end
    end

    alias colour color

    def colour=(c)
      self.color = c
    end

    # Draw the label over the visual, centered on its bounding box as it is
    # now, so the label follows a move, resize, or alignment made to the
    # visual directly. Called by the visual's draw hook, right after it draws.
    def _draw_label
      center_label
      @label._render_scene
    end

    private

    # Button isn't a scene-graph member (its visual is), so registry membership
    # is what makes it hit-testable. With a visual, dispatch skips the button
    # while the visual is out of the scene, so it can always join; a
    # visual-less button joins only while added, and `add` registers any
    # handlers attached in the meantime.
    def register_with_window
      Window.register_interactive(self) if @visual || added?
    end

    # Scene membership of a visual-less button, which has no scene object:
    # its own flag, and the window not having been cleared since it was set.
    def mark_added(added)
      @added = added
      @scene_generation = Window.scene_generation
    end

    def added?
      @added && @scene_generation == Window.scene_generation
    end

    # Make the visual draw the label after itself: the label is then always on
    # the visual, at the visual's depth, hidden and removed along with it.
    def draw_label_with_visual
      button = self
      @visual.define_singleton_method(:_render_scene) do
        super()
        button._draw_label
      end
    end

    # Wire the hover/pressed tint state machine. `:auto` lightens for hover
    # and darkens for pressed; any other value is treated as an explicit color.
    # Pressed wins over hover when both apply (hovering+pressed). Drag-out
    # while held reverts to base; drag back in re-engages the press tint.
    def install_state_tint(hover_input, pressed_input,
                           hover_label_input, pressed_label_input)
      @base_color = map_color(@visual.color) { |c| Color.new(c) }
      @hover_color   = resolve_state_color(hover_input,   :lighten)
      @pressed_color = resolve_state_color(pressed_input, :darken)

      if @label
        @base_label_color    = Color.new(@label.color)
        @hover_label_color   = hover_label_input   ? Color.new(hover_label_input)   : nil
        @pressed_label_color = pressed_label_input ? Color.new(pressed_label_input) : nil
      end

      @is_hovering = false
      @is_pressed = false

      on(:hover)      { @is_hovering = true;  apply_state }
      on(:hover_out)  { @is_hovering = false; apply_state }
      on(:mouse_down) { @is_pressed = true;   apply_state }
      on(:mouse_up)   { @is_pressed = false;  apply_state }
    end

    # Resolve a state-color input into a concrete Color or Color::Set. `:auto`
    # derives from the base color via `lighten` or `darken` as the state
    # requires (per-vertex when the base is a gradient). An explicit input goes
    # through `Color.set`, so a single color or a 4-color gradient both work.
    def resolve_state_color(input, mode)
      return nil unless input
      return (mode == :lighten ? lighten(@base_color) : darken(@base_color)) if input == :auto

      Color.set(input)
    end

    # Recompute fill and label color from current (hover, pressed) state and
    # apply to the visual + label. Pressed-without-hovering shows the rest
    # color (drag-out), matching native UI conventions.
    def apply_state
      fill, label_col = current_state_colors
      @visual.color = fill
      @label.color = label_col if @label && label_col
    end

    def current_state_colors
      if @is_pressed && @is_hovering
        [@pressed_color || @hover_color || @base_color,
         @pressed_label_color || @hover_label_color || @base_label_color]
      elsif @is_hovering
        [@hover_color || @base_color, @hover_label_color || @base_label_color]
      else
        [@base_color, @base_label_color]
      end
    end

    # Center the label on the visual's bounding box. The box, not the
    # position: a `Circle` is anchored at its center and a `Quad` or `Polygon`
    # at its centroid, so `x`/`y` alone would put the label off the shape.
    def center_label
      left = @visual.respond_to?(:_bounding_box_left) ? @visual._bounding_box_left : @visual.x
      top  = @visual.respond_to?(:_bounding_box_top)  ? @visual._bounding_box_top  : @visual.y
      @label.x = left + (width - @label.width) / 2.0
      @label.y = top + (height - @label.height) / 2.0
    end

    # Lightened version of a color for the `:auto` hover tint. Maps per-vertex
    # when the base is a gradient, so the gradient is preserved and brightened.
    def lighten(color, amount = 0.15)
      map_color(color) do |c|
        Color.new([
          [c.r + amount, 1.0].min,
          [c.g + amount, 1.0].min,
          [c.b + amount, 1.0].min,
          c.a
        ])
      end
    end

    # Darkened version of a color for the `:auto` pressed tint. Maps per-vertex
    # when the base is a gradient, so the gradient is preserved and darkened.
    def darken(color, amount = 0.15)
      map_color(color) do |c|
        Color.new([
          [c.r - amount, 0.0].max,
          [c.g - amount, 0.0].max,
          [c.b - amount, 0.0].max,
          c.a
        ])
      end
    end

    # Apply a per-color transform to a single Color or to each color of a
    # Color::Set, returning the same kind. Lets the hover/pressed tint operate
    # on gradient fills as well as solid ones.
    def map_color(color)
      return yield(color) unless color.is_a?(Color::Set)

      Color::Set.new(color.map { |c| yield(c) })
    end
  end
end
