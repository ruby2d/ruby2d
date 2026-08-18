# Ruby 2D owns the keyboard's name vocabulary rather than passing through
# SDL's display names. These specs pin the properties that made owning it
# worth doing: every key has one clean symbol, names never vary by platform,
# and a name outside the vocabulary raises instead of silently never matching.
RSpec.describe Ruby2D::Keyboard do
  describe 'the vocabulary' do
    it 'comes from the extension, so the name table has one home' do
      expect(described_class.names).to match_array(Ruby2D::Ext.key_names)
    end

    it 'holds no scancodes — Ruby never sees one' do
      expect(described_class.constants).not_to include(:SCANCODES, :NAMES)
      expect(described_class).not_to respond_to(:key_name)
    end

    it 'names every key as a bare symbol needing no quoting' do
      bad = described_class.names.reject { |s| s.to_s =~ /\A[a-z][a-z0-9_]*\z/ }
      expect(bad).to be_empty
    end

    it 'covers the whole keyboard, not just the common keys' do
      expect(described_class.names.size).to be > 200
      expect(described_class.names)
        .to include(:a, :space, :left_shift, :digit_1, :keypad_plus, :f24, :ac_back)
    end

    it 'separates the two scancodes SDL both calls "Return"' do
      expect(described_class.names).to include(:return, :return2)
    end

    it 'includes :unknown, so an unmapped key is still addressable' do
      expect(described_class.names).to include(:unknown)
      expect(described_class.key?(:unknown)).to be true
    end
  end

  describe '.validate!' do
    it 'returns the name when it is valid' do
      expect(described_class.validate!(:left_shift)).to eq(:left_shift)
    end

    it 'accepts :unknown so code can test for an unmapped key' do
      expect(described_class.validate!(:unknown)).to eq(:unknown)
    end

    it 'names the symbol to use when given the string form' do
      expect { described_class.validate!('space') }
        .to raise_error(Ruby2D::Error, /key names are symbols, use `:space`/)
    end

    it 'raises on a misspelled key instead of returning false' do
      expect { described_class.validate!(:spcae) }
        .to raise_error(Ruby2D::Error, /`:spcae` is not a valid key name/)
    end

    it 'raises on the old multi-word display names' do
      expect { described_class.validate!('left shift') }
        .to raise_error(Ruby2D::Error, /not a valid key name/)
    end
  end
end

RSpec.describe 'keyboard input' do
  let(:window) { Ruby2D::Window.new }

  def press(win, key)
    win.key_callback(:down, key)
    win.key_callback(:held, key)
    win.key_callback(:up, key)
  end

  describe 'polling' do
    it 'matches a symbol for pressed, held, and released' do
      press(window, :space)
      expect(window.key_pressed?(:space)).to be true
      expect(window.key_held?(:space)).to be true
      expect(window.key_released?(:space)).to be true
    end

    it 'does not match a key that was never pressed' do
      press(window, :space)
      expect(window.key_pressed?(:escape)).to be false
    end

    it 'raises on the string form rather than never matching' do
      press(window, :space)
      %i[key_pressed? key_held? key_released?].each do |method|
        expect { window.public_send(method, 'space') }
          .to raise_error(Ruby2D::Error, /key names are symbols, use `:space`/),
              "#{method} accepted a string"
      end
    end

    it 'raises on a misspelled key' do
      expect { window.key_pressed?(:spcae) }
        .to raise_error(Ruby2D::Error, /not a valid key name/)
    end

    it 'matches keys whose old SDL names were not clean symbols' do
      press(window, :left_shift)
      expect(window.key_held?(:left_shift)).to be true
    end
  end

  describe 'events' do
    it 'gives handlers a symbol in event.key' do
      captured = nil
      window.on(:key_down) { |e| captured = e }
      window.key_callback(:down, :left_shift)
      expect(captured.key).to eq(:left_shift)
    end

    it 'keeps event.key equal to what key? matches, so both agree' do
      captured = nil
      window.on(:key_down) { |e| captured = e }
      window.key_callback(:down, :space)
      expect(captured.key?(:space)).to be true
      expect(captured.key == :space).to be true
    end

    it 'raises when key? is given a string' do
      event = Ruby2D::Window::KeyEvent.new(:down, :space)
      expect { event.key?('space') }
        .to raise_error(Ruby2D::Error, /key names are symbols, use `:space`/)
    end
  end

  describe 'close_on_esc' do
    before do
      window.set(close_on_esc: true)
      allow(window).to receive(:close)
    end

    it 'still closes on the escape key' do
      window.key_callback(:down, :escape)
      expect(window).to have_received(:close)
    end

    it 'does not close on any other key' do
      window.key_callback(:down, :space)
      expect(window).not_to have_received(:close)
    end
  end
end
