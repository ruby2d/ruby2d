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
      @texture = Texture.new(*ext_load_text(@font.ttf_font, @text))
      @width = @texture.width
      @height = @texture.height

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
      @texture = Texture.new(*ext_load_text(@font.ttf_font, @text))
      @width = @texture.width
      @height = @texture.height
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
      vertices = Vertices.new(x, y, @texture.width, @texture.height, rotate)

      @texture.draw(
        vertices.coordinates, vertices.texture_coordinates, color
      )
    end
  end
end
