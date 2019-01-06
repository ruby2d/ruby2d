# Ruby2D::Circle

module Ruby2D
  class Circle
    include Renderable

    attr_accessor :x, :y, :radius, :sectors

    def initialize(opts = {})
      @x = opts[:x] || 25
      @y = opts[:y] || 25
      @z = opts[:z] || 0
      @radius = opts[:radius] || 25
      @sectors = opts[:sectors] || 20
      self.color = opts[:color] || 'white'
      self.opacity = opts[:opacity] if opts[:opacity]
      add
    end

    def contains?(x, y)
      Math.sqrt((x - @x)**2 + (y - @y)**2) <= @radius
    end

  end
end
