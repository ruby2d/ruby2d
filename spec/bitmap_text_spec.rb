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
      expect { BitmapText.new('hi', scale: 0) }.to raise_error(Ruby2D::Error, /positive number/)
      expect { BitmapText.new('hi', scale: -2) }.to raise_error(Ruby2D::Error, /positive number/)
      expect { BitmapText.new('hi', scale: 'big') }.to raise_error(Ruby2D::Error, /positive number/)
    end

    it 'rejects a non-positive scale assigned after construction' do
      bt = BitmapText.new('hi')
      expect { bt.scale = 0 }.to raise_error(Ruby2D::Error, /positive number/)
      expect { bt.scale = -1 }.to raise_error(Ruby2D::Error, /positive number/)
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
    it 'sizes one cell per byte instead of silently dropping unsupported characters' do
      # 'café' is 5 UTF-8 bytes (the é is two), each drawn as a glyph or a
      # placeholder — so its width matches a 5-character ASCII string, not the
      # 3 it would report if non-ASCII bytes were dropped from the count.
      accented = BitmapText.new('café', scale: 3)
      ascii5   = BitmapText.new('abcde', scale: 3)
      expect(accented.width).to eq(ascii5.width)
      expect(accented.width).to be > BitmapText.new('caf', scale: 3).width
    end
  end
end
