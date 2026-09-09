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

      # Fill tints go through the visual's `color`. An `Image` or `Canvas` has
      # a `tint` instead, and a visual-less button nothing at all.
      if (hover_input || pressed_input) && !@visual.respond_to?(:color=)
        what = @visual ? "a `#{@visual.class}` has no `color`" : 'a visual-less `Button` draws nothing'
        raise ArgumentError, "`hover_color`/`pressed_color` need a visual with a `color` to tint: #{what}"
      end

      if label
        @label = Text.new(label, size: label_size,
                          color: label_color || label_colour || 'white', add: false)
        draw_label_with_visual
        center_label
      end

      @hovering = false
      @pressed = []
      install_fill_tint(hover_input, pressed_input) if hover_input || pressed_input
      install_label_tint(hover_label_input, pressed_label_input) if hover_label_input || pressed_label_input
      install_state_handlers if @base_color || @base_label_color

      on(:click) { |e| on_click.call(e) } if on_click
    end

    # Remove the button: drop the visual (and with it the label) from the
    # scene and unregister from the interactive registry. A press or hover in
    # progress is cancelled, since the release or exit that would end it can
    # no longer reach the button.
    def remove
      @visual ? @visual.remove : mark_added(false)
      Window.unregister_interactive(self)
      reset_state
    end

    # Re-add the button after `remove`. Restores rendering and re-registers in
    # the interactive registry if any handlers are attached. A button that
    # was already added keeps its hover state: the cursor is still over it.
    def add
      newly = @visual ? @visual.add : !added?
      mark_added(true) unless @visual
      reset_state if newly
      Window.register_interactive(self) if interactive?
    end

    # The visual was removed directly, or the window cleared: the release or
    # exit that would end an interaction in progress can no longer reach the
    # button, so end it now.
    def _removed_from_scene
      reset_state
    end

    # Mark the button visible.
    def show
      @visual ? @visual.show : (@visible = true)
    end

    # Mark the button hidden. Like any hidden object it keeps receiving events.
    def hide
      @visual ? @visual.hide : (@visible = false)
    end

    def visible=(flag)
      flag ? show : hide
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

    # Alignment and padding belong to the visual, which resolves them when it
    # draws; these forward to it, and are no-ops on a visual-less button.
    def x_align=(sym)
      @visual.x_align = sym if @visual.respond_to?(:x_align=)
    end

    def y_align=(sym)
      @visual.y_align = sym if @visual.respond_to?(:y_align=)
    end

    def padding_top
      @visual.respond_to?(:padding_top) ? @visual.padding_top : nil
    end

    def padding_right
      @visual.respond_to?(:padding_right) ? @visual.padding_right : nil
    end

    def padding_bottom
      @visual.respond_to?(:padding_bottom) ? @visual.padding_bottom : nil
    end

    def padding_left
      @visual.respond_to?(:padding_left) ? @visual.padding_left : nil
    end

    def padding_top=(value)
      @visual.padding_top = value if @visual.respond_to?(:padding_top=)
    end

    def padding_right=(value)
      @visual.padding_right = value if @visual.respond_to?(:padding_right=)
    end

    def padding_bottom=(value)
      @visual.padding_bottom = value if @visual.respond_to?(:padding_bottom=)
    end

    def padding_left=(value)
      @visual.padding_left = value if @visual.respond_to?(:padding_left=)
    end

    # Set all four padding edges to the same value.
    def padding=(value)
      @visual.padding = value if @visual.respond_to?(:padding=)
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
    # updates the resting (base) color, derives the `:auto` tints from it
    # again, and re-applies the current state so the change survives the next
    # hover/press cycle; otherwise it sets the visual directly. Accepts a
    # single color or a gradient (`Color::Set`). A no-op on a button without a
    # colorable visual.
    def color=(c)
      return unless @visual.respond_to?(:color=)

      if @base_color
        @base_color = Color.set(c)
        @hover_color = resolve_state_color(@hover_input, :lighten)
        @pressed_color = resolve_state_color(@pressed_input, :darken)
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

    # Remember the fill tint inputs and resolve them against the base color.
    # `:auto` is kept as such so `color=` can derive it from a new base; an
    # explicit value is resolved once.
    def install_fill_tint(hover_input, pressed_input)
      @base_color = map_color(@visual.color) { |c| Color.new(c) }
      @hover_input = hover_input
      @pressed_input = pressed_input
      @hover_color   = resolve_state_color(hover_input,   :lighten)
      @pressed_color = resolve_state_color(pressed_input, :darken)
    end

    def install_label_tint(hover_label_input, pressed_label_input)
      @base_label_color    = Color.new(@label.color)
      @hover_label_color   = hover_label_input   ? Color.new(hover_label_input)   : nil
      @pressed_label_color = pressed_label_input ? Color.new(pressed_label_input) : nil
    end

    # Wire the hover/pressed state machine that the tints follow. Pressed wins
    # over hover when both apply (hovering+pressed). Drag-out while held
    # reverts to base; drag back in re-engages the press tint. Each mouse
    # button is tracked on its own, so with two held the tint stays until the
    # last release. The window brings hover up to date before a press, so a
    # button that appeared under a resting cursor tints on the first press.
    def install_state_handlers
      on(:hover)      { @hovering = true;  apply_state }
      on(:hover_out)  { @hovering = false; apply_state }
      on(:mouse_down) { |e| @pressed << e.button unless @pressed.include?(e.button); apply_state }
      on(:mouse_up)   { |e| @pressed.delete(e.button); apply_state }
    end

    # Forget any hover or press in progress and show the resting colors.
    def reset_state
      @hovering = false
      @pressed.clear
      apply_state
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

    # Recompute fill and label color from the current (hovering, pressed)
    # state and apply whichever tints are configured. Pressed-without-hovering
    # shows the rest color (drag-out), matching native UI conventions.
    def apply_state
      @visual.color = state_color(@base_color, @hover_color, @pressed_color) if @base_color
      return unless @base_label_color

      @label.color = state_color(@base_label_color, @hover_label_color, @pressed_label_color)
    end

    def state_color(base, hover, pressed)
      if @hovering && !@pressed.empty?
        pressed || hover || base
      elsif @hovering
        hover || base
      else
        base
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
