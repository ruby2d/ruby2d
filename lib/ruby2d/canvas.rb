# Ruby2D::Canvas

module Ruby2D
  class Canvas
    include Renderable

    def initialize(opts = {})
      @x = opts[:x] || 0
      @y = opts[:y] || 0
      @z = opts[:z] || 0
      @width = opts[:width]
      @height = opts[:height]
      @rotate = opts[:rotate] || 0
      @fill = Color.new(opts[:fill] || [0, 0, 0, 0])
      self.color = opts[:color] || opts[:colour] || 'white'
      self.color.opacity = opts[:opacity] if opts[:opacity]
      @update = if opts[:update] == nil then true else opts[:update] end

      ext_create([@width, @height, @fill.r, @fill.g, @fill.b, @fill.a])  # sets @ext_pixel_data
      @texture = Texture.new(@ext_pixel_data, @width, @height)
      unless opts[:show] == false then add end
    end
    
    # Draw a filled rectangle.
    def fill_rectangle(opts = {})
      clr = Color.new(opts[:color] || opts[:colour])
      ext_fill_rectangle([
        opts[:x], opts[:y], opts[:width], opts[:height],
        clr.r, clr.g, clr.b, clr.a
      ])
      update_texture if @update
    end

    # Draw an outline of a rectangle
    def draw_rectangle(opts = {})
      clr = Color.new(opts[:color] || opts[:colour])
      ext_draw_rectangle([
        opts[:x], opts[:y], opts[:width], opts[:height],
        clr.r, clr.g, clr.b, clr.a
      ])
      update_texture if @update
    end

    # Draw a straight line
    def draw_line(opts = {})
      clr = Color.new(opts[:color] || opts[:colour])
      ext_draw_line([
        opts[:x1], opts[:y1], opts[:x2], opts[:y2], opts[:width],
        clr.r, clr.g, clr.b, clr.a
      ])
      update_texture if @update
    end

    def update
      update_texture
    end

    private

    def update_texture
      @texture.delete
      @texture = Texture.new(@ext_pixel_data, @width, @height)
    end

    def render(x: @x, y: @y, width: @width, height: @height, color: @color, rotate: @rotate)
      vertices = Vertices.new(x, y, width, height, rotate)

      @texture.draw(
        vertices.coordinates, vertices.texture_coordinates, color
      )
    end

  end
end
