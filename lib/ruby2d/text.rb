# frozen_string_literal: true

# Ruby2D::Text

module Ruby2D
  # Text string drawn using the specified font and size
  class Text
    include Renderable

    attr_reader :text, :size
    attr_accessor :x, :y, :rotate, :data

    # Create a text string
    # @param text The text to show
    # @param [Numeric] size The font +size+
    # @param [String] font Path to font file to use to draw the text
    # @param [String] style Font style
    # @param [Numeric] x
    # @param [Numeric] y
    # @param [Numeric] z
    # @param [Numeric] rotate Angle, default is 0
    # @param [Numeric] color or +colour+ Colour the text when rendering
    # @param [Numeric] opacity Opacity of the image when rendering
    # @param [true, false] show If +true+ the Text is added to +Window+ automatically.
    def initialize(text, size: 20, style: nil, font: Font.default,
                   x: 0, y: 0, z: 0,
                   rotate: 0, color: nil, colour: nil,
                   opacity: nil, show: true)
      @x = x
      @y = y
      @z = z
      @text = text.to_s
      @size = size
      @rotate = rotate
      @style = style
      self.color = color || colour || 'white'
      self.color.opacity = opacity unless opacity.nil?
      @font_path = font
      @texture = nil
      create_font
      create_texture

      add if show
    end

    # Returns the path of the font as a string
    def font
      @font_path
    end

    def text=(msg)
      @text = msg.to_s
      create_texture
    end

    def size=(size)
      @size = size
      create_font
      create_texture
    end

    def draw(x:, y:, color:, rotate:)
      Window.render_ready_check

      x ||= @rotate
      color ||= [1.0, 1.0, 1.0, 1.0]

      render(x: x, y: y, color: Color.new(color), rotate: rotate)
    end

    private

    def render(x: @x, y: @y, color: @color, rotate: @rotate)
      vertices = Vertices.new(x, y, @width, @height, rotate)

      @texture.draw(
        vertices.coordinates, vertices.texture_coordinates, color
      )
    end

    def create_font
      @font = Font.load(@font_path, @size, @style)
    end

    def create_texture
      @texture&.delete
      @texture = Texture.new(*Text.ext_load_text(@font.ttf_font, @text))
      @width = @texture.width
      @height = @texture.height
    end
  end
end
