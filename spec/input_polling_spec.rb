
RSpec.describe 'window input polling and coordinates' do
  # Shapes auto-add to the DSL window, so it has to exist before they do.
  before(:each) { Ruby2D::DSL.window = Ruby2D::Window.new }

  let(:window) { Ruby2D::DSL.window }

  describe 'mouse positions' do
    it 'starts the polled position as floats, like event positions' do
      expect(window.mouse_x).to be_a(Float)
      expect(window.mouse_y).to be_a(Float)
      expect(window.mouse_position).to eq([0.0, 0.0])
    end

    it 'keeps a fractional event position for hit-testing and for the event' do
      rect = Ruby2D::Rectangle.new(x: 10.5, y: 10, width: 10, height: 10)
      clicks = []
      rect.on(:click) { |e| clicks << e.x }

      window.mouse_callback(:down, :left, nil, 10.75, 15.0, nil, nil)
      window.mouse_callback(:up, :left, nil, 10.75, 15.0, nil, nil)
      expect(clicks).to eq([10.75])
    end
  end

  describe 'scroll events' do
    let!(:left)  { Ruby2D::Rectangle.new(x: 0, y: 0, width: 50, height: 50) }
    let!(:right) { Ruby2D::Rectangle.new(x: 50, y: 0, width: 50, height: 50) }

    it 'hit-tests where the wheel moved, not where the cursor is by the end of the frame' do
      targets = []
      left.on(:mouse_scroll)  { |e| targets << [:left, e.position] }
      right.on(:mouse_scroll) { |e| targets << [:right, e.position] }

      # The cursor has already moved on to the right rectangle when the event
      # is dispatched; the event still belongs to the left one.
      window.instance_variable_set(:@mouse_x, 75.0)
      window.instance_variable_set(:@mouse_y, 25.0)
      window.mouse_callback(:scroll, nil, :normal, 25.0, 25.0, 0.0, 1.0)
      expect(targets).to eq([[:left, [25.0, 25.0]]])
    end

    it 'gives window-level handlers the position too' do
      positions = []
      window.on(:mouse_scroll) { |e| positions << e.position }
      window.on(:mouse)        { |e| positions << e.position }

      window.mouse_callback(:scroll, nil, :normal, 25.0, 25.0, 0.0, 1.0)
      expect(positions).to eq([[25.0, 25.0], [25.0, 25.0]])
    end
  end

  describe 'polled deltas' do
    it 'sums every move of the frame, while each handler call keeps its own delta' do
      deltas = []
      window.on(:mouse_move) { |e| deltas << e.delta }

      window.mouse_callback(:move, nil, nil, 13.0, 25.0, 3.0, 0.0)
      window.mouse_callback(:move, nil, nil, 20.0, 25.0, 7.0, 0.0)
      expect(deltas).to eq([[3.0, 0.0], [7.0, 0.0]])
      expect([window.mouse_move_delta_x, window.mouse_move_delta_y]).to eq([10.0, 0.0])
    end

    it 'sums every scroll of the frame, while each handler call keeps its own delta' do
      deltas = []
      window.on(:mouse_scroll) { |e| deltas << e.delta }

      window.mouse_callback(:scroll, nil, :normal, 25.0, 25.0, 0.0, -1.0)
      window.mouse_callback(:scroll, nil, :normal, 25.0, 25.0, 0.0, -2.0)
      expect(deltas).to eq([[0.0, -1.0], [0.0, -2.0]])
      expect([window.mouse_scroll_delta_x, window.mouse_scroll_delta_y]).to eq([0.0, -3.0])
    end

    it 'starts each frame from zero' do
      window.mouse_callback(:move, nil, nil, 13.0, 25.0, 3.0, 4.0)
      window.mouse_callback(:scroll, nil, :normal, 25.0, 25.0, 1.0, -1.0)
      window.send(:clear_event_stores)
      window.mouse_callback(:move, nil, nil, 20.0, 25.0, 7.0, 0.0)
      window.mouse_callback(:scroll, nil, :normal, 25.0, 25.0, 0.0, -2.0)
      expect([window.mouse_move_delta_x, window.mouse_move_delta_y]).to eq([7.0, 0.0])
      expect([window.mouse_scroll_delta_x, window.mouse_scroll_delta_y]).to eq([0.0, -2.0])
    end
  end

  # The extension queues a frame's transitions first and its held scan last,
  # so a handler for a transition runs before the scan; held state has to be
  # correct on its own by then.
  describe 'held state inside handlers' do
    it 'shows a key held since an earlier frame inside :key_down and :mouse_down handlers' do
      seen = []
      window.on(key_down: :s) { seen << [:key_down, window.key_held?(:left_shift), window.key_held?(:s)] }
      window.on(:mouse_down) { seen << [:mouse_down, window.key_held?(:left_shift)] }

      window.key_callback(:down, :left_shift)
      window.key_callback(:held, :left_shift)
      window.update_callback

      window.key_callback(:down, :s)
      window.mouse_callback(:down, :left, nil, 20.0, 20.0, nil, nil)
      expect(seen).to eq([[:key_down, true, true], [:mouse_down, true]])
    end

    it 'shows the button of a drag in progress inside a :mouse_move handler' do
      seen = []
      window.on(:mouse_move) { seen << window.mouse_held?(:left) }

      window.mouse_callback(:down, :left, nil, 20.0, 20.0, nil, nil)
      window.mouse_callback(:held, :left, nil, 20.0, 20.0, nil, nil)
      window.update_callback

      window.mouse_callback(:move, nil, nil, 30.0, 20.0, 10.0, 0.0)
      expect(seen).to eq([true])
    end

    it 'shows a gamepad button held since an earlier frame inside a button handler' do
      window.gamepad_callback(123, :connect, nil, nil, 'Pad')
      pad = window.gamepads.first
      seen = []
      window.on(gamepad_button_down: :south) { |device| seen << [device.held?(:left_shoulder), device.held?(:south)] }

      window.gamepad_callback(123, :button_down, :left_shoulder, nil)
      window.gamepad_callback(123, :button_held, :left_shoulder, nil)
      window.update_callback

      window.gamepad_callback(123, :button_down, :south, nil)
      expect(seen).to eq([[true, true]])
      expect(pad.held?(:left_shoulder)).to be true
    end

    it 'is current inside the :key and :mouse catch-alls for the event being delivered' do
      seen = []
      window.on(:key)   { |e| seen << [e.type, window.key_held?(:space)] }
      window.on(:mouse) { |e| seen << [e.type, window.mouse_held?(:left)] }

      window.key_callback(:down, :space)
      window.key_callback(:up, :space)
      window.mouse_callback(:down, :left, nil, 20.0, 20.0, nil, nil)
      window.mouse_callback(:up, :left, nil, 20.0, 20.0, nil, nil)
      expect(seen).to eq([[:down, true], [:up, false], [:down, true], [:up, false]])
    end

    it 'drops held state on release, including inside the :key_up and :mouse_up handlers' do
      seen = []
      window.on(:key_up)   { seen << window.key_held?(:space) }
      window.on(:mouse_up) { seen << window.mouse_held?(:left) }

      window.key_callback(:down, :space)
      window.mouse_callback(:down, :left, nil, 20.0, 20.0, nil, nil)
      window.update_callback
      expect(window.key_held?(:space)).to be true
      expect(window.mouse_held?(:left)).to be true

      window.key_callback(:up, :space)
      window.mouse_callback(:up, :left, nil, 20.0, 20.0, nil, nil)
      expect(seen).to eq([false, false])
      expect(window.key_held?(:space)).to be false
      expect(window.mouse_held?(:left)).to be false
    end

    it 'accepts the held scan as a source too, and still drops the key on release' do
      # A key down before the window existed reaches Ruby only through the
      # scan; a release still clears it.
      window.key_callback(:held, :left_ctrl)
      expect(window.key_held?(:left_ctrl)).to be true
      window.update_callback
      expect(window.key_held?(:left_ctrl)).to be true
      window.key_callback(:up, :left_ctrl)
      expect(window.key_held?(:left_ctrl)).to be false
    end
  end
end
