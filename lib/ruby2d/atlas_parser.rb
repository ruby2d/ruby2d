# Ruby2D::AtlasParser

module Ruby2D
  # Internal parser for sprite-sheet atlas files. Reads either Sparrow XML or
  # TexturePacker JSON (Hash or Array variants) and returns a uniform shape:
  #
  #     { image_path: 'sheet.png',
  #       frames: { 'frame_name' => { x:, y:, width:, height: }, ... } }
  #
  # A frame packed with trim or rotation metadata also carries
  # `source_width`/`source_height`/`trim_x`/`trim_y` and/or `rotated: true`,
  # in the same shape from either format. Hand-written and Regexp-free so it
  # works on mruby builds without the regex mrbgem.
  module AtlasParser
    class ParseError < StandardError; end

    def self.parse_file(path)
      data = File.read(path)
      lower = path.to_s.downcase
      if lower.end_with?('.xml')
        parse_xml(data)
      elsif lower.end_with?('.json')
        parse_json(data)
      else
        sniff(data, path)
      end
    end

    def self.sniff(data, path)
      i = 0
      i += 1 while i < data.length && ws?(data[i])
      first = data[i]
      return parse_xml(data) if first == '<'
      return parse_json(data) if first == '{'

      raise ParseError, "Cannot determine atlas format for #{path}"
    end

    def self.parse_xml(str)
      # An XML document is UTF-8 unless it declares otherwise, whatever the
      # process's default external encoding tagged it with, so read it as
      # UTF-8: a decoded reference then never meets bytes of another
      # encoding. (The guard is for an mruby built without `mruby-encoding`;
      # with it, as in Ruby 2D's builds, the call just clears the binary
      # flag. The `dup` keeps a frozen argument safe.)
      str = str.dup.force_encoding('UTF-8') if str.respond_to?(:force_encoding)

      image_path = nil
      frames = {}
      each_start_tag(str) do |tag, attrs|
        if tag == 'TextureAtlas'
          image_path ||= attrs['imagePath']
        elsif tag == 'SubTexture' && attrs['name']
          frames[attrs['name']] = extract_xml_frame(attrs)
        end
      end

      { image_path: image_path, frames: frames }
    end

    def self.extract_xml_frame(attrs)
      rect = {
        x: (attrs['x'] || '0').to_i,
        y: (attrs['y'] || '0').to_i,
        width: (attrs['width'] || '0').to_i,
        height: (attrs['height'] || '0').to_i
      }
      # Starling packs a frame turned 90° clockwise with `rotated="true"`;
      # keep the flag in the shape the JSON path uses so `Sprite` can refuse
      # the frame the same way.
      rect[:rotated] = true if attrs['rotated'] == 'true'

      # Extended Sparrow trim attributes: `frameWidth`/`frameHeight` give
      # the original frame's logical dimensions, and `frameX`/`frameY` are
      # the (negative) offset from the original frame's top-left to where
      # the trimmed rect begins. Convert to a positive `trim_x`/`trim_y`.
      if attrs['frameWidth'] || attrs['frameHeight'] || attrs['frameX'] || attrs['frameY']
        rect[:source_width]  = (attrs['frameWidth']  || rect[:width]).to_i
        rect[:source_height] = (attrs['frameHeight'] || rect[:height]).to_i
        rect[:trim_x] = -(attrs['frameX'] || '0').to_i
        rect[:trim_y] = -(attrs['frameY'] || '0').to_i
      end
      rect
    end

    def self.parse_json(str)
      data = JsonParser.parse(str)
      raise ParseError, 'Invalid JSON atlas: top-level value must be an object' unless data.is_a?(Hash)

      meta = data['meta']
      image_path = meta.is_a?(Hash) ? meta['image'] : nil

      frames = {}
      frames_data = data['frames']
      if frames_data.is_a?(Hash)
        frames_data.each { |name, info| frames[name] = extract_json_frame(info) }
      elsif frames_data.is_a?(Array)
        frames_data.each do |info|
          next unless info.is_a?(Hash)

          name = info['filename']
          frames[name] = extract_json_frame(info) if name
        end
      else
        raise ParseError, "Invalid JSON atlas: 'frames' must be a hash or array"
      end

      { image_path: image_path, frames: frames }
    end

    def self.extract_json_frame(info)
      frame = info.is_a?(Hash) ? info['frame'] : nil
      frame = {} unless frame.is_a?(Hash)
      result = {
        x: (frame['x'] || 0).to_i,
        y: (frame['y'] || 0).to_i,
        width: (frame['w'] || frame['width'] || 0).to_i,
        height: (frame['h'] || frame['height'] || 0).to_i
      }
      # TexturePacker can pack frames rotated 90° to save atlas space.
      # We capture the flag so the consumer can refuse or handle it; the
      # key is omitted when false to keep the common-case hash lean.
      result[:rotated] = true if info.is_a?(Hash) && info['rotated'] == true

      # Trim metadata: `sourceSize` is the original frame's logical size,
      # `spriteSourceSize.x/y` is where the packed pixels live within it.
      source = info.is_a?(Hash) ? info['sourceSize'] : nil
      sprite_source = info.is_a?(Hash) ? info['spriteSourceSize'] : nil
      if source.is_a?(Hash) && (source['w'] || source['h'])
        result[:source_width]  = (source['w'] || result[:width]).to_i
        result[:source_height] = (source['h'] || result[:height]).to_i
        if sprite_source.is_a?(Hash)
          result[:trim_x] = (sprite_source['x'] || 0).to_i
          result[:trim_y] = (sprite_source['y'] || 0).to_i
        else
          result[:trim_x] = 0
          result[:trim_y] = 0
        end
      end

      result
    end

    # Walk the document once, yielding each start tag's name and attribute
    # hash in document order. Comments, CDATA sections, processing
    # instructions, and the DOCTYPE are skipped whole, so a frame kept in a
    # comment never reads as an active one; end tags are skipped too.
    def self.each_start_tag(str)
      i = 0
      len = str.length
      while (i = str.index('<', i))
        if str[i, 4] == '<!--'
          i = skip_past(str, '-->', i + 4, 'comment', i)
        elsif str[i, 9] == '<![CDATA['
          i = skip_past(str, ']]>', i + 9, 'CDATA section', i)
        elsif str[i, 2] == '<?'
          i = skip_past(str, '?>', i + 2, 'processing instruction', i)
        elsif str[i, 2] == '<!'
          i = skip_declaration(str, i)
        elsif str[i, 2] == '</'
          i = skip_past(str, '>', i + 2, 'end tag', i)
        else
          name_start = i + 1
          i = name_start
          i += 1 while i < len && !ws?(str[i]) && str[i] != '>' && str[i] != '/'
          name = str[name_start...i]
          attrs, i = parse_xml_attrs(str, i)
          yield name, attrs
        end
      end
    end

    def self.skip_past(str, terminator, from, what, at)
      close = str.index(terminator, from)
      raise ParseError, "Unterminated #{what} at offset #{at}" unless close

      close + terminator.length
    end

    # Skip a `<!DOCTYPE ...>` declaration, whose internal subset in square
    # brackets may itself contain `>`, and whose quoted literals (a system
    # identifier, an entity value) and comments may contain any of `[`, `]`,
    # `>`, and an unmatched quote.
    def self.skip_declaration(str, at)
      i = at + 2
      depth = 0
      while (c = str[i])
        if c == '<' && str[i, 4] == '<!--'
          i = skip_past(str, '-->', i + 4, 'comment', i)
          next
        elsif c == '"' || c == "'"
          i = str.index(c, i + 1)
          break unless i
        elsif c == '['
          depth += 1
        elsif c == ']'
          depth -= 1
        elsif c == '>' && depth <= 0
          return i + 1
        end
        i += 1
      end
      raise ParseError, "Unterminated declaration at offset #{at}"
    end

    # Parse the `name="value"` (or `name='value'`) attributes of the start tag
    # whose name ends at `i`, up to its closing `>` or `/>`, tolerating extra
    # whitespace between tokens. Returns the attribute hash and the index
    # after the `>`. A `>` inside a quoted value is part of the value, and a
    # value or tag left unterminated is an error rather than a truncated
    # frame with zero coordinates.
    def self.parse_xml_attrs(str, i)
      attrs = {}
      len = str.length
      while i < len
        i += 1 while i < len && ws?(str[i])
        c = str[i]
        return attrs, i + 1 if c == '>'

        if c == '/'
          i += 1
          i += 1 while i < len && ws?(str[i])
          raise ParseError, "Expected '>' after '/' at offset #{i}" unless str[i] == '>'

          return attrs, i + 1
        end

        name_start = i
        i += 1 while i < len && str[i] != '=' && str[i] != '>' && str[i] != '/' && !ws?(str[i])
        name = str[name_start...i]
        raise ParseError, "Expected an attribute name at offset #{name_start}" if name.empty?

        i += 1 while i < len && ws?(str[i])
        raise ParseError, "Expected '=' after attribute `#{name}` at offset #{i}" unless str[i] == '='

        i += 1
        i += 1 while i < len && ws?(str[i])
        quote = str[i]
        unless quote == '"' || quote == "'"
          raise ParseError, "Expected a quoted value for attribute `#{name}` at offset #{i}"
        end

        close = str.index(quote, i + 1)
        raise ParseError, "Unterminated value for attribute `#{name}` at offset #{i}" unless close

        attrs[name] = decode_entities(str[(i + 1)...close])
        i = close + 1
      end
      raise ParseError, "Unterminated tag at offset #{i}"
    end

    # Decode the predefined XML entities and numeric character references in
    # an attribute value, so `a&amp;b.png` names the file `a&b.png`. A
    # reference this parser can't resolve (an entity declared in the DOCTYPE,
    # or a malformed one) is left as written.
    def self.decode_entities(value)
      return value unless value.include?('&')

      out = ''.dup
      i = 0
      while (amp = value.index('&', i))
        out << value[i...amp]
        semi = value.index(';', amp)
        decoded = semi && decode_entity(value[(amp + 1)...semi])
        if decoded
          out << decoded
          i = semi + 1
        else
          out << '&'
          i = amp + 1
        end
      end
      out << value[i..-1]
    end

    def self.decode_entity(ref)
      case ref
      when 'amp' then '&'
      when 'lt' then '<'
      when 'gt' then '>'
      when 'quot' then '"'
      when 'apos' then "'"
      else
        return nil unless ref[0] == '#'

        hex = ref[1] == 'x'
        digits = ref[(hex ? 2 : 1)..-1]
        return nil if digits.empty? || !digits.each_char.all? { |c| hex ? hex_digit?(c) : digit?(c) }

        code = digits.to_i(hex ? 16 : 10)
        return nil if code.zero? || code > 0x10FFFF || (code >= 0xD800 && code <= 0xDFFF)

        JsonParser.encode_utf8(code)
      end
    end

    def self.digit?(c)
      c >= '0' && c <= '9'
    end

    def self.hex_digit?(c)
      digit?(c) || (c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F')
    end

    def self.ws?(c)
      c == ' ' || c == "\t" || c == "\n" || c == "\r"
    end
  end
end
