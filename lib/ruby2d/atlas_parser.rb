# Ruby2D::AtlasParser

module Ruby2D
  # Internal parser for sprite-sheet atlas files. Reads either Sparrow XML or
  # TexturePacker JSON (Hash or Array variants) and returns a uniform shape:
  #
  #     { image_path: 'sheet.png',
  #       frames: { 'frame_name' => { x:, y:, width:, height: }, ... } }
  #
  # Hand-written and Regexp-free so it works on mruby builds without the
  # regex mrbgem.
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
      atlas_attrs = find_tags(str, 'TextureAtlas').first
      image_path = atlas_attrs && parse_xml_attrs(atlas_attrs)['imagePath']

      frames = {}
      find_tags(str, 'SubTexture').each do |attrs_str|
        attrs = parse_xml_attrs(attrs_str)
        name = attrs['name']
        next unless name

        rect = {
          x: (attrs['x'] || '0').to_i,
          y: (attrs['y'] || '0').to_i,
          width: (attrs['width'] || '0').to_i,
          height: (attrs['height'] || '0').to_i
        }
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
        frames[name] = rect
      end

      { image_path: image_path, frames: frames }
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

    # Locate every `<TagName ...>` (or `<TagName ... />`) opening tag in `str`
    # and return the inner attribute strings, in document order.
    def self.find_tags(str, tag_name)
      results = []
      marker = "<#{tag_name}"
      marker_len = marker.length
      i = 0
      while (pos = str.index(marker, i))
        after_idx = pos + marker_len
        after = str[after_idx]
        # Confirm this is the right tag boundary (not a longer name like
        # `<TextureAtlasFoo`)
        if after && (ws?(after) || after == '>' || after == '/')
          end_pos = str.index('>', after_idx)
          break unless end_pos

          attrs_str = str[after_idx...end_pos]
          # Drop the trailing slash from self-closing tags.
          attrs_str = attrs_str[0...-1] if attrs_str.end_with?('/')
          results << attrs_str
          i = end_pos + 1
        else
          i = pos + 1
        end
      end
      results
    end

    # Parse `name="value"` (or `name='value'`) attributes out of an XML tag's
    # attribute string. Tolerates extra whitespace between tokens.
    def self.parse_xml_attrs(str)
      attrs = {}
      return attrs unless str

      i = 0
      len = str.length
      while i < len
        i += 1 while i < len && ws?(str[i])
        break if i >= len

        name_start = i
        i += 1 while i < len && str[i] != '=' && !ws?(str[i])
        name = str[name_start...i]

        i += 1 while i < len && ws?(str[i])
        break unless i < len && str[i] == '='

        i += 1
        i += 1 while i < len && ws?(str[i])
        break unless i < len

        quote = str[i]
        break unless quote == '"' || quote == "'"

        i += 1
        val_start = i
        i += 1 while i < len && str[i] != quote
        attrs[name] = str[val_start...i]
        i += 1 if i < len
      end
      attrs
    end

    def self.ws?(c)
      c == ' ' || c == "\t" || c == "\n" || c == "\r"
    end
  end
end
