# Ruby2D::Text

module Ruby2D
  class Text
    include Renderable

    attr_reader :text, :size
    attr_accessor :x, :y, :rotate, :data

    def initialize(text, opts = {})
      @x = opts[:x] || 0
      @y = opts[:y] || 0
      @z = opts[:z] || 0
      @text = text.to_s
      @size = opts[:size] || 20
      @rotate = opts[:rotate] || 0
      @style = opts[:style]
      self.color = opts[:color] || 'white'
      self.color.opacity = opts[:opacity] if opts[:opacity]
      @font_path = opts[:font] || Font.default
      create_font
      create_texture

      unless opts[:show] == false then add end
    end

    # Returns the path of the font as a string
    def font
      @font_path
    end

    def text=(msg)
      @text = msg.to_s
      create_texture
    end

    def size=(size)
      @size = size
      create_font
      create_texture
    end

    def draw(opts = {})
      Window.render_ready_check

      opts[:rotate] = opts[:rotate] || @rotate
      unless opts[:color]
        opts[:color] = [1.0, 1.0, 1.0, 1.0]
      end

      render(x: opts[:x], y: opts[:y], color: Color.new(opts[:color]), rotate: opts[:rotate])
    end

    private

    def render(x: @x, y: @y, color: @color, rotate: @rotate)
      vertices = Vertices.new(x, y, @width, @height, rotate)

      @texture.draw(
        vertices.coordinates, vertices.texture_coordinates, color
      )
    end

    def create_font
      @font = Font.load(@font_path, @size, @style)
    end

    def create_texture
      if @texture then @texture.delete end

      @texture = Texture.new(*Text.ext_load_text(@font.ttf_font, @text))
      @width = @texture.width
      @height = @texture.height
    end
  end
end
