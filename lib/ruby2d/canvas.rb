# frozen_string_literal: true

# Ruby2D::Canvas

module Ruby2D
  #
  # Canvas provides a surface into which you can draw using primitives and render the contents
  # as if it were an image/texture.
  #
  # @example A basic Canvas positioned at (0, 0)
  #   Canvas.new width: 320, height: 240
  # @example A Canvas that doesn't update texture on every draw method
  #   Canvas.new width: 320, height: 240, update: false
  #
  class Canvas
    include Renderable

    # Create a Canvas.
    #
    # @param [Numeric] width The +width+ of the canvas in pixels
    # @param [Numeric] height The +height+ of the canvas in pixels
    # @param [Numeric] x
    # @param [Numeric] y
    # @param [Numeric] z
    # @param [Numeric] rotate Angle, default is 0
    # @param [String] fill Colour to clear the canvas, respects transparency
    # @param [String] color or +colour+ Tint the texture when rendering
    # @param [Numeric] opacity Opacity of the texture when rendering
    # @param [true, false] update If +true+ updates the texture for every draw/fill call
    # @param [true, false] show If +true+ the canvas is added to +Window+ automatically.
    def initialize(width:, height:, x: 0, y: 0, z: 0, rotate: 0,
                   fill: [0, 0, 0, 0], color: nil, colour: nil, opacity: nil,
                   update: true, show: true)
      @x = x
      @y = y
      @z = z
      @width = width
      @height = height
      @rotate = rotate
      @fill = Color.new(fill)
      self.color = color || colour || 'white'
      color.opacity = opacity if opacity
      @update = update

      ext_create([@width, @height, @fill.r, @fill.g, @fill.b, @fill.a]) # sets @ext_pixel_data
      @texture = Texture.new(@ext_pixel_data, @width, @height)
      add if show
    end

    # Clear the entire canvas, replacing every pixel with fill colour without blending.
    # @param [Color] fill_color
    def clear(fill_color = @fill)
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
    def fill_triangle(x1:, y1:, x2:, y2:, x3:, y3:, color: nil, colour: nil)
      fill_polygon coordinates: [x1, y1, x2, y2, x3, y3], color: color || colour
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
    def fill_quad(x1:, y1:, x2:, y2:, x3:, y3:, x4:, y4:, color: nil, colour: nil)
      fill_polygon coordinates: [x1, y1, x2, y2, x3, y3, x4, y4], color: color || colour
    end

    # Draw a circle.
    # @param [Numeric] x Centre
    # @param [Numeric] y Centre
    # @param [Numeric] radius
    # @param [Numeric] sectors The number of segments to subdivide the circumference.
    # @param [Numeric] stroke_width The thickness of the circle in pixels
    # @param [Color] color (or +colour+) The fill colour
    def draw_circle(x:, y:, radius:, sectors: 30, stroke_width: 1, color: nil, colour: nil)
      clr = color || colour
      clr = Color.new(clr) unless clr.is_a? Color
      ext_draw_ellipse([
                         x, y, radius, radius, sectors, stroke_width,
                         clr.r, clr.g, clr.b, clr.a
                       ])
      update_texture if @update
    end

    # Draw an ellipse
    # @param [Numeric] x Centre
    # @param [Numeric] y Centre
    # @param [Numeric] xradius
    # @param [Numeric] yradius
    # @param [Numeric] sectors The number of segments to subdivide the circumference.
    # @param [Numeric] stroke_width The thickness of the circle in pixels
    # @param [Color] color (or +colour+) The fill colour
    def draw_ellipse(x:, y:, xradius:, yradius:, sectors: 30, stroke_width: 1, color: nil, colour: nil)
      clr = color || colour
      clr = Color.new(clr) unless clr.is_a? Color
      ext_draw_ellipse([
                         x, y, xradius, yradius, sectors, stroke_width,
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
      ext_fill_ellipse([
                         x, y, radius, radius, sectors,
                         clr.r, clr.g, clr.b, clr.a
                       ])
      update_texture if @update
    end

    # Draw a filled ellipse.
    # @param [Numeric] x Centre
    # @param [Numeric] y Centre
    # @param [Numeric] xradius
    # @param [Numeric] yradius
    # @param [Numeric] sectors The number of segments to subdivide the circumference.
    # @param [Color] color (or +colour+) The fill colour
    def fill_ellipse(x:, y:, xradius:, yradius:, sectors: 30, color: nil, colour: nil)
      clr = color || colour
      clr = Color.new(clr) unless clr.is_a? Color
      ext_fill_ellipse([
                         x, y, xradius, yradius, sectors,
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

    # Draw an outline of a triangle.
    # @param [Numeric] x1
    # @param [Numeric] y1
    # @param [Numeric] x2
    # @param [Numeric] y2
    # @param [Numeric] x3
    # @param [Numeric] y3
    # @param [Numeric] stroke_width The thickness of the rectangle in pixels
    # @param [Color] color (or +colour+) The line colour
    def draw_triangle(x1:, y1:, x2:, y2:, x3:, y3:, stroke_width: 1, color: nil, colour: nil)
      draw_polyline closed: true,
                    coordinates: [x1, y1, x2, y2, x3, y3],
                    color: color, colour: colour, stroke_width: stroke_width
    end

    # Draw an outline of a quad.
    # @param [Numeric] x1
    # @param [Numeric] y1
    # @param [Numeric] x2
    # @param [Numeric] y2
    # @param [Numeric] x3
    # @param [Numeric] y3
    # @param [Numeric] x4
    # @param [Numeric] y4
    # @param [Numeric] stroke_width The thickness of the rectangle in pixels
    # @param [Color] color (or +colour+) The line colour
    def draw_quad(x1:, y1:, x2:, y2:, x3:, y3:, x4:, y4:, stroke_width: 1, color: nil, colour: nil)
      draw_polyline closed: true,
                    coordinates: [x1, y1, x2, y2, x3, y3, x4, y4],
                    color: color, colour: colour, stroke_width: stroke_width
    end

    # Draw an outline of a rectangle
    # @param [Numeric] x
    # @param [Numeric] y
    # @param [Numeric] width
    # @param [Numeric] height
    # @param [Numeric] stroke_width The thickness of the rectangle in pixels
    # @param [Color] color (or +colour+) The line colour
    def draw_rectangle(x:, y:, width:, height:, stroke_width: 1, color: nil, colour: nil)
      clr = color || colour
      clr = Color.new(clr) unless clr.is_a? Color
      ext_draw_rectangle([
                           x, y, width, height, stroke_width,
                           clr.r, clr.g, clr.b, clr.a
                         ])
      update_texture if @update
    end

    # Draw a straight line between two points
    # @param [Numeric] x1
    # @param [Numeric] y1
    # @param [Numeric] x2
    # @param [Numeric] y2
    # @param [Numeric] stroke_width The line's thickness in pixels; defaults to 1.
    # @param [Color] color (or +colour+) The line colour
    def draw_line(x1:, y1:, x2:, y2:, stroke_width: 1, color: nil, colour: nil)
      clr = color || colour
      clr = Color.new(clr) unless clr.is_a? Color
      ext_draw_line([
                      x1, y1, x2, y2, stroke_width,
                      clr.r, clr.g, clr.b, clr.a
                    ])
      update_texture if @update
    end

    # Draw a poly-line between N points.
    # @param [Array] coordinates An array of numbers x1, y1, x2, y2 ... with at least three coordinates (6 values)
    # @param [Numeric] stroke_width The line's thickness in pixels; defaults to 1.
    # @param [Color] color (or +colour+) The line colour
    # @param [Boolean] closed Use +true+ to draw this as a closed shape
    def draw_polyline(coordinates:, stroke_width: 1, color: nil, colour: nil, closed: false)
      return if coordinates.nil? || coordinates.count < 6

      clr = color || colour
      clr = Color.new(clr) unless clr.is_a? Color
      config = [stroke_width, clr.r, clr.g, clr.b, clr.a]
      if closed
        ext_draw_polygon(config, coordinates)
      else
        ext_draw_polyline(config, coordinates)
      end
      update_texture if @update
    end

    # Fill a polygon made up of N points.
    # @note Currently only supports convex polygons or simple polygons with one concave corner.
    # @note Supports per-vertex coloring, but the triangulation may change and affect the coloring.
    # @param [Array] coordinates An array of numbers x1, y1, x2, y2 ... with at least three coordinates (6 values)
    # @param [Color, Color::Set] color (or +colour+) Set one or per-vertex colour; at least one colour must be specified.
    def fill_polygon(coordinates:, color: nil, colour: nil)
      return if coordinates.nil? || coordinates.count < 6 || (color.nil? && colour.nil?)

      colors = colors_to_a(color || colour)
      ext_fill_polygon(coordinates, colors)
      update_texture if @update
    end

    # Draw the pixmap at the specified location and size
    #
    # @note This API will evolve to be able to draw a portion of the pixmap; coming soon.
    # @param [Pixmap] pixmap
    # @param [Numeric] x
    # @param [Numeric] y
    # @param [Numeric] width Optional, specify to scale the size
    # @param [Numeric] height  Optional, specify to scale the size
    # @param [Hash] crop Optional, specify a hash with `x:, y:, width:, height:` to crop from within the pixmap to draw.
    def draw_pixmap(pixmap, x:, y:, width: nil, height: nil, crop: nil)
      src_rect = crop ? [crop[:x], crop[:y], crop[:width], crop[:height]] : nil
      ext_draw_pixmap pixmap, src_rect, x, y, width, height
    end

    def update
      update_texture
    end

    private

    # Converts +color_or_set+ as a sequence of colour components; e.g. +[ r1, g1, b1, a1, ...]+
    # @param [Color, Color::Set] color_or_set
    # @return an array of r, g, b, a values
    def colors_to_a(color_or_set)
      if color_or_set.is_a? Color::Set
        color_a = []
        color_or_set.each do |clr|
          color_a << clr.r << clr.g << clr.b << clr.a
        end
        return color_a
      end

      color_or_set = Color.new(color_or_set) unless color_or_set.is_a? Color
      color_or_set.to_a
    end

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
