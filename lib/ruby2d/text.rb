# text.rb

module Ruby2D
  class Text
    
    attr_accessor :x, :y, :size, :text
    
    def initialize(x=0, y=0, size=20, text="Hello World!", font="Arial", c="white")
      if font.include? '.'
        unless File.exists? font
          raise Error, "Cannot find font file!"
        else
          @font = font
        end
      else
        @font = resolve_path(font)
      end
      
      @type_id = 4
      @x, @y, @size = x, y, size
      @text, @color = text, c
      update_color(c)
      
      if defined? Ruby2D::DSL
        Ruby2D::Application.add(self)
      end
    end
    
    def color=(c)
      @color = c
      update_color(c)
    end
    
    def remove
      if defined? Ruby2D::DSL
        Ruby2D::Application.remove(self)
      end
    end
    
    private
    
    def resolve_path(font)
      if RUBY_PLATFORM =~ /darwin/
        font_path = "/Library/Fonts/#{font}.ttf"
        unless File.exists? font_path
          raise Error, "Cannot find system font!"
        end
      end
      font_path
    end
    
    def update_color(c)
      @c = Ruby2D::Color.new(c)
    end
    
  end
end
