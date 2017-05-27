# square.rb

module Ruby2D
  class Square < Rectangle

    attr_reader :size

    def initialize(opts = {})
      @type_id = 2
      @x = opts[:x] || 0
      @y = opts[:y] || 0
      @z = opts[:z] || 0
      @width = @height = @size = opts[:size] || 100

      self.color = opts[:color] || 'white'

      update_coords(@x, @y, @size, @size)

      add
    end

    def size=(s)
      self.width = self.height = @size = s
    end

    private :width=, :height=
  end
end
