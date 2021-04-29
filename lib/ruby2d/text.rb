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
      unless ext_init
        raise Error, "Text `#{@text}` cannot be created"
      end
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

      self.class.ext_draw([
        self, opts[:x], opts[:y], opts[:rotate],
        opts[:color][0], opts[:color][1], opts[:color][2], opts[:color][3]
      ])
    end

    private

    def render
      self.class.ext_draw([
        self, @x, @y, @rotate,
        @color.r, @color.g, @color.b, @color.a
      ])
    end

  end
end
