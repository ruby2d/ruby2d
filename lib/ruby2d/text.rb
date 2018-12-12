# Ruby2D::Text

module Ruby2D
  class Text
    include Renderable

    attr_reader :text, :size, :width, :height, :font, :color
    attr_accessor :x, :y, :rotate, :data

    def initialize(text, opts = {})
      @x = opts[:x] || 0
      @y = opts[:y] || 0
      @z = opts[:z] || 0
      @text = text.to_s
      @size = opts[:size] || 20
      @rotate = opts[:rotate] || 0
      @font = opts[:font] || Font.default
      unless File.exist? @font
        raise Error, "Cannot find font file `#{@font}`"
      end
      self.color = opts[:color] || 'white'
      ext_init
      add
    end

    def text=(msg)
      @text = msg.to_s
      ext_set(@text)
    end

    def color=(c)
      @color = Color.new(c)
    end

  end
end
