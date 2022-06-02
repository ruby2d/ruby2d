# frozen_string_literal: true

# Ruby2D::Entity

module Ruby2D
  # Any object that can be managed by a Ruby2D::Window must be an Entity
  class Entity
    # Add the entity to the window
    def add
      Window.add(self)
    end

    # Remove the entity from the window
    def remove
      Window.remove(self)
    end
  end
end
