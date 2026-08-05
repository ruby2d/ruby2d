# Ruby2D::Window::ObjectEventDispatch

module Ruby2D
  class Window
    # Per-object event dispatching for interactive renderables
    module ObjectEventDispatch
      # Initialize stores for object-level interaction state
      def init_object_event_stores
        @interactive_objects = []
        @hovered_object = nil
        @pressed_objects = {}
      end

      # Register an object as interactive (has event handlers)
      def register_interactive(object)
        return if @interactive_objects.include?(object)

        index = @interactive_objects.index { |obj| obj.z > object.z }
        if index
          @interactive_objects.insert(index, object)
        else
          @interactive_objects.push(object)
        end
      end

      # Unregister an object (no more event handlers)
      def unregister_interactive(object)
        @interactive_objects.delete(object)
        cleanup_interaction_state(object)
      end

      # Clear pressed/hover refs when an object is removed
      def cleanup_interaction_state(object)
        @hovered_object = nil if @hovered_object == object

        @pressed_objects.delete_if { |_btn, info| info[:object] == object }
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
        # allocate: the enumerator + pair-array sort below costs ~12µs per
        # event on wasm mruby even with zero interactive objects.
        objs = @interactive_objects
        size = objs.size
        return nil if size.zero?

        # @interactive_objects is kept sorted by z at registration, but an
        # object's z (or its wrapped visual's z) can change at runtime. Verify
        # the order in one allocation-free pass; while it holds (nearly every
        # frame), hit-test top-down by iterating backwards in place — among
        # equal-z objects the highest index (most recently registered) is
        # checked first, matching the stable sort in the fallback.
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

        # A runtime z change broke the registration order: re-establish it with
        # a sort stable on the array's current index, preserving registration
        # order among equal-z objects (most recently registered stays topmost).
        objs.each_with_index.sort_by { |obj, idx| [obj.z, idx] }.reverse_each do |obj, _idx|
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
      # (and `:click` follows).
      def dispatch_object_mouse_up(button, x, y)
        obj = topmost_interactive_at(x, y)
        press = @pressed_objects.delete(button)
        event = MouseEvent.new(:up, button, nil, x, y, nil, nil)

        obj._fire_event(:mouse_up, event) if obj
        if press && press[:object] != obj
          press[:object]._fire_event(:mouse_up, event)
        end

        if press && obj == press[:object]
          obj._fire_event(:click, MouseEvent.new(:click, button, nil, x, y, nil, nil))
        end
      end

      # Dispatch mouse move: update hover state, handle drag
      def dispatch_object_mouse_move(x, y, delta_x, delta_y)
        obj = topmost_interactive_at(x, y)

        # Update hover state
        if obj != @hovered_object
          if @hovered_object
            @hovered_object._fire_event(:hover_out, MouseEvent.new(:hover_out, nil, nil, x, y, nil, nil))
          end
          if obj
            obj._fire_event(:hover, MouseEvent.new(:hover, nil, nil, x, y, nil, nil))
          end
          @hovered_object = obj
        end

        # Handle drag for each pressed button
        @pressed_objects.each do |button, info|
          drag_obj = info[:object]
          next unless drag_obj.interactive?(:drag)

          drag_obj._fire_event(:drag, MouseEvent.new(:drag, button, nil, x, y, delta_x, delta_y))
        end
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
    end
  end
end
