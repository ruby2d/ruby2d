# Ruby2D::Text

module Ruby2D
  class Text
    include Renderable

    attr_reader :text, :font
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
      @font = opts[:font] || Font.default
      unless File.exist? @font
        raise Error, "Cannot find font file `#{@font}`"
      end
      @font_instance_test = Font.new.ext_load(@font, @size)


      # else
      #   raise Error, "Text `#{@text}` cannot be created"
      # end
      unless opts[:show] == false then add end

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
        texture_id, width, height = ext_load_texture(@font_instance_test, @text)

        @texture = Texture.new(texture_id, width, height)
      end

      @texture.ext_draw(
        Vertices.new(x, y, @texture.width, @texture.height, color, rotate).to_a,
        @texture.texture_id
      )
    end
  end
end
