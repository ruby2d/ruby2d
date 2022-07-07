# frozen_string_literal: true

# Ruby2D::Triangle

module Ruby2D
  # A triangle
  class Triangle
    include Renderable

    attr_accessor :x1, :y1,
                  :x2, :y2,
                  :x3, :y3
    attr_reader :color

    # Create a triangle
    # @param x1 [Numeric]
    # @param y1 [Numeric]
    # @param x2 [Numeric]
    # @param y2 [Numeric]
    # @param x3 [Numeric]
    # @param y3 [Numeric]
    # @param z [Numeric]
    # @param color [String, Array] A single colour or an array of exactly 3 colours
    # @param opacity [Numeric] Opacity of the image when rendering
    # @raise [ArgumentError] if an array of colours does not have 3 entries
    def initialize(x1: 50, y1: 0, x2: 100, y2: 100, x3: 0, y3: 100,
                   z: 0, color: 'white', colour: nil, opacity: nil)
      @x1 = x1
      @y1 = y1
      @x2 = x2
      @y2 = y2
      @x3 = x3
      @y3 = y3
      @z  = z
      self.color = color || colour
      self.color.opacity = opacity if opacity
      add
    end

    # Change the colour of the line
    # @param [String, Array] color A single colour or an array of exactly 3 colours
    # @raise [ArgumentError] if an array of colours does not have 3 entries
    def color=(color)
      # convert to Color or Color::Set
      color = Color.set(color)

      # require 3 colours if multiple colours provided
      if color.is_a?(Color::Set) && color.length != 3
        raise ArgumentError,
              "`#{self.class}` requires 3 colors, one for each vertex. #{color.length} were given."
      end

      @color = color # converted above
      invalidate_color_components
    end

    # A point is inside a triangle if the area of 3 triangles, constructed from
    # triangle sides and the given point, is equal to the area of triangle.
    def contains?(x, y)
      self_area = triangle_area(@x1, @y1, @x2, @y2, @x3, @y3)
      questioned_area =
        triangle_area(@x1, @y1, @x2, @y2, x, y) +
        triangle_area(@x2, @y2, @x3, @y3, x, y) +
        triangle_area(@x3, @y3, @x1, @y1, x, y)

      questioned_area <= self_area
    end

    # Draw a triangle
    # @param x1 [Numeric]
    # @param y1 [Numeric]
    # @param x2 [Numeric]
    # @param y2 [Numeric]
    # @param x3 [Numeric]
    # @param y3 [Numeric]
    # @param z [Numeric]
    # @param color [Array<Array<float,float,float,float>>] An array of 3 arrays of colour components
    #                                  (e.g. [[1.0, 0, 0, 1.0], ...])
    def self.draw(x1:, y1:, x2:, y2:, x3:, y3:, color:)
      Window.render_ready_check
      ext_draw([
                 x1, y1, *color[0], # splat the colour components
                 x2, y2, *color[1],
                 x3, y3, *color[2]
               ])
    end

    private

    def render
      color_comp_arrays = color_components
      self.class.ext_draw([
                            @x1, @y1, *color_comp_arrays[0], # splat the colour components
                            @x2, @y2, *color_comp_arrays[1],
                            @x3, @y3, *color_comp_arrays[2]
                          ])
    end

    def triangle_area(x1, y1, x2, y2, x3, y3)
      (x1 * y2 + x2 * y3 + x3 * y1 - x3 * y2 - x1 * y3 - x2 * y1).abs / 2
    end

    # Return colours as a memoized array of 3 x colour component arrays
    def color_components
      check_if_opacity_changed
      @color_components ||= if @color.is_a? Color::Set
                              # Extract colour component arrays; see +def color=+ where colour set
                              # size is enforced
                              [
                                @color[0].to_a, @color[1].to_a, @color[2].to_a
                              ]
                            else
                              # All vertex colours are the same
                              c_a = @color.to_a
                              [
                                c_a, c_a, c_a
                              ]
                            end
    end

    # Invalidate memoized colour components if opacity has been changed via +color=+
    def check_if_opacity_changed
      @color_components = nil if @color_components && @color_components.first[3] != @color.opacity
    end

    # Invalidate the memoized colour components. Called when Line's colour is changed
    def invalidate_color_components
      @color_components = nil
    end
  end
end
