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
      self.opacity = opts[:opacity] if opts[:opacity]
      update_coords(@x, @y, @size, @size)
      add
    end

    # Set the size of the square
    def size=(s)
      self.width = self.height = @size = s
    end


    def self.draw(x: 0, y: 0, z: 0, size: 100)

      @width = @height = @size = size || 100

      @x = opts[:x] || 0
      @y = opts[:y] || 0
      @z = opts[:z] || 0

      self.color = opts[:color] || 'white'
      self.opacity = opts[:opacity] if opts[:opacity]
      update_coords(@x, @y, @size, @size)

      ext_draw(x, y, c)
    end


    # Make the inherited width and height attribute accessors private
    private :width=, :height=

  end
end
