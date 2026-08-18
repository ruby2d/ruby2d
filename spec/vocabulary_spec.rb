# Every input device names its inputs with symbols from a closed set. These
# specs pin the two properties that make that worth having: the vocabularies
# cannot drift from the maps the C bridge fills, and a name outside a set
# raises rather than returning a default that can never change.
RSpec.describe Ruby2D::Vocabulary do
  subject(:vocab) { described_class.new('widget', %i[alpha beta], 'one of :alpha, :beta') }

  it 'returns the name when it is valid, so it can wrap an argument inline' do
    expect(vocab.validate!(:alpha)).to eq(:alpha)
  end

  it 'names the symbol to use when handed the string form' do
    expect { vocab.validate!('alpha') }
      .to raise_error(Ruby2D::Error, /widget names are symbols, use `:alpha`/)
  end

  it 'includes the hint when the name is not in the set at all' do
    expect { vocab.validate!(:gamma) }
      .to raise_error(Ruby2D::Error, /`:gamma` is not a valid widget name — one of :alpha, :beta/)
  end

  it 'is frozen, and hands out a copy so the set cannot be widened' do
    expect(vocab).to be_frozen
    vocab.names << :gamma
    expect(vocab.valid?(:gamma)).to be false
  end
end

RSpec.describe 'input vocabularies match the C bridge maps' do
  it 'mouse buttons cover exactly what MOUSE_BTN_MAP produces' do
    expect(Ruby2D::Mouse::BUTTONS.names)
      .to match_array(Ruby2D::Window::MOUSE_BTN_MAP.values)
  end

  it 'gamepad buttons cover exactly what GP_BUTTON_MAP produces' do
    expect(Ruby2D::Gamepad::BUTTONS.names)
      .to match_array(Ruby2D::Window::GP_BUTTON_MAP.values)
  end

  it 'gamepad axes cover exactly what GP_AXIS_MAP produces' do
    expect(Ruby2D::Gamepad::AXES.names)
      .to match_array(Ruby2D::Window::GP_AXIS_MAP.values)
  end

  it 'keys come from the extension, which owns the scancode mapping' do
    expect(Ruby2D::Keyboard.names).to match_array(Ruby2D::Ext.key_names)
  end

  # No scancode API remains, by design, so nothing can assert "44 is :space"
  # directly. `Ext.key_names` walks scancodes in order, so its ordering *is*
  # the mapping: swapping two rows of the C table reorders this list. Pinning
  # the common runs catches an edit that would otherwise be spec-blind.
  it 'reports names in scancode order, pinning them to their physical keys' do
    names = Ruby2D::Ext.key_names
    expect(names.first).to eq(:unknown)
    expect(names[1, 26]).to eq((:a..:z).to_a)
    expect(names[27, 10]).to eq(%i[digit_1 digit_2 digit_3 digit_4 digit_5
                                   digit_6 digit_7 digit_8 digit_9 digit_0])
    expect(names[37, 5]).to eq(%i[return escape backspace tab space])
    expect(names[names.index(:left_ctrl), 8])
      .to eq(%i[left_ctrl left_shift left_alt left_gui
                right_ctrl right_shift right_alt right_gui])
  end
end

RSpec.describe 'mouse input names' do
  let(:window) { Ruby2D::Window.new }

  before do
    window.mouse_callback(:down, :left, nil, 0, 0, nil, nil)
    window.mouse_callback(:held, :left, nil, 0, 0, nil, nil)
    window.mouse_callback(:up,   :left, nil, 0, 0, nil, nil)
  end

  it 'matches a symbol for pressed, held, and released' do
    expect(window.mouse_pressed?(:left)).to be true
    expect(window.mouse_held?(:left)).to be true
    expect(window.mouse_released?(:left)).to be true
  end

  it 'raises on the string form rather than never matching' do
    %i[mouse_pressed? mouse_held? mouse_released?].each do |method|
      expect { window.public_send(method, 'left') }
        .to raise_error(Ruby2D::Error, /mouse button names are symbols, use `:left`/),
            "#{method} accepted a string"
    end
  end

  it 'raises on an unknown button' do
    expect { window.mouse_pressed?(:middel) }
      .to raise_error(Ruby2D::Error, /not a valid mouse button name/)
  end

  it 'raises when button? is given a string' do
    event = Ruby2D::Window::MouseEvent.new(:down, :left, nil, 0, 0, nil, nil)
    expect { event.button?('left') }
      .to raise_error(Ruby2D::Error, /mouse button names are symbols/)
  end
end

RSpec.describe 'gamepad input names' do
  let(:window) { Ruby2D::Window.new }

  def connect(win, id: 1)
    win.gamepad_callback(id, :connect, nil, nil, 'Test Pad')
    win.gamepads.find { |p| p.id == id }
  end

  it 'raises on a string button name' do
    pad = connect(window)
    expect { pad.held?('south') }
      .to raise_error(Ruby2D::Error, /gamepad button names are symbols, use `:south`/)
  end

  it 'raises on a string axis name' do
    pad = connect(window)
    expect { pad.axis('left_x') }
      .to raise_error(Ruby2D::Error, /gamepad axis names are symbols, use `:left_x`/)
  end

  it 'validates has? even while the pad is disconnected' do
    pad = connect(window)
    window.gamepad_callback(pad.id, :disconnect, nil, nil, nil)
    expect { pad.has?(:button, :no_such_button) }
      .to raise_error(Ruby2D::Error, /not a valid gamepad button name/)
  end

  it 'answers rather than raises for a real button, present or not' do
    pad = connect(window)
    expect { pad.has?(:button, :paddle1) }.not_to raise_error
  end
end

RSpec.describe 'filter registration validates names' do
  let(:window) { Ruby2D::Window.new }

  {
    'mouse_down'          => [:mouse_down, 'left', /mouse button names are symbols/],
    'gamepad_button_down' => [:gamepad_button_down, 'south', /gamepad button names are symbols/],
    'gamepad_axis'        => [:gamepad_axis, 'left_x', /gamepad axis names are symbols/]
  }.each do |label, (event, bad_value, message)|
    it "rejects a string #{label} matcher when registering" do
      expect { window.on(event => bad_value) {} }
        .to raise_error(Ruby2D::Error, message)
    end
  end

  it 'rejects an unknown name inside an array matcher' do
    expect { window.on(mouse_down: %i[left middel]) {} }
      .to raise_error(Ruby2D::Error, /not a valid mouse button name/)
  end

  # The hash form takes a different branch from the scalar/array form, so it
  # needs its own check — otherwise a typo waits for the first button press.
  it 'rejects a bad name inside a gamepad hash matcher when registering' do
    expect { window.on(gamepad_button_down: { button: :suoth }) {} }
      .to raise_error(Ruby2D::Error, /not a valid gamepad button name/)
    expect { window.on(gamepad_axis: { axis: 'left_x' }) {} }
      .to raise_error(Ruby2D::Error, /gamepad axis names are symbols/)
  end
end

RSpec.describe 'per-object filter registration validates names' do
  let(:window) { Ruby2D::Window.new }
  let(:square) { Ruby2D::Square.new(x: 0, y: 0, size: 10) }

  # Object handlers fire from deep in dispatch, at a moment the player picks,
  # so an unvalidated name would surface as a crash mid-click.
  it 'rejects a string button matcher when registering' do
    expect { square.on(click: 'left') {} }
      .to raise_error(Ruby2D::Error, /mouse button names are symbols, use `:left`/)
  end

  it 'rejects an unknown button matcher when registering' do
    expect { square.on(mouse_down: :leftt) {} }
      .to raise_error(Ruby2D::Error, /not a valid mouse button name/)
  end

  it 'still registers a valid filter' do
    expect { square.on(click: :left) {} }.not_to raise_error
  end
end
