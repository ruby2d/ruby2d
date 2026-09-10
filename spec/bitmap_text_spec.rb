RSpec.describe Ruby2D::BitmapText do
  # BitmapText takes content as a positional arg; pass it via constructor wrapper.
  # The shared examples wrap kwargs only, so we test color defaults inline here.
  describe 'color defaults' do
    it 'defaults to white' do
      bt = BitmapText.new('hello')
      expect(bt.color).to be_a(Ruby2D::Color)
      expect(bt.color.to_a).to eq([1, 1, 1, 1])
    end

    it 'accepts color: and opacity: kwargs' do
      bt = BitmapText.new('hello', color: 'gray', opacity: 0.5)
      expect(bt.color.r).to eq(2 / 3.0)
      expect(bt.opacity).to eq(0.5)
    end
  end

  describe '#new' do
    it 'creates bitmap text with default values' do
      bt = BitmapText.new('hello')
      expect(bt.content).to eq('hello')
      expect(bt.x).to eq(0)
      expect(bt.y).to eq(0)
      expect(bt.z).to eq(0)
      expect(bt.scale).to eq(3)
    end

    it 'creates bitmap text with options' do
      bt = BitmapText.new(
        'hello',
        x: 10, y: 20, z: 30,
        scale: 5, rotate: 45
      )

      expect(bt.content).to eq('hello')
      expect(bt.x).to eq(10)
      expect(bt.y).to eq(20)
      expect(bt.z).to eq(30)
      expect(bt.scale).to eq(5)
      expect(bt.rotate).to eq(45)
    end

    it 'rejects a symbolic position (no alignment support) up front' do
      expect { BitmapText.new('hello', x: :center) }.to raise_error(Ruby2D::Error, /must be a number/)
      expect { BitmapText.new('hello', y: :top) }.to raise_error(Ruby2D::Error, /must be a number/)
    end

    it 'rejects a symbolic position assigned after construction' do
      bt = BitmapText.new('hello')
      expect { bt.x = :center }.to raise_error(Ruby2D::Error, /must be a number/)
    end
  end

  describe 'rotation' do
    it 'defaults the rotation center to the text center' do
      bt = BitmapText.new('hello', x: 10, y: 20)
      expect(bt.rx).to eq(10 + bt.width / 2.0)
      expect(bt.ry).to eq(20 + bt.height / 2.0)
    end

    it 'honors an explicit rotation center' do
      bt = BitmapText.new('hello', x: 10, y: 20, rx: 0, ry: 0)
      expect(bt.rx).to eq(0)
      expect(bt.ry).to eq(0)
    end

    it 'exposes rotate and rx/ry as settable attributes' do
      bt = BitmapText.new('hello')
      bt.rotate = 90
      bt.rx = 5
      bt.ry = 7
      expect(bt.rotate).to eq(90)
      expect(bt.rx).to eq(5)
      expect(bt.ry).to eq(7)
    end
  end

  describe 'attributes' do
    it 'can be set and read' do
      bt = BitmapText.new('hello')
      bt.x = 10
      bt.y = 20
      bt.z = 30
      bt.color = 'gray'
      bt.opacity = 0.5

      expect(bt.x).to eq(10)
      expect(bt.y).to eq(20)
      expect(bt.z).to eq(30)
      expect(bt.color.r).to eq(2 / 3.0)
      expect(bt.opacity).to eq(0.5)
    end
  end

  describe '#content=' do
    it 'maps Number to string' do
      bt = BitmapText.new('hello')
      bt.content = 42
      expect(bt.content).to eq('42')
    end

    it 'updates dimensions when text changes' do
      bt = BitmapText.new('hi')
      short_width = bt.width

      bt.content = 'hello world'
      expect(bt.width).to be > short_width
    end

    it 'skips the texture rebuild when the content is unchanged' do
      bt = BitmapText.new('hello')
      expect(Ruby2D::Ext).not_to receive(:bitmap_text_create)
      bt.content = 'hello'
    end

    it 'still rebuilds when the content changes' do
      bt = BitmapText.new('hello')
      expect(Ruby2D::Ext).to receive(:bitmap_text_create).with(bt)
      bt.content = 'world'
    end
  end

  describe '#scale=' do
    it 'updates dimensions when scale changes' do
      bt = BitmapText.new('hello', scale: 2)
      small_width = bt.width
      small_height = bt.height

      bt.scale = 4
      expect(bt.width).to be > small_width
      expect(bt.height).to be > small_height
    end

    it 'skips the texture rebuild when the scale is unchanged' do
      bt = BitmapText.new('hello', scale: 2)
      expect(Ruby2D::Ext).not_to receive(:bitmap_text_create)
      bt.scale = 2
    end

    it 'still rebuilds when the scale changes' do
      bt = BitmapText.new('hello', scale: 2)
      expect(Ruby2D::Ext).to receive(:bitmap_text_create).with(bt)
      bt.scale = 3
    end
  end

  describe 'scale validation' do
    it 'rejects a non-positive or non-numeric scale in the constructor' do
      expect { BitmapText.new('hi', scale: 0) }.to raise_error(Ruby2D::Error, /at least 1/)
      expect { BitmapText.new('hi', scale: 0.5) }.to raise_error(Ruby2D::Error, /at least 1/)
      expect { BitmapText.new('hi', scale: -2) }.to raise_error(Ruby2D::Error, /at least 1/)
      expect { BitmapText.new('hi', scale: 'big') }.to raise_error(Ruby2D::Error, /at least 1/)
    end

    it 'rejects a scale below 1 assigned after construction' do
      bt = BitmapText.new('hi')
      expect { bt.scale = 0 }.to raise_error(Ruby2D::Error, /at least 1/)
      expect { bt.scale = -1 }.to raise_error(Ruby2D::Error, /at least 1/)
    end

    it 'rejects an infinite scale with the same error' do
      expect { BitmapText.new('hi', scale: Float::INFINITY) }.to raise_error(Ruby2D::Error, /at least 1/)
    end

    it 'restores the scale and content when the native call raises' do
      bt = BitmapText.new('hi', scale: 3)
      expect { bt.scale = 2**31 }.to raise_error(RangeError)
      expect(bt.scale).to eq(3)

      allow(Ruby2D::Ext).to receive(:bitmap_text_create).and_raise(Ruby2D::Error, 'boom')
      expect { bt.content = 'changed' }.to raise_error(Ruby2D::Error, 'boom')
      expect(bt.content).to eq('hi')
    end

    it 'truncates a float scale to the integer the renderer uses' do
      expect(BitmapText.new('hi', scale: 2.9).scale).to eq(2)
      bt = BitmapText.new('hi', scale: 3)
      bt.scale = 4.9
      expect(bt.scale).to eq(4)
    end
  end

  describe '#width' do
    it 'is known after creation' do
      bt = BitmapText.new('Hello', scale: 3)
      # 5 chars: 5 * (5 * 3) + 4 * 3 = 75 + 12 = 87
      expect(bt.width).to eq(87)
    end

    it 'is 0 for empty content, with the glyph height preserved' do
      bt = BitmapText.new('', scale: 3)
      expect(bt.width).to eq(0)
      expect(bt.height).to eq(21) # 7 * 3

      bt.content = 'Hi'
      expect(bt.width).to be > 0

      bt.content = ''
      expect(bt.width).to eq(0)
    end
  end

  describe '#height' do
    it 'is known after creation' do
      bt = BitmapText.new('Hello', scale: 3)
      # 7 * 3 = 21
      expect(bt.height).to eq(21)
    end
  end

  describe '#contains?' do
    it 'returns true if point is inside the text' do
      bt = BitmapText.new('Hello', x: 0, y: 0, scale: 3)
      expect(bt.contains?(bt.width / 2, bt.height / 2)).to be true
    end

    it 'returns false if point is outside the text' do
      bt = BitmapText.new('Hello', x: 0, y: 0, scale: 3)
      expect(bt.contains?(-1, bt.height / 2)).to be false
      expect(bt.contains?(bt.width + 1, bt.height / 2)).to be false
    end
  end

  describe 'non-ASCII content' do
    it 'draws one placeholder cell per character, not per UTF-8 byte' do
      one_placeholder = BitmapText.new('A?B', scale: 3).width
      expect(BitmapText.new('AéB', scale: 3).width).to eq(one_placeholder)  # 2 bytes
      expect(BitmapText.new('A界B', scale: 3).width).to eq(one_placeholder) # 3 bytes
      expect(BitmapText.new('A🚀B', scale: 3).width).to eq(one_placeholder) # 4 bytes
      expect(BitmapText.new('A??B', scale: 3).width).to be > one_placeholder
    end

    it 'does not drop unsupported characters from the count' do
      expect(BitmapText.new('café', scale: 3).width).to eq(BitmapText.new('cafe', scale: 3).width)
    end

    it 'gives a malformed byte a cell of its own, so nothing vanishes' do
      placeholder = BitmapText.new('A?B', scale: 3).width
      expect(BitmapText.new("A\xFFB".b, scale: 3).width).to eq(placeholder)
      # A lead byte without its continuation is one cell, then the letter
      expect(BitmapText.new("A\xC3B".b, scale: 3).width).to eq(placeholder)
      expect(BitmapText.new("A\xC3".b, scale: 3).width).to eq(BitmapText.new('A?', scale: 3).width)
    end
  end

  describe 'embedded NUL content' do
    it 'is rejected in the constructor and content=, as with Text' do
      # The native side reads the string to its terminator, so a NUL silently
      # cut off everything after it instead of drawing a placeholder.
      expect { BitmapText.new("A\0B") }.to raise_error(Ruby2D::Error, /NUL/)
      bt = BitmapText.new('AB')
      expect { bt.content = "A\0BC" }.to raise_error(Ruby2D::Error, /NUL/)
      expect(bt.content).to eq('AB')
    end
  end

  describe 'content immutability' do
    it 'owns a copy, so a caller mutating its string cannot desync the dimensions' do
      content = +'A'
      bt = BitmapText.new(content, scale: 1)
      content << 'BCD'
      expect(bt.content).to eq('A')

      # Assigning the grown buffer back is a real change, measured afresh
      bt.content = content
      expect(bt.content).to eq('ABCD')
      expect(bt.width).to eq(BitmapText.new('ABCD', scale: 1).width)
    end

    it 'rejects in-place mutation so native state cannot desync' do
      expect { BitmapText.new('hi').content << 'x' }.to raise_error(FrozenError)
    end

    it 'never freezes the caller-supplied string' do
      str = +'hello'
      BitmapText.new(str)
      expect(str).not_to be_frozen
    end
  end
end
