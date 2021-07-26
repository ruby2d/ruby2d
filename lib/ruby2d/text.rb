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

      # FIXME: Get these custom options working again :)
      render()
      # self.class.ext_draw([
      #   self, opts[:x], opts[:y], opts[:rotate],
      #   opts[:color][0], opts[:color][1], opts[:color][2], opts[:color][3]
      # ])
    end

    private

    def render
      # TODO: If the width or height changes, we'll need to re-generate the texture :)
      unless defined?(@texture)
        # TODO: Texture will also store the surface object from the C extension
        texture_id, width, height = ext_load_texture(@font_instance_test, @text)

        @texture = Texture.new(texture_id, width, height)
      end

      # TODO: move this to a vertex calculator class
      x1 = @x
      x2 = @x + @texture.width
      x3 = @x + @texture.width
      x4 = @x
      y1 = @y
      y2 = @y
      y3 = @y + @texture.height
      y4 = @y + @texture.height
      tx1 = 0.0
      ty1 = 0.0
      tx2 = 1.0
      ty2 = 0.0
      tx3 = 1.0
      ty3 = 1.0
      tx4 = 0.0
      ty4 = 1.0

      # TODO: add rotation processing before outputing vertices :)
      @texture.ext_draw([
        x1, y1, @color.r, @color.g, @color.b, @color.a, tx1, ty1,
        x2, y2, @color.r, @color.g, @color.b, @color.a, tx2, ty2,
        x3, y3, @color.r, @color.g, @color.b, @color.a, tx3, ty3,
        x4, y4, @color.r, @color.g, @color.b, @color.a, tx4, ty4],
        @texture.texture_id
      )
    end

  end
end
