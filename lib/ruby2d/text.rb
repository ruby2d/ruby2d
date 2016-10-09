# text.rb

module Ruby2D
  class Text

    attr_accessor :x, :y, :size, :text
    
    def initialize(x=0, y=0, size=20, msg="Hello World!", font="Arial", c="white")

      if File.exists? font
        @font = font
      else
        @font = resolve_path(font)
      end
      
      @type_id = 5
      @x, @y, @size = x, y, size
      @text, @color = msg, c
      update_color(c)
      
      if defined? DSL
        Application.add(self)
      end
    end
    
    def color=(c)
      @color = c
      update_color(c)
    end
    
    def text=(t)
      @text = t
    end
    
    def remove
      if defined? DSL
        Application.remove(self)
      end
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
    
    def update_color(c)
      @c = Color.new(c)
    end
    
  end
end
