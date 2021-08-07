# Ruby2D::Square

module Ruby2D
  class Square < Rectangle

    attr_reader :size

    def initialize(opts = {})
      @x = opts[:x] || 0
      @y = opts[:y] || 0
      @z = opts[:z] || 0
      @width = @height = @size = opts[:size] || 100
      self.color = opts[:color] || 'white'
      self.color.opacity = opts[:opacity] if opts[:opacity]
      update_coords(@x, @y, @size, @size)
      add
    end

    # Set the size of the square
    def size=(s)
      self.width = self.height = @size = s
    end

    def self.draw(opts = {})
      ext_draw([
        opts[:x]              , opts[:y]              , opts[:color][0][0], opts[:color][0][1], opts[:color][0][2], opts[:color][0][3],
        opts[:x] + opts[:size], opts[:y]              , opts[:color][1][0], opts[:color][1][1], opts[:color][1][2], opts[:color][1][3],
        opts[:x] + opts[:size], opts[:y] + opts[:size], opts[:color][2][0], opts[:color][2][1], opts[:color][2][2], opts[:color][2][3],
        opts[:x]              , opts[:y] + opts[:size], opts[:color][3][0], opts[:color][3][1], opts[:color][3][2], opts[:color][3][3]
      ])
    end

    # Make the inherited width and height attribute accessors private
    private :width=, :height=

  end
end
