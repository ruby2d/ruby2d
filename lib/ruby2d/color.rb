# color.rb

module Ruby2D
  class Color
    # Color::Set represents an array of colors
    class Set
      def initialize(colors)
        @colors = colors.map{|c| Color.new(c)}
      end

      def [](i)
        @colors[i]
      end

      def length
        @colors.length
      end

      def opacity=(opacity)
        @colors.each do |color|
          color.opacity = opacity
        end
      end
    end
    
    attr_reader :r, :g, :b, :a
    
    # Based on clrs.cc
    @@colors = {
      'navy'    => '#001F3F',
      'blue'    => '#0074D9',
      'aqua'    => '#7FDBFF',
      'teal'    => '#39CCCC',
      'olive'   => '#3D9970',
      'green'   => '#2ECC40',
      'lime'    => '#01FF70',
      'yellow'  => '#FFDC00',
      'orange'  => '#FF851B',
      'red'     => '#FF4136',
      'brown'   => '#663300',
      'fuchsia' => '#F012BE',
      'purple'  => '#B10DC9',
      'maroon'  => '#85144B',
      'white'   => '#FFFFFF',
      'silver'  => '#DDDDDD',
      'gray'    => '#AAAAAA',
      'black'   => '#111111',
      'random'  => ''
    }
    
    def initialize(c)
      if !self.class.is_valid? c
        raise Error, "`#{c}` is not a valid color"
      else
        case c
        when String
          if c == 'random'
            @r, @g, @b, @a = rand, rand, rand, 1.0
          elsif self.class.is_hex?(c)
            @r, @g, @b, @a = hex_to_f(c)
          else
            @r, @g, @b, @a = hex_to_f(@@colors[c])
          end
        when Array
          @r, @g, @b, @a = [c[0], c[1], c[2], c[3]]
        end
      end
    end
    
    # Check if string is a proper hex value
    def self.is_hex?(s)
      # MRuby doesn't support regex, otherwise we'd do:
      #   !(/^#[0-9A-F]{6}$/i.match(a).nil?)
      s.class == String && s[0] == '#' && s.length == 7
    end
    
    # Check if the color is valid
    def self.is_valid?(c)
      @@colors.key?(c) ||  # keyword
      self.is_hex?(c)  ||  # hexadecimal value
      
      # Array of Floats from 0.0..1.0
      c.class == Array && c.length == 4 &&
      c.all? { |el|
        el.is_a?(Numeric) && (0.0..1.0).include?(el)
      }
    end

    def self.from(input)
      # If a valid array of colors, return a Color::Set with those colors
      # Else return single color
      if input.is_a? Array and input.all? { |el| Color.is_valid? el }
        Color::Set.new(input)
      else
        Color.new(input)
      end
    end

    def opacity=(opacity)
      @a = opacity
    end
    
    private
    
    # TODO: Only `Number` supported in JS
    # Convert from Fixnum (0..255) to Float (0.0..1.0)
    def to_f(a)
      b = []
      a.each do |n|
        b.push(n / 255.0)
      end
      return b
    end
    
    # Convert from hex value (e.g. #FFF000) to Float (0.0..1.0)
    def hex_to_f(h)
      h = (h[1..-1]).chars.each_slice(2).map(&:join)
      a = []
      
      h.each do |el|
        a.push(el.to_i(16))
      end
      
      a.push(255)
      return to_f(a)
    end
    
  end
end
