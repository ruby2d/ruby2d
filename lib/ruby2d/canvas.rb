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
    
    # Clear the entire canvas, replacing every pixel with fill colour without blending.
    # @param [Color] fill_color 
    def clear(fill_color = nil)
      color = fill_color || @fill
      ext_clear([color.r, color.g, color.b, color.a])
      update_texture if @update
    end

    # Draw a filled triangle with a single colour or per-vertex colour blending.
    # @param [Numeric] x1
    # @param [Numeric] y1
    # @param [Numeric] x2
    # @param [Numeric] y2
    # @param [Numeric] x3
    # @param [Numeric] y3
    # @param [Color, Color::Set] color (or +colour+) Set one or per-vertex colour
    def fill_triangle(x1:, y1:, x2:, y2:, x3:, y3:, color: nil, colour:nil)
      clr = color || colour
      if clr.is_a? Color::Set
        c1 = clr[0]
        c2 = clr[1] || c1
        c3 = clr[2] || c2
      else
        c1 = c2 = c3 = (clr.is_a?(Color) ? clr : Color.new(clr))
      end
      ext_fill_triangle([
        x1, y1, c1.r, c1.g, c1.b, c1.a,
        x2, y2, c2.r, c2.g, c2.b, c2.a,
        x3, y3, c3.r, c3.g, c3.b, c3.a
      ])
      update_texture if @update
    end

    # Draw a filled quad(rilateral) with a single colour or per-vertex colour blending.
    # @param [Numeric] x1
    # @param [Numeric] y1
    # @param [Numeric] x2
    # @param [Numeric] y2
    # @param [Numeric] x3
    # @param [Numeric] y3
    # @param [Numeric] x4
    # @param [Numeric] y4
    # @param [Color, Color::Set] color (or +colour+) Set one or per-vertex colour
    def fill_quad(x1:, y1:, x2:, y2:, x3:, y3:, x4:, y4:, color: nil, colour:nil)
      clr = color || colour
      if clr.is_a? Color::Set
        c1 = clr[0]
        c2 = clr[1] || c1
        c3 = clr[2] || c2
        c4 = clr[3] || c3
      else
        c1 = c2 = c3 = c4 = (clr.is_a?(Color) ? clr : Color.new(clr))
      end
      ext_fill_quad([
        x1, y1, c1.r, c1.g, c1.b, c1.a,
        x2, y2, c2.r, c2.g, c2.b, c2.a,
        x3, y3, c3.r, c3.g, c3.b, c3.a,
        x4, y4, c4.r, c4.g, c4.b, c4.a
      ])
      update_texture if @update
    end

    # Draw a circle.
    # @param [Numeric] x Centre
    # @param [Numeric] y Centre
    # @param [Numeric] radius
    # @param [Numeric] sectors The number of segments to subdivide the circumference.
    # @param [Numeric] width The thickness of the circle in pixels
    # @param [Color] color (or +colour+) The fill colour
    def draw_circle(x:, y:, radius:, sectors: 30, width: 1, color: nil, colour: nil)
      clr = color || colour
      clr = Color.new(clr) unless clr.is_a? Color
      ext_draw_circle([
        x, y, radius, sectors, width,
        clr.r, clr.g, clr.b, clr.a
      ])
      update_texture if @update
    end

    # Draw a filled circle.
    # @param [Numeric] x Centre
    # @param [Numeric] y Centre
    # @param [Numeric] radius
    # @param [Numeric] sectors The number of segments to subdivide the circumference.
    # @param [Color] color (or +colour+) The fill colour
    def fill_circle(x:, y:, radius:, sectors: 30, color: nil, colour: nil)
      clr = color || colour
      clr = Color.new(clr) unless clr.is_a? Color
      ext_fill_circle([
        x, y, radius, sectors,
        clr.r, clr.g, clr.b, clr.a
      ])
      update_texture if @update
    end

    # Draw a filled rectangle.
    # @param [Numeric] x
    # @param [Numeric] y
    # @param [Numeric] width
    # @param [Numeric] height
    # @param [Color] color (or +colour+) The fill colour
    def fill_rectangle(x:, y:, width:, height:, color: nil, colour: nil)
      clr = color || colour
      clr = Color.new(clr) unless clr.is_a? Color
      ext_fill_rectangle([
        x, y, width, height,
        clr.r, clr.g, clr.b, clr.a
      ])
      update_texture if @update
    end

    # Draw an outline of a rectangle
    # @param [Numeric] x
    # @param [Numeric] y
    # @param [Numeric] width
    # @param [Numeric] height
    # @param [Color] color (or +colour+) The line colour
    def draw_rectangle(x:, y:, width:, height:, color: nil, colour: nil)
      clr = color || colour
      clr = Color.new(clr) unless clr.is_a? Color
      ext_draw_rectangle([
        x, y, width, height,
        clr.r, clr.g, clr.b, clr.a
      ])
      update_texture if @update
    end

    # Draw a straight line between two points
    # @param [Numeric] x1
    # @param [Numeric] y1
    # @param [Numeric] x2
    # @param [Numeric] y2
    # @param [Numeric] width The line's thickness in pixels; defaults to 1.
    # @param [Color] color (or +colour+) The line colour
    def draw_line(x1:, y1:, x2:, y2:, width: 1, color: nil, colour: nil)
      clr = color || colour
      clr = Color.new(clr) unless clr.is_a? Color
      ext_draw_line([
        x1, y1, x2, y2, width,
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
