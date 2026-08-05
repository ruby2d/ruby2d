RSpec.describe Ruby2D::Gamepad do
  # A bare instance forced disconnected, so feedback methods short-circuit
  # before touching SDL — no window or hardware needed.
  let(:pad) do
    g = described_class.allocate
    g.instance_variable_set(:@connected, false)
    g
  end

  describe '#set_led and #led=' do
    it 'set_led returns false when the pad is disconnected' do
      expect(pad.set_led([255, 0, 0])).to be false
    end

    it 'led= evaluates to the assigned value (Ruby setter semantics), not the success Boolean' do
      result = (pad.led = [255, 0, 0])
      expect(result).to eq([255, 0, 0])
    end
  end

  describe 'button enum coverage' do
    # Both maps must cover every SDL3 gamepad button (0..25, COUNT = 26) and
    # agree: GP_BUTTON_MAP (event int → symbol) is the inverse of BUTTON_ENUM
    # (symbol → capability-query int).
    let(:enum)     { Ruby2D::Gamepad::BUTTON_ENUM }
    let(:name_map) { Ruby2D::Window::GP_BUTTON_MAP }

    it 'covers the full SDL button range 0..25 in both maps' do
      expect(enum.values.sort).to eq((0..25).to_a)
      expect(name_map.keys.sort).to eq((0..25).to_a)
    end

    it 'maps the misc2..misc6 buttons' do
      expect(enum.values_at(:misc2, :misc3, :misc4, :misc5, :misc6)).to eq([21, 22, 23, 24, 25])
      expect(name_map.values_at(21, 22, 23, 24, 25)).to eq(%i[misc2 misc3 misc4 misc5 misc6])
    end

    it 'is internally consistent (the two maps are inverses)' do
      enum.each { |sym, int| expect(name_map[int]).to eq(sym) }
    end
  end
end
