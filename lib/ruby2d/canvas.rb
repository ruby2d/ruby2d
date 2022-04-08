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
      self.color = opts[:color] || 'white'
      self.color.opacity = opts[:opacity] if opts[:opacity]
      @update = if opts[:update] == nil then true else opts[:update] end

      ext_create([@width, @height, @fill.r, @fill.g, @fill.b, @fill.a])  # sets @ext_pixel_data

      @texture = Texture.new(@ext_pixel_data, @width, @height)

      unless opts[:show] == false then add end
    end

    def draw_rectangle(x, y, w, h, r, g, b, a)
      ext_draw_rectangle([x, y, w, h, r, g, b, a])
      update_texture if @update
    end

    def draw_line(x1, y1, x2, y2, w, r, g, b, a)
      ext_draw_line([x1, y1, x2, y2, w, r, g, b, a])
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
