# frozen_string_literal: true

# Ruby2D::Quad

module Ruby2D
  # A quadrilateral based on four points in clockwise order starting at the top left.
  class Quad
    include Renderable

    # Coordinates in clockwise order, starting at top left:
    # x1,y1 == top left
    # x2,y2 == top right
    # x3,y3 == bottom right
    # x4,y4 == bottom left
    attr_accessor :x1, :y1,
                  :x2, :y2,
                  :x3, :y3,
                  :x4, :y4

    # Create an quadrilateral
    # @param [Numeric] x1
    # @param [Numeric] y1
    # @param [Numeric] x2
    # @param [Numeric] y2
    # @param [Numeric] x3
    # @param [Numeric] y3
    # @param [Numeric] x4
    # @param [Numeric] y4
    # @param [Numeric] z
    # @param [String, Array] color A single colour or an array of exactly 4 colours
    # @param [Numeric] opacity Opacity of the image when rendering
    # @raise [ArgumentError] if an array of colours does not have 4 entries
    def initialize(x1: 0, y1: 0, x2: 100, y2: 0, x3: 100, y3: 100, x4: 0, y4: 100,
                   z: 0, color: nil, colour: nil, opacity: nil)
      @x1 = x1
      @y1 = y1
      @x2 = x2
      @y2 = y2
      @x3 = x3
      @y3 = y3
      @x4 = x4
      @y4 = y4
      @z  = z
      self.color = color || colour || 'white'
      self.color.opacity = opacity unless opacity.nil?
      add
    end

    # Change the colour of the line
    # @param [String, Array] color A single colour or an array of exactly 4 colours
    # @raise [ArgumentError] if an array of colours does not have 4 entries
    def color=(color)
      # convert to Color or Color::Set
      color = Color.set(color)

      # require 4 colours if multiple colours provided
      if color.is_a?(Color::Set) && color.length != 4
        raise ArgumentError,
              "`#{self.class}` requires 4 colors, one for each vertex. #{color.length} were given."
      end

      @color = color # converted above
      invalidate_color_components
    end

    # The logic is the same as for a triangle
    # See triangle.rb for reference
    def contains?(x, y)
      self_area = triangle_area(@x1, @y1, @x2, @y2, @x3, @y3) +
                  triangle_area(@x1, @y1, @x3, @y3, @x4, @y4)

      questioned_area = triangle_area(@x1, @y1, @x2, @y2, x, y) +
                        triangle_area(@x2, @y2, @x3, @y3, x, y) +
                        triangle_area(@x3, @y3, @x4, @y4, x, y) +
                        triangle_area(@x4, @y4, @x1, @y1, x, y)

      questioned_area <= self_area
    end

    # Draw a line without creating a Line
    # @param [Numeric] x1
    # @param [Numeric] y1
    # @param [Numeric] x2
    # @param [Numeric] y2
    # @param [Numeric] x3
    # @param [Numeric] y3
    # @param [Numeric] x4
    # @param [Numeric] y4
    # @param color [Array<Array<float,float,float,float>>] An array of 4 array of colour components
    #                                       (e.g. [[1.0, 0, 0, 1.0], ...])
    def self.draw(x1:, y1:, x2:, y2:, x3:, y3:, x4:, y4:, color:)
      Window.render_ready_check
      ext_draw([
                 x1, y1, *color[0], # splat the colour components
                 x2, y2, *color[1],
                 x3, y3, *color[2],
                 x4, y4, *color[3]
               ])
    end

    private

    def render
      color_comp_arrays = color_components
      self.class.ext_draw([
                            @x1, @y1, *color_comp_arrays[0], # splat the colour components
                            @x2, @y2, *color_comp_arrays[1],
                            @x3, @y3, *color_comp_arrays[2],
                            @x4, @y4, *color_comp_arrays[3]
                          ])
    end

    def triangle_area(x1, y1, x2, y2, x3, y3)
      (x1 * y2 + x2 * y3 + x3 * y1 - x3 * y2 - x1 * y3 - x2 * y1).abs / 2
    end

    # Return colours as a memoized array of 4 x colour component arrays
    def color_components
      check_if_opacity_changed
      @color_components ||= if @color.is_a? Color::Set
                              # Extract colour component arrays; see +def color=+ where colour set
                              # size is enforced
                              [
                                @color[0].to_a, @color[1].to_a, @color[2].to_a, @color[3].to_a
                              ]
                            else
                              # All vertex colours are the same
                              c_a = @color.to_a
                              [
                                c_a, c_a, c_a, c_a
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
