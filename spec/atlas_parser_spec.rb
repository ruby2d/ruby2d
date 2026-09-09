require 'tempfile'

RSpec.describe Ruby2D::AtlasParser do
  describe '.parse_xml' do
    it 'parses a Sparrow-format atlas with imagePath and frames' do
      xml = <<~XML
        <TextureAtlas imagePath="sheet.png">
          <SubTexture name="char_idle" x="0" y="0" width="32" height="48"/>
          <SubTexture name="char_walk_a" x="32" y="0" width="32" height="48"/>
          <SubTexture name="char_walk_b" x="64" y="0" width="32" height="48"/>
        </TextureAtlas>
      XML

      result = described_class.parse_xml(xml)
      expect(result[:image_path]).to eq('sheet.png')
      expect(result[:frames].keys).to eq(%w[char_idle char_walk_a char_walk_b])
      expect(result[:frames]['char_walk_a']).to eq(x: 32, y: 0, width: 32, height: 48)
    end

    it 'tolerates extra whitespace and attribute reordering' do
      xml = '<TextureAtlas    imagePath = "x.png" >' \
            "\n  <SubTexture y = \"5\"   name=\"a\" height=\"7\" x=\"3\" width=\"6\"   />\n" \
            '</TextureAtlas>'
      result = described_class.parse_xml(xml)
      expect(result[:image_path]).to eq('x.png')
      expect(result[:frames]['a']).to eq(x: 3, y: 5, width: 6, height: 7)
    end

    it 'accepts single-quoted attribute values' do
      xml = "<TextureAtlas imagePath='s.png'><SubTexture name='a' x='0' y='0' width='1' height='2'/></TextureAtlas>"
      result = described_class.parse_xml(xml)
      expect(result[:image_path]).to eq('s.png')
      expect(result[:frames]['a']).to eq(x: 0, y: 0, width: 1, height: 2)
    end

    it 'returns no frames when input is empty' do
      result = described_class.parse_xml('<TextureAtlas imagePath="x.png"></TextureAtlas>')
      expect(result[:frames]).to eq({})
    end

    it 'extracts trim metadata from extended Sparrow attrs' do
      xml = <<~XML
        <TextureAtlas imagePath="s.png">
          <SubTexture name="trimmed" x="0" y="0" width="80" height="120"
                      frameX="-40" frameY="-70" frameWidth="256" frameHeight="256"/>
          <SubTexture name="untrimmed" x="80" y="0" width="32" height="32"/>
        </TextureAtlas>
      XML
      result = described_class.parse_xml(xml)

      trimmed = result[:frames]['trimmed']
      expect(trimmed[:source_width]).to eq(256)
      expect(trimmed[:source_height]).to eq(256)
      expect(trimmed[:trim_x]).to eq(40)   # negated frameX
      expect(trimmed[:trim_y]).to eq(70)

      untrimmed = result[:frames]['untrimmed']
      expect(untrimmed).not_to include(:source_width, :trim_x)
    end

    it 'flags rotated frames and omits the key for unrotated ones, like the JSON path' do
      xml = '<TextureAtlas imagePath="s.png">' \
            '<SubTexture name="hero" x="0" y="0" width="4" height="8" rotated="true"/>' \
            '<SubTexture name="flat" x="0" y="0" width="4" height="8" rotated="false"/>' \
            '<SubTexture name="plain" x="0" y="0" width="4" height="8"/>' \
            '</TextureAtlas>'
      frames = described_class.parse_xml(xml)[:frames]
      expect(frames['hero']).to eq(x: 0, y: 0, width: 4, height: 8, rotated: true)
      expect(frames['flat']).not_to include(:rotated)
      expect(frames['plain']).not_to include(:rotated)
    end

    it 'decodes the predefined entities and numeric character references in attribute values' do
      xml = '<TextureAtlas imagePath="a&amp;b.png">' \
            '<SubTexture name="a&amp;b" x="0" y="0" width="1" height="1"/>' \
            '<SubTexture name="q&quot;s&apos;lt&lt;gt&gt;" x="0" y="0" width="1" height="1"/>' \
            '<SubTexture name="num&#65;&#x42;&#x1F600;" x="0" y="0" width="1" height="1"/>' \
            '</TextureAtlas>'
      result = described_class.parse_xml(xml)
      expect(result[:image_path]).to eq('a&b.png')
      expect(result[:frames].keys).to eq(['a&b', %q(q"s'lt<gt>), "numAB\u{1F600}"])
    end

    it 'leaves a reference it cannot resolve as written' do
      xml = '<TextureAtlas imagePath="s.png">' \
            '<SubTexture name="keep&bogus;&#;&#xZZ;&#0;&#xD800;&" x="0" y="0" width="1" height="1"/>' \
            '</TextureAtlas>'
      expect(described_class.parse_xml(xml)[:frames].keys).to eq(['keep&bogus;&#;&#xZZ;&#0;&#xD800;&'])
    end

    it 'skips frames inside comments, CDATA sections, processing instructions, and the DOCTYPE' do
      xml = <<~XML
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE TextureAtlas [ <!ELEMENT SubTexture EMPTY> ]>
        <!-- <TextureAtlas imagePath="wrong.png"> -->
        <TextureAtlas imagePath="sheet.png">
          <SubTexture name="idle" x="0" y="0" width="8" height="8" />
          <!-- Old frame, retained as a comment:
            <SubTexture name="idle" x="32" y="32" width="64" height="64" />
            <SubTexture name="deleted" x="0" y="0" width="4" height="4" />
          -->
          <![CDATA[ <SubTexture name="cdata" x="1" y="1" width="1" height="1"/> ]]>
          <?pi <SubTexture name="pi" x="1" y="1" width="1" height="1"/> ?>
        </TextureAtlas>
      XML
      result = described_class.parse_xml(xml)
      expect(result[:image_path]).to eq('sheet.png')
      expect(result[:frames]).to eq('idle' => { x: 0, y: 0, width: 8, height: 8 })
    end

    it 'skips a DOCTYPE whose quoted literals or comments contain brackets, quotes, or >' do
      xml = <<~XML
        <!DOCTYPE TextureAtlas SYSTEM "a[b.dtd">
        <TextureAtlas imagePath="s.png">
          <SubTexture name="arr]x" x="1" y="2" width="3" height="4"/>
        </TextureAtlas>
      XML
      expect(described_class.parse_xml(xml)).to eq(
        image_path: 's.png', frames: { 'arr]x' => { x: 1, y: 2, width: 3, height: 4 } }
      )

      xml = <<~XML
        <!DOCTYPE TextureAtlas [
          <!ENTITY a "]">
          <!ENTITY b "<A/><SubTexture name='ghost' x='9' y='9' width='9' height='9'/>">
        ]>
        <TextureAtlas imagePath="s.png"><SubTexture name="a" x="1" y="2" width="3" height="4"/></TextureAtlas>
      XML
      expect(described_class.parse_xml(xml)[:frames].keys).to eq(['a'])

      xml = <<~XML
        <!DOCTYPE TextureAtlas [
          <!-- don't edit; see [1 -->
          <!ELEMENT SubTexture EMPTY>
        ]>
        <TextureAtlas imagePath="s.png"><SubTexture name="a" x="1" y="2" width="3" height="4"/></TextureAtlas>
      XML
      expect(described_class.parse_xml(xml)[:frames].keys).to eq(['a'])
    end

    it 'decodes a reference beside a raw non-ASCII byte whatever the source string is tagged' do
      value = "caf\xE9&#233;.png".b
      xml = "<TextureAtlas imagePath=\"#{value}\"/>".b
      expect(described_class.parse_xml(xml)[:image_path]).to eq("caf\xE9é.png".b.force_encoding('UTF-8'))
    end

    it 'keeps a quoted > or /> as part of the attribute value' do
      xml = "<TextureAtlas note='a>\"b' imagePath=\"s.png\">" \
            '<SubTexture name="power>idle" x="16" y="8" width="24" height="32"/>' \
            "<SubTexture name='x/>y' x=\"1\" y=\"2\" width=\"3\" height=\"4\" />" \
            '</TextureAtlas>'
      result = described_class.parse_xml(xml)
      expect(result[:image_path]).to eq('s.png')
      expect(result[:frames]).to eq(
        'power>idle' => { x: 16, y: 8, width: 24, height: 32 },
        'x/>y' => { x: 1, y: 2, width: 3, height: 4 }
      )
    end

    it 'raises ParseError on an unterminated attribute value, tag, or comment instead of a truncated frame' do
      base = '<TextureAtlas imagePath="s.png">%s</TextureAtlas>'
      [
        '<SubTexture name="oops x="1"/>',
        '<SubTexture name="oops',
        '<SubTexture name="a" selected x="1"/>',
        '<!-- <SubTexture name="a" x="1"/>'
      ].each do |markup|
        expect { described_class.parse_xml(format(base, markup)) }
          .to raise_error(described_class::ParseError), markup
      end
      expect { described_class.parse_xml('<SubTexture name="a" x="1"') }
        .to raise_error(described_class::ParseError, /Unterminated tag/)
    end
  end

  describe '.parse_json (TexturePacker Hash form)' do
    it 'raises ParseError when the top-level value is not an object' do
      expect { described_class.parse_json('[1, 2, 3]') }.to raise_error(described_class::ParseError)
      expect { described_class.parse_json('42') }.to raise_error(described_class::ParseError)
      expect { described_class.parse_json('null') }.to raise_error(described_class::ParseError)
    end

    it 'parses frames as an object keyed by name' do
      json = <<~JSON
        {
          "frames": {
            "char_idle": {
              "frame": {"x":0,"y":0,"w":32,"h":48},
              "rotated": false,
              "trimmed": false
            },
            "char_walk_a": {
              "frame": {"x":32,"y":0,"w":32,"h":48}
            }
          },
          "meta": { "image": "sheet.png", "size": {"w":256,"h":256} }
        }
      JSON

      result = described_class.parse_json(json)
      expect(result[:image_path]).to eq('sheet.png')
      expect(result[:frames]['char_idle']).to eq(x: 0, y: 0, width: 32, height: 48)
      expect(result[:frames]['char_walk_a']).to eq(x: 32, y: 0, width: 32, height: 48)
    end

    it 'flags rotated frames and omits the key for unrotated ones' do
      json = <<~JSON
        {
          "frames": {
            "a": { "frame": {"x":0,"y":0,"w":4,"h":4}, "rotated": true },
            "b": { "frame": {"x":8,"y":0,"w":4,"h":4}, "rotated": false }
          },
          "meta": { "image": "s.png" }
        }
      JSON

      result = described_class.parse_json(json)
      expect(result[:frames]['a'][:rotated]).to be true
      expect(result[:frames]['b']).not_to include(:rotated)
    end

    it 'extracts trim metadata from sourceSize and spriteSourceSize' do
      json = <<~JSON
        {
          "frames": {
            "trimmed": {
              "frame": {"x":0,"y":0,"w":80,"h":120},
              "spriteSourceSize": {"x":40,"y":70,"w":80,"h":120},
              "sourceSize": {"w":256,"h":256}
            },
            "untrimmed": {
              "frame": {"x":80,"y":0,"w":32,"h":32}
            }
          },
          "meta": { "image": "s.png" }
        }
      JSON

      result = described_class.parse_json(json)
      trimmed = result[:frames]['trimmed']
      expect(trimmed[:source_width]).to eq(256)
      expect(trimmed[:source_height]).to eq(256)
      expect(trimmed[:trim_x]).to eq(40)
      expect(trimmed[:trim_y]).to eq(70)

      untrimmed = result[:frames]['untrimmed']
      expect(untrimmed).not_to include(:source_width, :trim_x)
    end
  end

  describe '.parse_json (TexturePacker Array form)' do
    it 'parses frames as an array with filename keys' do
      json = <<~JSON
        {
          "frames": [
            { "filename": "a", "frame": {"x":0,"y":0,"w":1,"h":2} },
            { "filename": "b", "frame": {"x":3,"y":4,"w":5,"h":6} }
          ],
          "meta": { "image": "s.png" }
        }
      JSON

      result = described_class.parse_json(json)
      expect(result[:image_path]).to eq('s.png')
      expect(result[:frames]['a']).to eq(x: 0, y: 0, width: 1, height: 2)
      expect(result[:frames]['b']).to eq(x: 3, y: 4, width: 5, height: 6)
    end

    it 'raises when frames is missing' do
      expect { described_class.parse_json('{"meta": {}}') }
        .to raise_error(described_class::ParseError)
    end
  end

  describe '.parse_file' do
    let(:sheets_dir) { Ruby2D.test_spritesheets }

    it 'parses bundled Sparrow XML fixtures' do
      result = described_class.parse_file("#{sheets_dir}/spritesheet.xml")
      expect(result[:image_path]).to eq('spritesheet.png')
      expect(result[:frames]).not_to be_empty
      expect(result[:frames]['block_blue']).to eq(x: 0, y: 0, width: 128, height: 128)
    end

    it 'dispatches by file extension' do
      tmp = Tempfile.new(['atlas', '.json'])
      tmp.write('{"frames":{"a":{"frame":{"x":0,"y":0,"w":1,"h":1}}},"meta":{"image":"x.png"}}')
      tmp.close
      result = described_class.parse_file(tmp.path)
      expect(result[:image_path]).to eq('x.png')
      expect(result[:frames]['a']).to eq(x: 0, y: 0, width: 1, height: 1)
    ensure
      tmp&.unlink
    end

    it 'sniffs format from content when extension is unrecognized' do
      tmp = Tempfile.new(['atlas', '.txt'])
      tmp.write('<TextureAtlas imagePath="x.png"><SubTexture name="a" x="0" y="0" width="1" height="2"/></TextureAtlas>')
      tmp.close
      result = described_class.parse_file(tmp.path)
      expect(result[:image_path]).to eq('x.png')
      expect(result[:frames]['a']).to eq(x: 0, y: 0, width: 1, height: 2)
    ensure
      tmp&.unlink
    end
  end
end
