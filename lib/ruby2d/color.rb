# color.rb

module Ruby2D
  class Color
    
    attr_reader :r, :g, :b, :a
    
    @@colors = {
      'black'   => [  0,   0,   0, 255],
      'gray'    => [170, 170, 170, 255],
      'silver'  => [221, 221, 221, 255],
      'white'   => [255, 255, 255, 255],
      'navy'    => [  0,  31,  63, 255],
      'blue'    => [  0, 116, 217, 255],
      'aqua'    => [127, 219, 255, 255],
      'teal'    => [ 57, 204, 204, 255],
      'olive'   => [ 61, 153, 112, 255],
      'green'   => [ 46, 204,  64, 255],
      'lime'    => [  1, 255, 112, 255],
      'yellow'  => [255, 220,   0, 255],
      'orange'  => [255, 133,  27, 255],
      'red'     => [255,  65,  54, 255],
      'maroon'  => [133,  20,  75, 255],
      'fuchsia' => [240,  18, 190, 255],
      'purple'  => [177,  13, 201, 255],
      'brown'   => [102,  51,   0, 255],
      'random'  => []
    }
    
    def initialize(c)
      if !self.class.is_valid? c
        raise Error, "`#{c}` is not a valid color"
      else
        case c
        when String
          if c == 'random'
            @r, @g, @b, @a = rand(0..1.0), rand(0..1.0), rand(0..1.0), 1.0
          elsif self.class.is_hex(c)
            @r, @g, @b, @a = hex_to_f(c)
          else
            @r, @g, @b, @a = to_f(@@colors[c])
          end
        when Array
          @r, @g, @b, @a = to_f([c[0], c[1], c[2], c[3]])
        end
      end
    end

    # test whether input string is Hex color
    def self.is_hex(a)
      # result = !(/^#[0-9A-F]{6}$/i.match(a).nil?)
      # return result
      if (a.include? "#") && (a.length == 7)
        true
      else
        false
      end
    end

    # Color must be String, like 'red', or Array, like [1.0, 0, 0, 1.0]
    def self.is_valid?(c)
      (c.class == String && @@colors.key?(c)) ||
      (c.class == String && self.is_hex(c)) ||
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

    # convert from "#FFF000" to Float (0.0..1.0) 
    def hex_to_f(a)
      c=[]	    
      b=a.delete("#")
      n=(b.length)
      #n1=n/3
      j=0
      for i in (0..n-1).step(n/3)
      	c[j]=Integer("0x".concat(b[i,n/3]))
	      j=j+1
      end
      c[3] = 255 #set @a to 255
      f = to_f(c)
      return f
    end
    
  end
end
