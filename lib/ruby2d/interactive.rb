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
      if event.is_a?(Symbol) && filters.empty?
        raise Error, "`#{event}` is not a valid object event" unless OBJECT_EVENTS.include?(event)
        register_object_event_handler(event, proc)
      elsif event.nil? && !filters.empty?
        descriptors = filters.map do |type, matcher|
          predicate = OBJECT_EVENT_FILTER_PREDICATES[type] or
            raise Error, "`#{type}` does not support filtering with `on event: value`"
          values = Array(matcher)
          # Every filterable object event matches on a mouse button, so a bad
          # name fails here rather than the first time the user clicks.
          values.each { |v| Mouse.validate!(v) }
          wrapped = ->(e) { proc.call(e) if values.any? { |v| e.send(predicate, v) } }
          register_object_event_handler(type, wrapped)
        end
        descriptors.size == 1 ? descriptors.first : descriptors
      else
        raise Error, '`on` requires either an event symbol or event filters'
      end
    end

    # Remove a per-object event handler (or several, given an array).
    def off(descriptor)
      return descriptor.each { |d| off(d) } if descriptor.is_a?(Array)

      unless descriptor.is_a?(Window::ObjectEventDescriptor)
        raise Error,
              "Cannot remove event handler: expected a descriptor returned by `on`, got #{descriptor.inspect}"
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
      # iterating ("can't add a new key into hash during iteration").
      handlers.values.each { |proc| proc.call(event) }
    end

    private

    def register_object_event_handler(event, proc)
      @_object_events ||= {}
      @_object_events[event] ||= {}
      id = (@_object_event_key = (@_object_event_key || 0) + 1)
      @_object_events[event][id] = proc
      Window.register_interactive(self)
      Window::ObjectEventDescriptor.new(self, event, id)
    end
  end
end
