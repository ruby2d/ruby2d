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
    @input_counter = 0

    def self.start_input
      DSL.window.start_input if @input_counter <= 0
      @input_counter += 1
    end

    def self.stop_input
      @input_counter = [0, @input_counter - 1].max
      DSL.window.stop_input if @input_counter <= 0
    end

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

      @events = DSL.window.instance_variable_get(:@events)

      @text_input_proc = proc do |event|
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

      @command_input_proc = proc do |event|
        if event.type == :down
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
      end

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

      self.class.start_input

      @focused = true
      @caret.add

      @text_input_descriptor = DSL.window.on :text_input, &@text_input_proc

      # this is necessary to prevent Ruby's
      # RuntimeError: 'can't add a new key into hash during iteration'
      # that happens when calling focus from inside a :key_down event
      if @events[:key_down].empty?
        @command_input_descriptor = DSL.window.on :key_down, &command_input_proc
        @command_input_stored_proc = nil
      else
        @command_input_descriptor = @events[:key_down].first.first
        @command_input_stored_proc = @events[:key_down][@command_input_descriptor]
        @events[:key_down][@command_input_descriptor] = proc do |event|
          @command_input_stored_proc.call event
          @command_input_proc.call event
        end
      end
    end

    def unfocus
      return unless @focused

      self.class.stop_input

      @focused = false
      @caret.remove

      DSL.window.off @text_input_descriptor

      if @command_input_stored_proc.nil?
        DSL.window.off @command_input_descriptor
      else
        @events[:key_down][@command_input_descriptor] = @command_input_stored_proc
      end
    end
  end
end
