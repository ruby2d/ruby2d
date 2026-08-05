# Ruby2D::JsonParser

module Ruby2D
  # Internal recursive-descent JSON parser. Hand-rolled so Ruby 2D pulls in no
  # stdlib `require 'json'` and stays mruby-compatible without an mrbgem
  # dependency. Public API: `Ruby2D::JsonParser.parse(str)`.
  module JsonParser
    class ParseError < StandardError; end

    def self.parse(str)
      Parser.new(str).parse
    end

    class Parser
      # Cap nesting depth so pathological input fails with a ParseError rather
      # than overflowing the Ruby stack with a SystemStackError. Real texture
      # atlases nest only a handful of levels deep.
      MAX_DEPTH = 500

      def initialize(str)
        @s = str
        @i = 0
        @depth = 0
      end

      def parse
        skip_ws
        value = parse_value
        skip_ws
        raise ParseError, "unexpected trailing data at offset #{@i}" if @i < @s.length

        value
      end

      private

      def parse_value
        @depth += 1
        raise ParseError, "nesting too deep (over #{MAX_DEPTH} levels)" if @depth > MAX_DEPTH

        skip_ws
        c = @s[@i]
        case c
        when '{' then parse_object
        when '[' then parse_array
        when '"' then parse_string
        when 't', 'f' then parse_bool
        when 'n' then parse_null
        when '-', '0', '1', '2', '3', '4', '5', '6', '7', '8', '9' then parse_number
        else
          raise ParseError, "unexpected character #{c.inspect} at offset #{@i}"
        end
      ensure
        @depth -= 1
      end

      def parse_object
        @i += 1
        obj = {}
        skip_ws
        if @s[@i] == '}'
          @i += 1
          return obj
        end
        loop do
          skip_ws
          raise ParseError, "expected string key at offset #{@i}" unless @s[@i] == '"'

          key = parse_string
          skip_ws
          raise ParseError, "expected ':' at offset #{@i}" unless @s[@i] == ':'

          @i += 1
          obj[key] = parse_value
          skip_ws
          case @s[@i]
          when ','
            @i += 1
          when '}'
            @i += 1
            return obj
          else
            raise ParseError, "expected ',' or '}' at offset #{@i}"
          end
        end
      end

      def parse_array
        @i += 1
        arr = []
        skip_ws
        if @s[@i] == ']'
          @i += 1
          return arr
        end
        loop do
          arr << parse_value
          skip_ws
          case @s[@i]
          when ','
            @i += 1
          when ']'
            @i += 1
            return arr
          else
            raise ParseError, "expected ',' or ']' at offset #{@i}"
          end
        end
      end

      def parse_string
        @i += 1
        result = ''.dup
        while (c = @s[@i])
          case c
          when '"'
            @i += 1
            return result
          when '\\'
            result << parse_escape
          else
            result << c
            @i += 1
          end
        end
        raise ParseError, 'unterminated string'
      end

      def parse_escape
        @i += 1
        esc = @s[@i]
        @i += 1
        case esc
        when '"'  then '"'
        when '\\' then '\\'
        when '/'  then '/'
        when 'b'  then "\b"
        when 'f'  then "\f"
        when 'n'  then "\n"
        when 'r'  then "\r"
        when 't'  then "\t"
        when 'u'  then parse_unicode_escape
        else
          raise ParseError, "bad escape \\#{esc} at offset #{@i - 1}"
        end
      end

      def parse_unicode_escape
        code = read_hex4
        # Handle a UTF-16 surrogate pair
        if code >= 0xD800 && code <= 0xDBFF
          raise ParseError, "expected low surrogate at offset #{@i}" unless @s[@i, 2] == '\\u'

          @i += 2
          lo = read_hex4
          raise ParseError, "invalid low surrogate at offset #{@i}" unless lo >= 0xDC00 && lo <= 0xDFFF

          code = 0x10000 + ((code - 0xD800) * 0x400) + (lo - 0xDC00)
        elsif code >= 0xDC00 && code <= 0xDFFF
          # A low surrogate with no preceding high surrogate is not a valid
          # scalar value; without this guard it would escape as a RangeError.
          raise ParseError, "unexpected low surrogate at offset #{@i}"
        end
        encode_codepoint(code)
      end

      def read_hex4
        hex = @s[@i, 4]
        unless hex && hex.length == 4 && hex_only?(hex)
          raise ParseError, "bad unicode escape at offset #{@i}"
        end

        @i += 4
        hex.to_i(16)
      end

      def hex_only?(s)
        s.each_char.all? { |c| (c >= '0' && c <= '9') || (c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F') }
      end

      # On CRuby, `Integer#chr(Encoding::UTF_8)` produces a properly tagged
      # UTF-8 string. mruby (without the encoding mrbgem) lacks `Encoding`, so
      # we fall back to a hand-rolled UTF-8 byte sequence.
      def encode_codepoint(code)
        code.chr(Encoding::UTF_8)
      rescue NameError, ArgumentError
        encode_codepoint_bytes(code)
      end

      def encode_codepoint_bytes(code)
        if code < 0x80
          code.chr
        elsif code < 0x800
          (0xC0 | (code >> 6)).chr +
            (0x80 | (code & 0x3F)).chr
        elsif code < 0x10000
          (0xE0 | (code >> 12)).chr +
            (0x80 | ((code >> 6) & 0x3F)).chr +
            (0x80 | (code & 0x3F)).chr
        else
          (0xF0 | (code >> 18)).chr +
            (0x80 | ((code >> 12) & 0x3F)).chr +
            (0x80 | ((code >> 6) & 0x3F)).chr +
            (0x80 | (code & 0x3F)).chr
        end
      end

      def parse_number
        start = @i
        @i += 1 if @s[@i] == '-'
        if @s[@i] == '0'
          @i += 1
        elsif digit?(@s[@i])
          @i += 1 while digit?(@s[@i])
        else
          raise ParseError, "bad number at offset #{start}"
        end
        is_float = false
        if @s[@i] == '.'
          is_float = true
          @i += 1
          frac_start = @i
          @i += 1 while digit?(@s[@i])
          raise ParseError, "expected digits after '.' at offset #{frac_start}" if @i == frac_start
        end
        if @s[@i] == 'e' || @s[@i] == 'E'
          is_float = true
          @i += 1
          @i += 1 if @s[@i] == '+' || @s[@i] == '-'
          exp_start = @i
          @i += 1 while digit?(@s[@i])
          raise ParseError, "expected digits after exponent at offset #{exp_start}" if @i == exp_start
        end
        token = @s[start...@i]
        is_float ? token.to_f : token.to_i
      end

      def digit?(c)
        c && c >= '0' && c <= '9'
      end

      def parse_bool
        if @s[@i, 4] == 'true'
          @i += 4
          true
        elsif @s[@i, 5] == 'false'
          @i += 5
          false
        else
          raise ParseError, "bad literal at offset #{@i}"
        end
      end

      def parse_null
        raise ParseError, "bad literal at offset #{@i}" unless @s[@i, 4] == 'null'

        @i += 4
        nil
      end

      def skip_ws
        while (c = @s[@i]) && (c == ' ' || c == "\t" || c == "\n" || c == "\r")
          @i += 1
        end
      end
    end
  end
end
