# circle.rb

module Ruby2D
  class Circle
    include Renderable

    attr_reader :color
    attr_accessor :x, :y, :radius, :sectors

    def initialize(opts = {})
      @x         = opts[:x]       || 25
      @y         = opts[:y]       || 25
      @radius    = opts[:radius]  || 25
      @sectors   = opts[:sectors] || 20
      @z         = opts[:z]       || 0
      self.color = opts[:color]   || 'white'
      add
    end

    def color=(c)
      @color = Color.from(c)
    end

    def contains?(x, y)
      Math.sqrt((x - @x)**2 + (y - @y)**2) <= @radius
    end
  end
end
