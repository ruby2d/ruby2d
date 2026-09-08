# Ruby2D::Interactive

module Ruby2D
  # Per-object event handling for objects that participate in Window's
  # interactive registry. Provides `on` / `off` / `interactive?` and the
  # `_fire_event` dispatch entry point. Mixed into `Renderable` and `Button`.
  #
  # Including objects must expose `x`, `y`, `z`, `width`, `height`, and
  # `contains?(x, y)` so `Window::ObjectEventDispatch` can hit-test them.
  module Interactive
    # Per-object events that take a value matcher (button) in the kwarg form.
    # `:hover`, `:hover_out`, and `:mouse_scroll` carry no matchable field.
    OBJECT_EVENT_FILTER_PREDICATES = {
      mouse_down: :button?, mouse_held: :button?, mouse_up: :button?,
      click: :button?, drag: :button?
    }.freeze

    # The full per-object event vocabulary: the filterable events above plus the
    # three that carry no matchable field. Derived from the predicates map so the
    # two can't drift, and mirrors what Window::ObjectEventDispatch fires.
    OBJECT_EVENTS = (OBJECT_EVENT_FILTER_PREDICATES.keys + %i[hover hover_out mouse_scroll]).freeze

    # Register a per-object event handler. Two forms:
    #
    #   obj.on(:click) { |event| ... }
    #   obj.on(click: :left) { ... }                   # filtered
    #   obj.on(click: [:left, :right]) { ... }         # array → match any
    #   obj.on(mouse_down: :left, click: :left) { ... }  # multi-event
    def on(event = nil, **filters, &proc)
      raise Error, '`on` requires a block' unless proc

      handlers =
        if event.is_a?(Symbol) && filters.empty?
          raise Error, "`#{event}` is not a valid object event" unless OBJECT_EVENTS.include?(event)

          [[event, proc]]
        elsif event.nil? && !filters.empty?
          # Build every wrapper before installing any handler, so a bad filter
          # later in the list raises without leaving the earlier ones installed.
          filters.map { |type, matcher| [type, build_filter_wrapper(type, matcher, proc)] }
        else
          raise Error, '`on` requires either an event symbol or event filters'
        end

      descriptors = handlers.map { |type, handler| install_object_event_handler(type, handler) }
      register_with_window
      descriptors.size == 1 ? descriptors.first : descriptors
    end

    # Remove a per-object event handler (or several, given an array).
    def off(descriptor)
      return descriptor.each { |d| off(d) } if descriptor.is_a?(Array)

      unless descriptor.is_a?(Window::ObjectEventDescriptor)
        raise Error,
              "Cannot remove event handler: expected a descriptor returned by `on`, got #{descriptor.inspect}"
      end

      # Handler IDs are per object, so a descriptor from another object would
      # silently name an unrelated handler here.
      unless descriptor.object.equal?(self)
        raise Error,
              'Cannot remove event handler: the descriptor belongs to another object ' \
              "(#{descriptor.object.class}); call `off` on that object, or `Window.off`"
      end

      return unless @_object_events

      handlers = @_object_events[descriptor.type]
      return unless handlers

      handlers.delete(descriptor.id)
      @_object_events.delete(descriptor.type) if handlers.empty?

      Window.unregister_interactive(self) unless interactive?
    end

    # Check if this object has any event handlers
    def interactive?(event = nil)
      return false unless @_object_events

      if event
        @_object_events.key?(event) && !@_object_events[event].empty?
      else
        @_object_events.any? { |_type, handlers| !handlers.empty? }
      end
    end

    # Dispatch an event to stored handlers (called by Window)
    def _fire_event(type, event)
      return unless @_object_events

      handlers = @_object_events[type]
      return unless handlers

      # Snapshot the values: a handler may register another handler for the same
      # event type mid-dispatch, which would otherwise mutate the hash we're
      # iterating ("can't add a new key into hash during iteration"). With more
      # than one handler each gets its own copy of the event, so one mutating a
      # field can't change what the next handler (or its filter) sees — the
      # same isolation window-level handlers have. The single-handler case
      # passes the event through untouched to avoid the allocation.
      procs = handlers.values
      return procs.first.call(event) if procs.size == 1

      procs.each { |proc| proc.call(event.dup) }
    end

    # The scene-graph member drawn for this object when it isn't one itself,
    # so hit-testing among equal z can follow draw order. Renderables are
    # their own; Button answers with its visual.
    def _scene_visual
      nil
    end

    private

    # Wrap a user proc with a button matcher. Validates the event type and
    # every button name up front, so a bad name fails here rather than the
    # first time the user clicks.
    def build_filter_wrapper(type, matcher, proc)
      predicate = OBJECT_EVENT_FILTER_PREDICATES[type] or
        raise Error, "`#{type}` does not support filtering with `on event: value`"
      values = Array(matcher)
      values.each { |v| Mouse.validate!(v) }
      ->(e) { proc.call(e) if values.any? { |v| e.send(predicate, v) } }
    end

    def install_object_event_handler(event, proc)
      @_object_events ||= {}
      @_object_events[event] ||= {}
      id = (@_object_event_key = (@_object_event_key || 0) + 1)
      @_object_events[event][id] = proc
      Window::ObjectEventDescriptor.new(self, event, id)
    end

    # Join the window's interactive registry once handlers exist. Renderables
    # always register; whether one is hit-tested is decided by scene-graph
    # membership at dispatch time. Button overrides this to register only
    # while added, since registry membership is what makes it hit-testable.
    def register_with_window
      Window.register_interactive(self)
    end
  end
end
