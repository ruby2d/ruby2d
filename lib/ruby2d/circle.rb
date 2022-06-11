# frozen_string_literal: true

# Ruby2D::Circle

module Ruby2D
  #
  # Create a circle using +Circle.new+
  #
  class Circle
    include Renderable

    attr_accessor :x, :y, :radius, :sectors

    # Create a circle
    #
    # @param [Numeric] x
    # @param [Numeric] y
    # @param [Numeric] z
    # @param [Numeric] radius
    # @param [Numeric] sectors Smoothness of the circle is better when more +sectors+ are used.
    # @param [String | Color] color Or +colour+
    # @param [Float] opacity
    def initialize(x: 25, y: 25, z: 0, radius: 50, sectors: 30,
                   color: nil, colour: nil, opacity: nil)
      @x = x
      @y = y
      @z = z
      @radius = radius
      @sectors = sectors
      self.color = color || colour || 'white'
      self.color.opacity = opacity unless opacity.nil?
      add
    end

    # Check if the circle contains the point at +(x, y)+
    def contains?(x, y)
      Math.sqrt((x - @x)**2 + (y - @y)**2) <= @radius
    end

    def self.draw(opts = {})
      Window.render_ready_check

      ext_draw([
                 opts[:x], opts[:y], opts[:radius], opts[:sectors],
                 opts[:color][0], opts[:color][1], opts[:color][2], opts[:color][3]
               ])
    end

    private

    def render
      self.class.ext_draw([
                            @x, @y, @radius, @sectors,
                            @color.r, @color.g, @color.b, @color.a
                          ])
    end
  end
end
