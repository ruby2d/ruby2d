# color.rb

module Ruby2D
  class Color
    
    attr_reader :r, :g, :b, :a
    
    def initialize(c)
      if !self.class.is_valid? c
        raise Error, "`#{c}` is not a valid color"
      end
      
      case c
      when 'black'
        @r, @g, @b, @a = to_f([0, 0, 0, 255])
      when 'gray'
        @r, @g, @b, @a = to_f([170, 170, 170, 255])
      when 'silver'
        @r, @g, @b, @a = to_f([221, 221, 221, 255])
      when 'white'
        @r, @g, @b, @a = to_f([255, 255, 255, 255])
      when 'navy'
        @r, @g, @b, @a = to_f([0, 31, 63, 255])
      when 'blue'
        @r, @g, @b, @a = to_f([0, 116, 217, 255])
      when 'aqua'
        @r, @g, @b, @a = to_f([127, 219, 255, 255])
      when 'teal'
        @r, @g, @b, @a = to_f([57, 204, 204, 255])
      when 'olive'
        @r, @g, @b, @a = to_f([61, 153, 112, 255])
      when 'green'
        @r, @g, @b, @a = to_f([46, 204, 64, 255])
      when 'lime'
        @r, @g, @b, @a = to_f([1, 255, 112, 255])
      when 'yellow'
        @r, @g, @b, @a = to_f([255, 220, 0, 255])
      when 'orange'
        @r, @g, @b, @a = to_f([255, 133, 27, 255])
      when 'red'
        @r, @g, @b, @a = to_f([255, 65, 54, 255])
      when 'maroon'
        @r, @g, @b, @a = to_f([133, 20, 75, 255])
      when 'fuchsia'
        @r, @g, @b, @a = to_f([240, 18, 190, 255])
      when 'purple'
        @r, @g, @b, @a = to_f([177, 13, 201, 255])
      when 'brown'
        @r, @g, @b, @a = to_f([102, 51, 0, 255])
      when 'random'
        @r, @g, @b, @a = rand(0..1.0), rand(0..1.0), rand(0..1.0), 1.0
      when Array
        @r, @g, @b, @a = to_f([c[0], c[1], c[2], c[3]])
      else
        raise Error, "`#{c}` is not a valid color"
      end
    end
    
    # Color must be String, like 'red', or Array, like [1.0, 0, 0, 1.0]
    def self.is_valid?(c)
      # TODO: Check if valid color string
      #   (c.class == String && c.has_key?(c)) ||
      (c.class == String) ||
      (c.class == Array && c.length == 4 &&
       c.all? { |el| el.is_a? Numeric } &&
       c.all? { |el| el.class == Fixnum && (0..255).include?(el) ||
                     el.class == Float  && (0.0..1.0).include?(el) })
    end
    
    private
    
    # Convert from Fixnum (0..255) to Float (0.0..1.0)
    def to_f(a)
      b = []
      a.each do |n|
        if n.class == Fixnum
          b.push(n / 255.0)
        else
          b.push(n)
        end
      end
      return b
    end
    
  end
end
