# Ruby2D::Window::ObjectEventDispatch

module Ruby2D
  class Window
    # Per-object event dispatching for interactive renderables
    module ObjectEventDispatch
      # Initialize stores for object-level interaction state
      def init_object_event_stores
        @interactive_objects = []
        @interactive_keys = {}
        @interactive_by_visual = {}
        @hovered_object = nil
        @pressed_objects = {}
      end

      # Register an object as interactive (has event handlers). The registry is
      # kept sorted by z, and among equal z by an order key: the scene insertion
      # order of the object, or of the visual drawn for it (a Button's), so
      # hit-testing agrees with draw order however handlers were attached; an
      # object with nothing in the scene gets the next order key instead.
      # `@interactive_keys` doubles as the registry's membership set, and
      # `@interactive_by_visual` lets `insert_object` re-key a Button when its
      # visual moves in the scene.
      def register_interactive(object)
        return if @interactive_keys.key?(object)

        visual = object._scene_visual
        @interactive_by_visual[visual] = object if visual
        # Keys are unique per object except for a Button and the visual it
        # stands in for, when that visual has handlers of its own. Doubling
        # leaves room for that one tie: the Button ranks just above its visual.
        key = (@object_set[object] || @object_set[visual] || next_scene_order) * 2
        key += 1 if visual
        @interactive_keys[object] = key
        z = object.z
        index = @interactive_objects.index do |obj|
          obj.z > z || (obj.z == z && @interactive_keys[obj] > key)
        end
        @interactive_objects.insert(index || @interactive_objects.size, object)
      end

      # Unregister an object (no more event handlers, or removed from the
      # scene), ending any interaction it was part of.
      def unregister_interactive(object)
        if @interactive_keys.delete(object)
          @interactive_objects.delete(object)
          visual = object._scene_visual
          @interactive_by_visual.delete(visual) if @interactive_by_visual[visual].equal?(object)
        end
        cleanup_interaction_state(object)
      end

      # Re-sort a registered object after its z or scene position changed.
      # Unlike unregister + register, hover and press state survive.
      def reregister_interactive(object)
        @interactive_objects.delete(object) if @interactive_keys.delete(object)
        register_interactive(object)
      end

      # Clear pressed/hover refs when an object is removed
      def cleanup_interaction_state(object)
        @hovered_object = nil if @hovered_object == object

        @pressed_objects.delete_if { |_btn, info| info[:object] == object }
      end

      # Whether an object may receive an object event right now: still in the
      # registry and, for a Renderable, still in the scene graph. Dispatch
      # re-checks this after every user callback, since a callback may remove
      # the object the next event was about to go to.
      def event_target?(object)
        return false unless @interactive_keys.key?(object)

        !object.is_a?(Renderable) || @object_set.key?(object)
      end

      # Find the topmost interactive object at the given coordinates. A
      # Renderable is only hit-tested while it's in the scene graph: a shape
      # built with `add: false` (or one that's been removed) has handlers but
      # is not drawn, so it must not silently swallow clicks or shadow visible
      # objects beneath it. Hidden objects (`visible = false`) stay in the
      # scene graph and keep receiving events, as documented. Button and other
      # self-managing interactives aren't scene-graph members by design (their
      # visual is) and register/unregister themselves, so they're exempt.
      def topmost_interactive_at(x, y)
        # This runs on every mouse-move event, so the common cases must not
        # allocate: a sort like the fallback's below costs ~12µs per event on
        # wasm mruby even with zero interactive objects.
        objs = @interactive_objects
        size = objs.size
        return nil if size.zero?

        # @interactive_objects is kept sorted by z and order key: registration
        # inserts in order and `Window#reorder` re-sorts on every `z` change.
        # Verify the z order in one allocation-free pass anyway, in case a z
        # changed behind the window's back; while it holds (nearly every
        # frame), hit-test top-down by iterating backwards in place — among
        # equal-z objects the highest index (latest order key, i.e. drawn on
        # top) is checked first. Otherwise fall back to re-sorting below.
        in_order = true
        i = 1
        while i < size
          if objs[i - 1].z > objs[i].z
            in_order = false
            break
          end
          i += 1
        end

        if in_order
          i = size - 1
          while i >= 0
            obj = objs[i]
            unless obj.is_a?(Renderable) && !@object_set.key?(obj)
              return obj if obj.contains?(x, y)
            end
            i -= 1
          end
          return nil
        end

        # A runtime z change broke the registration order: re-sort by z and
        # order key, keeping the sorted array as the registry so later events
        # take the fast path again, then hit-test top-down as above.
        objs = @interactive_objects = objs.sort_by { |obj| [obj.z, @interactive_keys[obj]] }
        objs.reverse_each do |obj|
          next if obj.is_a?(Renderable) && !@object_set.key?(obj)
          return obj if obj.contains?(x, y)
        end
        nil
      end

      # Dispatch mouse down to the topmost interactive object
      def dispatch_object_mouse_down(button, x, y)
        obj = topmost_interactive_at(x, y)
        return unless obj

        @pressed_objects[button] = { object: obj, x: x, y: y }
        obj._fire_event(:mouse_down, MouseEvent.new(:down, button, nil, x, y, nil, nil))
      end

      # Dispatch mouse up. `:mouse_up` mirrors `:mouse_down`: it fires on the
      # originally-pressed object regardless of release location, and also on
      # the topmost interactive object under the cursor at release. When the
      # press and release are on the same object, only one `:mouse_up` fires
      # (and `:click` follows). Each recipient is re-checked before its event,
      # since an earlier handler may have removed it or cleared the window.
      def dispatch_object_mouse_up(button, x, y)
        obj = topmost_interactive_at(x, y)
        press = @pressed_objects.delete(button)
        origin = press && press[:object]

        obj._fire_event(:mouse_up, MouseEvent.new(:up, button, nil, x, y, nil, nil)) if obj

        if origin && origin != obj && event_target?(origin)
          origin._fire_event(:mouse_up, MouseEvent.new(:up, button, nil, x, y, nil, nil))
        end

        if origin && origin == obj && event_target?(obj)
          obj._fire_event(:click, MouseEvent.new(:click, button, nil, x, y, nil, nil))
        end
      end

      # Dispatch mouse move: update hover state, handle drag
      def dispatch_object_mouse_move(x, y, delta_x, delta_y)
        obj = topmost_interactive_at(x, y)

        # Hover transition. Commit the new hovered object before running either
        # callback: a handler that removes its object clears `@hovered_object`
        # through `cleanup_interaction_state`, and assigning afterwards would
        # resurrect the reference removal just cleared.
        if obj != @hovered_object
          previous = @hovered_object
          @hovered_object = obj
          if previous
            previous._fire_event(:hover_out, MouseEvent.new(:hover_out, nil, nil, x, y, nil, nil))
          end
          if obj && @hovered_object.equal?(obj)
            obj._fire_event(:hover, MouseEvent.new(:hover, nil, nil, x, y, nil, nil))
          end
        end

        dispatch_object_drags(x, y, delta_x, delta_y)
      end

      # The cursor left the window: end the hover on whatever object had it,
      # since no in-window motion event will. Press captures are kept, so a
      # drag that leaves the window keeps reporting positions.
      def dispatch_object_mouse_leave(x, y)
        previous = @hovered_object
        return unless previous

        @hovered_object = nil
        previous._fire_event(:hover_out, MouseEvent.new(:hover_out, nil, nil, x, y, nil, nil))
      end

      # Dispatch mouse held to the object originally pressed with this button.
      # Stays on the originally pressed object even if the cursor drags off,
      # mirroring :drag's "this interaction belongs to this object" semantics.
      def dispatch_object_mouse_held(button, x, y)
        press = @pressed_objects[button]
        return unless press

        press[:object]._fire_event(:mouse_held, MouseEvent.new(:held, button, nil, x, y, nil, nil))
      end

      # Dispatch scroll to the topmost interactive object under the cursor.
      # Hit-tests fresh (like :mouse_down/:mouse_up) rather than reusing the
      # hover state, which mouse_move updates only on movement — scrolling
      # without first moving would otherwise target the wrong object or nothing.
      def dispatch_object_mouse_scroll(x, y, direction, delta_x, delta_y)
        obj = topmost_interactive_at(x, y)
        return unless obj

        obj._fire_event(:mouse_scroll, MouseEvent.new(:scroll, nil, direction, x, y, delta_x, delta_y))
      end

      private

      # Fire `:drag` on each captured object. Iterates a snapshot because a
      # callback may remove objects (deleting their captures) or clear the
      # window (replacing the store), and deleting from a Hash mid-iteration
      # behaves differently on CRuby and mruby. Each capture is re-validated
      # against the live store before its event goes out.
      def dispatch_object_drags(x, y, delta_x, delta_y)
        return if @pressed_objects.empty?

        @pressed_objects.to_a.each do |button, info|
          next unless @pressed_objects[button].equal?(info)

          drag_obj = info[:object]
          next unless drag_obj.interactive?(:drag)

          drag_obj._fire_event(:drag, MouseEvent.new(:drag, button, nil, x, y, delta_x, delta_y))
        end
      end
    end
  end
end
