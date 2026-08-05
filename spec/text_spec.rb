RSpec.describe Ruby2D::Text do
  describe '#new' do
    context 'using pathname' do
      it 'succeeds' do
        expect do
          Text.new('hello', font: Pathname.new(Font.default))
        end.not_to raise_error
      end
    end

    it "raises exception if font file doesn't exist" do
      expect { Text.new('hello', font: 'bad_font.ttf') }.to raise_error(Ruby2D::Error)
    end

    it 'uses the system default font if one is not provided' do
      txt = Text.new('hello')
      expect(txt.font).to eq(Font.default)
    end

    it 'creates text with options' do
      txt = Text.new(
        'hello',
        x: 10, y: 20, z: 30,
        size: 40, rotate: 50,
        color: 'gray', opacity: 0.5
      )

      expect(txt.content).to eq('hello')
      expect(txt.x).to eq(10)
      expect(txt.y).to eq(20)
      expect(txt.z).to eq(30)
      expect(txt.size).to eq(40)
      expect(txt.rotate).to eq(50)
      expect(txt.color.r).to eq(2 / 3.0)
      expect(txt.opacity).to eq(0.5)
    end
  end

  describe 'color defaults' do
    it 'defaults to white' do
      txt = Text.new('hello')
      expect(txt.color).to be_a(Ruby2D::Color)
      expect(txt.color.to_a).to eq([1, 1, 1, 1])
    end
  end

  describe 'attributes' do
    it 'can be set and read' do
      txt = Text.new('hello')
      txt.x = 10
      txt.y = 20
      txt.z = 30
      txt.size = 40
      txt.rotate = 50
      txt.color = 'gray'
      txt.opacity = 0.5

      expect(txt.x).to eq(10)
      expect(txt.y).to eq(20)
      expect(txt.z).to eq(30)
      expect(txt.size).to eq(40)
      expect(txt.rotate).to eq(50)
      expect(txt.color.r).to eq(2 / 3.0)
      expect(txt.opacity).to eq(0.5)
    end
  end

  describe 'size validation' do
    it 'raises on a non-positive or non-numeric size at construction' do
      expect { Text.new('hi', size: 0) }.to raise_error(Ruby2D::Error, /positive number/)
      expect { Text.new('hi', size: -5) }.to raise_error(Ruby2D::Error)
      expect { Text.new('hi', size: 'big') }.to raise_error(Ruby2D::Error)
    end

    it 'raises when size= is set to an invalid value' do
      txt = Text.new('hi')
      expect { txt.size = 0 }.to raise_error(Ruby2D::Error)
    end
  end

  describe '#size=' do
    it 're-renders the text with new dimensions' do
      txt = Text.new('hello', size: 10)
      original_width = txt.width
      original_height = txt.height

      txt.size = 20
      expect(txt.width).to be > original_width
      expect(txt.height).to be > original_height
    end
  end

  describe 'fractional size' do
    it 'truncates to the integer size actually rendered' do
      # The native renderer uses the size as an int (truncation toward zero), so
      # the reader is stored truncated to match what's drawn.
      expect(Text.new('x', size: 10.9).size).to eq(10)
      expect(Text.new('x', size: 10.0).size).to eq(10)
      expect(Text.new('x', size: 10).size).to eq(10)
    end

    it 'truncates when size= is assigned a fractional value' do
      txt = Text.new('x', size: 20)
      txt.size = 10.9
      expect(txt.size).to eq(10)
    end
  end

  describe 'empty content' do
    it 'reports a zero width but keeps the line height' do
      txt = Text.new('')
      expect(txt.width).to eq(0)
      expect(txt.height).to be > 0
    end

    it 'collapses width to 0 when content becomes empty, and restores it' do
      txt = Text.new('hello')
      full_width = txt.width
      expect(full_width).to be > 0

      txt.content = ''
      expect(txt.width).to eq(0)

      txt.content = 'hello'
      expect(txt.width).to eq(full_width)
    end
  end

  describe 'font style' do
    it 'reads back the style it was created with' do
      expect(Text.new('hi', style: :bold).style).to eq(:bold)
    end

    it 'raises a clear error for an unknown style' do
      expect { Text.new('hi', style: :wiggly) }.to raise_error(Ruby2D::Error, /Unknown text style/)
    end

    it 'accepts an array of styles' do
      expect(Text.new('hi', style: [:bold, :italic]).style).to eq([:bold, :italic])
    end

    it 'applies bold (wider than normal) and can be changed after creation' do
      normal = Text.new('Wide Wide Wide')
      bold   = Text.new('Wide Wide Wide', style: :bold)
      expect(bold.width).to be > normal.width

      normal.style = :bold
      expect(normal.width).to eq(bold.width)
    end
  end

  describe '#font=' do
    it 're-renders when the font changes' do
      txt = Text.new('hello')
      expect { txt.font = Font.default }.not_to raise_error
    end

    it 'raises for a missing font file' do
      txt = Text.new('hello')
      expect { txt.font = 'nope.ttf' }.to raise_error(Ruby2D::Error)
    end
  end

  describe '#content=' do
    it 'maps Time to string' do
      txt = Text.new('hello')
      txt.content = Time.new(1, 1, 1, 1, 1, 1, 1)
      expect(txt.content).to eq('0001-01-01 01:01:01 +0000')
    end

    it 'maps Number to string' do
      txt = Text.new('hello')
      txt.content = 0
      expect(txt.content).to eq('0')
    end

    it 'skips the texture rebuild when the content is unchanged' do
      txt = Text.new('hello')
      expect(Ruby2D::Ext).not_to receive(:text_create)
      txt.content = 'hello'
    end

    it 'still rebuilds when the content changes' do
      txt = Text.new('hello')
      expect(Ruby2D::Ext).to receive(:text_create).with(txt)
      txt.content = 'world'
    end

    it 'still raises on invalid content even when the text is unchanged-looking' do
      txt = Text.new('hello')
      expect { txt.content = "hel\0lo" }.to raise_error(Ruby2D::Error, /NUL/)
    end
  end

  # The sibling setters share content='s no-op contract: assigning the value
  # the text already has must not rebuild the texture.
  describe 'unchanged-value setters' do
    it 'skips the texture rebuild when the size is unchanged' do
      txt = Text.new('hello', size: 24)
      expect(Ruby2D::Ext).not_to receive(:text_create)
      txt.size = 24
    end

    it 'still rebuilds when the size changes' do
      txt = Text.new('hello', size: 24)
      expect(Ruby2D::Ext).to receive(:text_create).with(txt)
      txt.size = 32
    end

    it 'skips the texture rebuild when the style flags are unchanged' do
      txt = Text.new('hello', style: :bold)
      expect(Ruby2D::Ext).not_to receive(:text_create)
      txt.style = [:bold]
      expect(txt.style).to eq([:bold])
    end

    it 'still rebuilds when the style changes' do
      txt = Text.new('hello', style: :bold)
      expect(Ruby2D::Ext).to receive(:text_create).with(txt)
      txt.style = %i[bold italic]
    end

    it 'skips the texture rebuild when the font is unchanged' do
      txt = Text.new('hello')
      expect(Ruby2D::Ext).not_to receive(:text_create)
      txt.font = txt.font
    end
  end

  describe 'content immutability' do
    it 'rejects in-place mutation so native state cannot desync' do
      txt = Text.new('hello')
      expect { txt.content << 'x' }.to raise_error(FrozenError)
    end

    it 'still updates (and re-renders) via content=' do
      txt = Text.new('hello')
      original_width = txt.width
      txt.content = 'Hello world!'
      expect(txt.content).to eq('Hello world!')
      expect(txt.width).not_to eq(original_width)
    end

    it 'never freezes the caller-supplied string' do
      str = +'hello'
      Text.new(str)
      expect(str).not_to be_frozen
    end
  end

  describe 'embedded NUL content' do
    it 'is rejected rather than silently truncated or passed to the rasterizer' do
      # NUL has no glyph and SDL_ttf cannot render it (it hangs on U+0000), while
      # silently truncating at the NUL would hide the caller's corrupt data. Fail
      # loudly instead, in both the constructor and the content= setter.
      expect { Text.new("a\0bc") }.to raise_error(Ruby2D::Error, /NUL/)
      txt = Text.new('ok')
      expect { txt.content = "x\0y" }.to raise_error(Ruby2D::Error, /NUL/)
    end
  end

  describe '#width' do
    it 'is known after creation' do
      txt = Text.new('Hello Ruby!')
      expect(txt.width).to be_between(95, 105)
    end

    it 'is known after updating' do
      txt = Text.new('hello')
      txt.content = 'Hello!'
      expect(txt.width).to be_between(47, 55)
    end
  end

  describe '#height' do
    it 'is known after creation' do
      txt = Text.new('hello')
      expect(txt.height).to be_between(23, 27)
    end

    it 'is known after updating' do
      txt = Text.new('hello')
      txt.content = 'Good morning world!'
      expect(txt.height).to be_between(23, 27)
    end
  end

  describe '#contains?' do
    it 'returns true if point is inside the text' do
      txt = Text.new('hello')
      txt.content = 'Hello world!'
      expect(txt.contains?(txt.width / 2, txt.height / 2)).to be true
    end

    it 'returns false if point is outside the text' do
      txt = Text.new('hello')
      txt.content = 'Hello world!'
      expect(txt.contains?(- txt.width / 2, txt.height / 2)).to be false
      expect(txt.contains?(txt.width / 2, - txt.height / 2)).to be false
      expect(txt.contains?(3 * txt.width / 2, txt.height / 2)).to be false
      expect(txt.contains?(txt.width / 2, 3 * txt.height / 2)).to be false
    end
  end

  describe 'multiline content' do
    it 'lays out embedded newlines as separate lines' do
      one = Text.new('a', size: 20)
      two = Text.new("a\nb", size: 20)
      # Two stacked lines are clearly taller than one. (The old single-line
      # renderer drew "a\nb" as one garbled line of roughly equal height.)
      expect(two.height).to be > (one.height * 1.5)
    end
  end

  describe 'font cache exhaustion' do
    it 'still loads fonts when more than the cache limit are simultaneously live' do
      # The native font cache holds 128 entries. With 150 distinct sizes all
      # referenced by live Text objects, the ones past the limit must still
      # load (via a standalone fallback) instead of raising a spurious error.
      texts = (10..159).map { |s| Text.new('x', size: s) }
      expect(texts.length).to eq(150)
      expect(texts.last.width).to be > 0
    end
  end
end
