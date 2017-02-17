# text.rb

module Ruby2D
  class Text
    
    attr_accessor :x, :y, :size, :text, :data
    attr_reader :color
    
    def initialize(x=0, y=0, size=20, text="Hello World!", font="Arial", c="white")
      
      # if File.exists? font
        @font = font
      # else
      #   @font = resolve_path(font)
      # end
      
      @type_id = 5
      @x, @y, @size = x, y, size
      @text = text
      @color = Color.new(c)
      add
    end
    
    def color=(c)
      @color = Color.new(c)
    end
    
    def text=(t)
      @text = t
    end
        
    def add
      if Module.const_defined? :DSL
        Application.add(self)
      end
    end
    
    def remove
      if Module.const_defined? :DSL
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
    
  end
end
