require 'ruby2d/cli/browser'

RSpec.describe Ruby2D::CLI::Browser do
  describe '.classify_escape' do
    it 'maps arrow and navigation sequences to actions' do
      expect(described_class.classify_escape('[A')).to eq(:up)
      expect(described_class.classify_escape('OA')).to eq(:up)
      expect(described_class.classify_escape('[B')).to eq(:down)
      expect(described_class.classify_escape('[H')).to eq(:home)
      expect(described_class.classify_escape('[F')).to eq(:last)
      expect(described_class.classify_escape('[5~')).to eq(:pgup)
      expect(described_class.classify_escape('[6~')).to eq(:pgdn)
    end

    it 'treats a bare ESC (empty sequence) as :quit' do
      expect(described_class.classify_escape('')).to eq(:quit)
    end

    it 'ignores mouse-reporting sequences (returns nil, not a navigation action)' do
      expect(described_class.classify_escape('[<0;1;1M')).to be_nil
      expect(described_class.classify_escape('[<0;1;1m')).to be_nil
      expect(described_class.classify_escape('[M abc')).to be_nil
    end

    it 'returns nil for an unrecognized sequence' do
      expect(described_class.classify_escape('[Z')).to be_nil
    end
  end

  describe '.classify_char' do
    it 'maps j/k and g/G to navigation and Enter/q/Ctrl-C/Ctrl-D to control' do
      expect(described_class.classify_char('k')).to eq(:up)
      expect(described_class.classify_char('j')).to eq(:down)
      expect(described_class.classify_char('g')).to eq(:home)
      expect(described_class.classify_char('G')).to eq(:last)
      expect(described_class.classify_char("\r")).to eq(:enter)
      expect(described_class.classify_char("\n")).to eq(:enter)
      expect(described_class.classify_char('q')).to eq(:quit)
      expect(described_class.classify_char("\x03")).to eq(:quit)
      expect(described_class.classify_char("\x04")).to eq(:quit)
    end

    it 'returns nil for an unmapped byte' do
      expect(described_class.classify_char('x')).to be_nil
    end
  end

  describe '.classify_scancode' do
    it 'maps Windows scan codes to navigation actions' do
      expect(described_class.classify_scancode('H')).to eq(:up)
      expect(described_class.classify_scancode('P')).to eq(:down)
      expect(described_class.classify_scancode('I')).to eq(:pgup)
      expect(described_class.classify_scancode('Q')).to eq(:pgdn)
      expect(described_class.classify_scancode('G')).to eq(:home)
      expect(described_class.classify_scancode('O')).to eq(:last)
    end

    it 'returns nil for an unmapped scan code (e.g. Left arrow, unused)' do
      expect(described_class.classify_scancode('K')).to be_nil
    end
  end

  describe '.wrap' do
    it 'returns [] for empty text or non-positive width' do
      expect(described_class.wrap('', 10)).to eq([])
      expect(described_class.wrap(nil, 10)).to eq([])
      expect(described_class.wrap('hi', 0)).to eq([])
    end

    it 'keeps text that fits on a single line' do
      expect(described_class.wrap('a b c', 10)).to eq(['a b c'])
    end

    it 'wraps greedily at the width boundary' do
      expect(described_class.wrap('aaa bbb ccc', 7)).to eq(['aaa bbb', 'ccc'])
    end

    it 'puts a word longer than the width on its own line' do
      expect(described_class.wrap('a bbbbbbbb c', 4)).to eq(['a', 'bbbbbbbb', 'c'])
    end
  end
end
