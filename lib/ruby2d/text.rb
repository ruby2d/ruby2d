# text.rb

module Ruby2D
  class Text
    include Renderable

    attr_accessor :x, :y, :data
    attr_reader :text, :size, :width, :height, :font, :color

    def initialize(opts = {})
      @x = opts[:x] || 0
      @y = opts[:y] || 0
      @z = opts[:z] || 0
      @text = (opts[:text] || "Hello World!").to_s
      @size = opts[:size] || 20

      @font = opts[:font]

      unless RUBY_ENGINE == 'opal'
        unless File.exists? @font
          raise Error, "Cannot find font file `#{@font}`"
        end
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

    def contains?(x, y)
      @x < x and @x + @width > x and @y < y and @y + @height > y
    end

    private

    def resolve_path(font)
      if RUBY_PLATFORM =~ /darwin/
        font_path = "/Library/Fonts/#{font}.ttf"
      else
        # Linux
        font_path = "/usr/share/fonts/truetype/#{font}.ttf"
      end

      unless File.exists? font_path
        raise Error, "Cannot find system font"
      else
        font_path
      end
    end

  end
end
