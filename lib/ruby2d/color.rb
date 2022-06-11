# frozen_string_literal: true

# Ruby2D::Color

module Ruby2D
  # Colors are represented by the Color class. Colors can be created from keywords
  # (based on css), a hexadecimal value or an array containing a collection of
  # red, green, blue, and alpha (transparency) values expressed as a Float from 0.0 to 1.0.
  class Color
    # Color::Set represents an array of colors.
    class Set
      include Enumerable

      def initialize(colors)
        @colors = colors.map { |c| Color.new(c) }
      end

      def [](index)
        @colors[index]
      end

      def length
        @colors.length
      end

      alias count length

      def each(&block)
        @colors.each(&block)
      end

      def first
        @colors.first
      end

      def last
        @colors.last
      end

      def opacity
        @colors.first.opacity
      end

      def opacity=(opacity)
        @colors.each do |color|
          color.opacity = opacity
        end
      end
    end

    attr_accessor :r, :g, :b, :a

    # Based on clrs.cc
    NAMED_COLORS = {
      'navy' => '#001F3F',
      'blue' => '#0074D9',
      'aqua' => '#7FDBFF',
      'teal' => '#39CCCC',
      'olive' => '#3D9970',
      'green' => '#2ECC40',
      'lime' => '#01FF70',
      'yellow' => '#FFDC00',
      'orange' => '#FF851B',
      'red' => '#FF4136',
      'brown' => '#663300',
      'fuchsia' => '#F012BE',
      'purple' => '#B10DC9',
      'maroon' => '#85144B',
      'white' => '#FFFFFF',
      'silver' => '#DDDDDD',
      'gray' => '#AAAAAA',
      'black' => '#111111',
      'random' => ''
    }.freeze

    def initialize(color)
      raise Error, "`#{color}` is not a valid color" unless self.class.valid? color

      case color
      when String
        init_from_string color
      when Array
        @r = color[0]
        @g = color[1]
        @b = color[2]
        @a = color[3]
      when Color
        @r = color.r
        @g = color.g
        @b = color.b
        @a = color.a
      end
    end

    class << self
      # Return a color set if an array of valid colors
      def set(colors)
        # If a valid array of colors, return a `Color::Set` with those colors
        if colors.is_a?(Array) && colors.all? { |el| Color.valid? el }
          Color::Set.new(colors)
        # Otherwise, return single color
        else
          Color.new(colors)
        end
      end

      # Check if string is a proper hex value
      def hex?(color_string)
        # MRuby doesn't support regex, otherwise we'd do:
        #   !(/^#[0-9A-F]{6}$/i.match(a).nil?)
        color_string.instance_of?(String) &&
          color_string[0] == '#' &&
          color_string.length == 7
      end

      # Check if the color is valid
      def valid?(color)
        color.is_a?(Color) ||             # color object
          NAMED_COLORS.key?(color) ||     # keyword
          hex?(color) ||                  # hexadecimal value
          (                               # Array of Floats from 0.0..1.0
            color.instance_of?(Array) &&
            color.length == 4 &&
            color.all? { |el| el.is_a?(Numeric) }
          )
      end

      #
      # Backwards compatibility
      alias is_valid? valid?
      alias is_hex? valid?
    end

    # Convenience methods to alias `opacity` to `@a`
    def opacity
      @a
    end

    def opacity=(opacity)
      @a = opacity
    end

    # Return colour components as an array +[r, g, b, a]+
    def to_a
      [@r, @g, @b, @a]
    end

    private

    def init_from_string(color)
      if color == 'random'
        init_random_color
      elsif self.class.hex?(color)
        @r, @g, @b, @a = hex_to_f(color)
      else
        @r, @g, @b, @a = hex_to_f(NAMED_COLORS[color])
      end
    end

    def init_random_color
      @r = rand
      @g = rand
      @b = rand
      @a = 1.0
    end

    # Convert from Fixnum (0..255) to Float (0.0..1.0)
    def i_to_f(color_array)
      b = []
      color_array.each do |n|
        b.push(n / 255.0)
      end
      b
    end

    # Convert from hex value (e.g. #FFF000) to Float (0.0..1.0)
    def hex_to_f(hex_color)
      hex_color = (hex_color[1..]).chars.each_slice(2).map(&:join)
      a = []

      hex_color.each do |el|
        a.push(el.to_i(16))
      end

      a.push(255)
      i_to_f(a)
    end
  end

  # Allow British English spelling of color
  Colour = Color
end
