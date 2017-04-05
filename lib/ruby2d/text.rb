# text.rb

module Ruby2D
  class Text
    include Renderable
    
    attr_accessor :x, :y, :data
    attr_reader :text, :size, :width, :height, :font, :color, :z
    
    def initialize(x=0, y=0, text="Hello World!", size=20, font=nil, c="white", z=0)
      
      # if File.exists? font
        @font = font
      # else
      #   @font = resolve_path(font)
      # end
      
      @type_id = 5
      @x, @y, @z, @size = x, y, z, size
      @text = text.to_s
      self.color = c
      init
      add
    end
    
    def text=(msg)
      @text = msg.to_s
      ext_text_set(@text)
    end
    
    def color=(c)
      @color = Color.new(c)
    end

    def z=(z)
      @z = z
      Application.z_sort
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
