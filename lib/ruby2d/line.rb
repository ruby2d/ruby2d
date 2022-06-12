# frozen_string_literal: true

# Ruby2D::Line

module Ruby2D
  # A line between two points.
  class Line
    include Renderable

    attr_accessor :x1, :x2, :y1, :y2, :width

    # Create an Line
    # @param [Numeric] x1
    # @param [Numeric] y1
    # @param [Numeric] x2
    # @param [Numeric] y2
    # @param [Numeric] width The +width+ or thickness of the line
    # @param [Numeric] z
    # @param [String, Array] color A single colour or an array of exactly 4 colours
    # @param [Numeric] opacity Opacity of the image when rendering
    # @raise [ArgumentError] if an array of colours does not have 4 entries
    def initialize(x1: 0, y1: 0, x2: 100, y2: 100, z: 0,
                   width: 2, color: nil, colour: nil, opacity: nil)
      @x1 = x1
      @y1 = y1
      @x2 = x2
      @y2 = y2
      @z = z
      @width = width
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

    # Return the length of the line
    def length
      points_distance(@x1, @y1, @x2, @y2)
    end

    # Line contains a point if the point is closer than the length of line from
    # both ends and if the distance from point to line is smaller than half of
    # the width. For reference:
    #   https://en.wikipedia.org/wiki/Distance_from_a_point_to_a_line
    def contains?(x, y)
      line_len = length
      points_distance(@x1, @y1, x, y) <= line_len &&
        points_distance(@x2, @y2, x, y) <= line_len &&
        (((@y2 - @y1) * x - (@x2 - @x1) * y + @x2 * @y1 - @y2 * @x1).abs / line_len) <= 0.5 * @width
    end

    # Draw a line without creating a Line
    # @param [Numeric] x1
    # @param [Numeric] y1
    # @param [Numeric] x2
    # @param [Numeric] y2
    # @param [Numeric] width The +width+ or thickness of the line
    # @param [Array] colors An array or 4 arrays of colour components.
    def self.draw(x1:, y1:, x2:, y2:, width:, colors:)
      Window.render_ready_check

      ext_draw([
                 x1, y1, x2, y2, width,
                 # splat each colour's components
                 *colors[0], *colors[1], *colors[2], *colors[3]
               ])
    end

    private

    def render
      self.class.ext_draw([
                            @x1, @y1, @x2, @y2, @width,
                            # splat the colour components from helper
                            *color_components
                          ])
    end

    # Calculate the distance between two points
    def points_distance(x1, y1, x2, y2)
      Math.sqrt((x1 - x2).abs2 + (y1 - y2).abs2)
    end

    # Return colours as a memoized flattened array of 4 x colour components
    def color_components
      @color_components ||= if @color.is_a? Color::Set
                              # Splat the colours from the set; see +def color=+ where colour set
                              # size is enforced
                              [
                                *@color[0].to_a, *@color[1].to_a, *@color[2].to_a, *@color[3].to_a
                              ]
                            else
                              # All vertex colours are the same
                              c_a = @color.to_a
                              [
                                *c_a, *c_a, *c_a, *c_a
                              ]
                            end
    end

    # Invalidate the memoized colour components. Called when Line's colour is changed
    def invalidate_color_components
      @color_components = nil
    end
  end
end
