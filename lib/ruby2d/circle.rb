# Ruby2D::Circle

module Ruby2D
  class Circle
    include Renderable

    attr_accessor :x, :y, :radius, :sectors

    def initialize(opts = {})
      @x = opts[:x] || 25
      @y = opts[:y] || 25
      @z = opts[:z] || 0
      @radius = opts[:radius] || 50
      @sectors = opts[:sectors] || 30
      self.color = opts[:color] || 'white'
      self.opacity = opts[:opacity] if opts[:opacity]
      add
    end

    def contains?(x, y)
      Math.sqrt((x - @x)**2 + (y - @y)**2) <= @radius
    end

    def self.draw(opts = {})
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
