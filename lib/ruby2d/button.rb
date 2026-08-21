# Ruby2D::Button

module Ruby2D
  # A clickable region with optional visual and label. Button is itself the
  # interactive entity: it registers directly with `Window`'s interactive
  # registry and holds its own event handlers. The optional `@visual` is a
  # rendering concern, never an event-routing one.
  class Button
    include Interactive

    attr_reader :label_text

    # Create a button. Three forms:
    #
    # Self-rendered:
    #   Button.new(x:, y:, width:, height:, label:, color:, hover_color:) { ... }
    #
    # Wrap a custom visual (any shape responding to `x`, `y`, and `contains?`):
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
        @visual = visual
        @owns_visual = false
        @x = visual.x
        @y = visual.y
        @z = visual.respond_to?(:z) ? visual.z : 0
        @width = visual.respond_to?(:width) ? visual.width : 0
        @height = visual.respond_to?(:height) ? visual.height : 0
      else
        @x = x.is_a?(Symbol) ? 0 : x
        @y = y.is_a?(Symbol) ? 0 : y
        @z = z
        @width = width
        @height = height
        if label || base_color_input || stroke_input
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
          @owns_visual = true
        else
          # Visual-less: no rendering, no @visual. Just an interactive region.
          @visual = nil
          @owns_visual = false
        end
      end

      if label
        @label = Text.new(label, x: 0, y: 0, z: @z + 1,
                          size: label_size, color: label_color || label_colour || 'white',
                          add: add, visible: visible)
        center_label
      end

      if @visual && (hover_input || pressed_input || hover_label_input || pressed_label_input)
        install_state_tint(hover_input, pressed_input,
                           hover_label_input, pressed_label_input)
      end
      hook_visual_alignment if @owns_visual

      # `self.on`, not `on`: the receiver is explicit because Spinel resolves
      # an implicit-self `on` here to the DSL's top-level `on` rather than
      # `Interactive#on` (see spinel/issues/54).
      self.on(:click) { |e| on_click.call(e) } if on_click

      # Honor `add: false` for interactivity, not just rendering. Registering the
      # click/tint handlers above auto-added this Button to the interactive
      # registry; without this an `add: false` Button would keep swallowing
      # clicks while its un-added visual draws nothing. Only touches the registry
      # when handlers exist, so a handler-less Button doesn't force a window into
      # being. `add`/`remove` manage registration thereafter.
      Window.unregister_interactive(self) if interactive? && !add
    end

    # Remove the button: drop visual + label from the render list and
    # unregister Button from the interactive registry.
    def remove
      @visual.remove if @visual
      @label.remove if @label
      Window.unregister_interactive(self)
    end

    # Re-add the button after `remove`. Restores rendering and re-registers
    # in the interactive registry if any handlers are attached.
    def add
      @visual.add if @visual
      @label.add if @label
      Window.register_interactive(self) if interactive?
    end

    # Mark the button visible (cascades to visual and label).
    def show
      @visual.show if @visual
      @label.show if @label
    end

    # Mark the button hidden (cascades to visual and label).
    def hide
      @visual.hide if @visual
      @label.hide if @label
    end

    # Whether the button is currently visible.
    def visible?
      @visual ? @visual.visible? : true
    end

    # Hit-test the button. Wrapped visuals delegate so non-rectangular shapes
    # (Circle, Polygon, …) test against their actual geometry.
    def contains?(x, y)
      return @visual.contains?(x, y) if @visual && !@owns_visual

      x >= @x && x <= (@x + @width) && y >= @y && y <= (@y + @height)
    end

    def x
      @owns_visual ? @x : (@visual ? @visual.x : @x)
    end

    # Set the x position. Pass a symbol (`:left`, `:center`, `:right`) to
    # set alignment intent on the underlying visual (owned visuals only).
    def x=(x)
      return self.x_align = x if x.is_a?(Symbol)

      @x = x
      # Move the visual too — owned or wrapped — so the visual, the (delegated)
      # hit region, the getter, and the label all move together.
      @visual.x = x if @visual.respond_to?(:x=)
      center_label if @label
    end

    def y
      @owns_visual ? @y : (@visual ? @visual.y : @y)
    end

    # Set the y position. Pass a symbol (`:top`, `:center`, `:bottom`) to
    # set alignment intent on the underlying visual (owned visuals only).
    def y=(y)
      return self.y_align = y if y.is_a?(Symbol)

      @y = y
      # Move the visual too — owned or wrapped — so the visual, the (delegated)
      # hit region, the getter, and the label all move together.
      @visual.y = y if @visual.respond_to?(:y=)
      center_label if @label
    end

    def z
      @owns_visual ? @z : (@visual && @visual.respond_to?(:z) ? @visual.z : @z)
    end

    def width
      @owns_visual ? @width : (@visual && @visual.respond_to?(:width) ? @visual.width : @width)
    end

    def height
      @owns_visual ? @height : (@visual && @visual.respond_to?(:height) ? @visual.height : @height)
    end

    # Horizontal alignment intent of the underlying visual, or nil.
    def x_align
      @visual.respond_to?(:x_align) ? @visual.x_align : nil
    end

    # Vertical alignment intent of the underlying visual, or nil.
    def y_align
      @visual.respond_to?(:y_align) ? @visual.y_align : nil
    end

    # Set alignment intent on the underlying visual (owned visuals only), so
    # these mirror the getters above rather than writing a `@x_align` the
    # getters would never read. A wrapped visual is positioned by its owner,
    # so alignment there is the caller's to set on the visual itself.
    def x_align=(sym)
      @visual.x_align = sym if @owns_visual
    end

    def y_align=(sym)
      @visual.y_align = sym if @owns_visual
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

    private

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

      # Explicit receivers for the reason given at the `:click` registration
      self.on(:hover)      { @is_hovering = true;  apply_state }
      self.on(:hover_out)  { @is_hovering = false; apply_state }
      self.on(:mouse_down) { @is_pressed = true;   apply_state }
      self.on(:mouse_up)   { @is_pressed = false;  apply_state }
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

    # Center the label text within the button bounds. `@x`/`@y` is the visual's
    # anchor, which is the bounding-box top-left for most shapes but the *center*
    # for a wrapped Circle/Ellipse — so back out the anchor offset to find the
    # true top-left before centering.
    def center_label
      return unless @label

      ox, oy = visual_anchor_offset
      left = @x - ox
      top  = @y - oy
      @label.x = left + (@width - @label.width) / 2.0
      @label.y = top + (@height - @label.height) / 2.0
    end

    # Offset from the visual's bounding-box top-left to its `x`/`y` anchor.
    # Zero for top-left-anchored shapes (Rectangle, owned visual, visual-less);
    # the radius for a wrapped center-anchored Circle/Ellipse. Lets
    # `center_label` find the bounding box regardless of the visual's anchor.
    def visual_anchor_offset
      if @visual && !@owns_visual && @visual.respond_to?(:_alignment_anchor_dx, true)
        [@visual.send(:_alignment_anchor_dx), @visual.send(:_alignment_anchor_dy)]
      else
        [0, 0]
      end
    end

    # Wrap the visual's alignment resolver so that, when symbolic alignment
    # resolves to a numeric position at draw time, Button's stored `@x`/`@y`
    # follow and the label re-centers.
    def hook_visual_alignment
      return unless @visual.respond_to?(:_resolve_alignment)

      button = self
      @visual.define_singleton_method(:_resolve_alignment) do
        super()
        button.send(:_sync_from_visual)
      end
    end

    # Pull the visual's resolved position back into Button's own state and
    # re-center the label. Called after each alignment resolution.
    def _sync_from_visual
      @x = @visual.x
      @y = @visual.y
      center_label if @label
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
