# frozen_string_literal: false

# Ruby2D::TextInput

module Ruby2D
  # This class draws the caret
  class Caret
    attr_accessor :i

    def initialize(text, color: nil)
      @text = text
      @line = Line.new(z: @text.z + 1, width: 2, color: color)
      @font = text.instance_variable_get('@font')
      @i = @text.text.size
      @line.remove
      update
    end

    def update
      offset = 0
      if @i.positive?
        texture = Texture.new(*Text.ext_load_text(@font.ttf_font, @text.text[0..@i - 1]))
        offset = texture.width
      end
      @line.x1 = @line.x2 = @text.x + offset
      @line.y1 = @text.y
      @line.y2 = @text.y + @text.height
    end

    def add
      @line.add
    end

    def remove
      @line.remove
    end
  end

  # Text string drawn using the specified font and size
  class TextInput < Text
    def initialize(text, size: 20, style: nil, font: Font.default,
                   x: 0, y: 0, z: 0,
                   rotate: 0, color: nil, colour: nil,
                   opacity: nil, show: true,
                   maxlen: nil, maxwidth: nil,
                   caret_color: nil, caret_colour: nil)

      super(text, size: size, style: style, font: font, x: x, y: y, z: z, rotate: rotate, color: color, colour: colour, opacity: opacity, show: show)

      @focused = false

      @maxlen = maxlen
      @maxwidth = maxwidth

      @caret = Caret.new(self, color: caret_color || caret_colour || color || colour)
      @caret.i = text.size
    end
    
    def focused?
      @focused
    end

    def text=(text)
      super
      @caret.i = text.size
      @caret.update
    end

    def add
      @caret.add if @focused
      super
    end

    def remove
      @caret.remove
      super
    end

    def focus
      return if @focused

      @focused = true
      @caret.add

      @text_input_descriptor = Window.on :text_input do |event|
        text = String.new(@text)
        text.insert(@caret.i, event.text)
        texture = Texture.new(*Text.ext_load_text(@font.ttf_font, text))

        if (@maxlen.nil? || text.size <= @maxlen) && (@maxwidth.nil? || texture.width <= @maxwidth)
          @text = text
          @texture&.delete
          @texture = texture
          @width = texture.width
          @height = texture.height
          @caret.i += event.text.size
          @caret.update
        end
      end

      @command_input_descriptor = Window.on :key_down do |event|
        case event.key
        when 'left'
          @caret.i -= 1 if @caret.i.positive?
        when 'right'
          @caret.i += 1 if @caret.i < @text.size
        when 'home'
          @caret.i = 0
        when 'end'
          @caret.i = @text.size
        when 'backspace'
          if @caret.i.positive?
            @caret.i -= 1
            @text[@caret.i] = ''
            create_texture
          end
        when 'delete'
          if @caret.i < @text.size
            @text[@caret.i] = ''
            create_texture
          end
        end
        @caret.update
      end

      Window.start_input
    end

    def unfocus
      return unless @focused

      @focused = false
      @caret.remove

      Window.stop_input

      Window.off @text_input_descriptor
      Window.off @command_input_descriptor
    end
  end
end
