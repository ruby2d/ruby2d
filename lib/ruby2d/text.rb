# Ruby2D::Text

module Ruby2D
  class Text
    include Renderable

    attr_reader :text
    attr_accessor :x, :y, :size, :rotate, :data

    def initialize(text, opts = {})
      @x = opts[:x] || 0
      @y = opts[:y] || 0
      @z = opts[:z] || 0
      @text = text.to_s
      @size = opts[:size] || 20
      @rotate = opts[:rotate] || 0
      self.color = opts[:color] || 'white'
      self.opacity = opts[:opacity] if opts[:opacity]
      @font_path = opts[:font] || Font.default
      @font = Font.load(@font_path, @size)

      unless opts[:show] == false then add end

    end

    # Here to keep API compatibility
    # TODO: revisit if this is neccessary or not
    # I think it would be useful as you can clone text objects this way by using `font: another_text.font` in your
    # constructor
    def font
      @font_path
    end

    def text=(msg)
      @text = msg.to_s
      ext_set(@text)
    end

    def draw(opts = {})
      opts[:rotate] = opts[:rotate] || @rotate
      unless opts[:color]
        opts[:color] = [1.0, 1.0, 1.0, 1.0]
      end

      render(x: opts[:x], y: opts[:y], color: Color.new(opts[:color]), rotate: opts[:rotate])
    end

    private

    def render(x: @x, y: @y, color: @color, rotate: @rotate)
      # TODO: If the width or height changes (maybe due to font size), we'll need to re-generate the texture :)
      unless defined?(@texture)
        # TODO: Texture may also need to store the surface object from the C extension (I think so we can free() it)
        @texture = Texture.load_text(@font, @text)
      end

      vertices = Vertices.new(x, y, @texture.width, @texture.height, rotate)
      color = [color.r, color.g, color.b, color.a]

      @texture.ext_draw(
        vertices.coordinates, vertices.texture_coordinates, color, @texture.texture_id
      )
    end
  end
end
