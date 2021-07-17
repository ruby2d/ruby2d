# Ruby2D::Entity

module Ruby2D
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
