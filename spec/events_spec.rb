RSpec.describe Ruby2D::Window do

  describe 'on :bad_event' do
    it 'raises exception if a bad event type is given' do
      window = Ruby2D::Window.new
      expect { window.on(:bad_event) { } }.to raise_error(Ruby2D::Error)
    end
  end

  describe 'registration without a block' do
    let(:window) { Ruby2D::Window.new }

    it 'raises a clear error from #on (symbol and filter forms)' do
      expect { window.on(:key_down) }.to raise_error(Ruby2D::Error, /requires a block/)
      expect { window.on(key_down: :space) }.to raise_error(Ruby2D::Error, /requires a block/)
    end

    it 'raises a clear error from #update and #render' do
      expect { window.update }.to raise_error(Ruby2D::Error, /requires a block/)
      expect { window.render }.to raise_error(Ruby2D::Error, /requires a block/)
    end
  end

  # Each event family (key / mouse) shares a single registration and dispatch
  # path. We verify the full bind / multi-bind / off cycle once per family
  # using a canonical event type, then add one parametric test that covers
  # every event type in the family — enough to catch a typo in the
  # symbol-to-callback mapping without re-testing the registry per type.
  shared_examples 'event family' do |canonical_type, all_types, prefix|
    let(:window) { Ruby2D::Window.new }
    let(:canonical_callback) { canonical_type.to_s.sub(/^#{prefix}_/, '').to_sym }

    it "binds and fires #{canonical_type}" do
      value = 0
      window.on(canonical_type) { value += 1 }
      fire(window, canonical_callback)
      expect(value).to eq(1)
    end

    it 'supports multiple handlers on the same event' do
      value = 0
      window.on(canonical_type) { value += 1 }
      window.on(canonical_type) { value += 2 }
      fire(window, canonical_callback)
      expect(value).to eq(3)
    end

    it 'unbinds via descriptor passed to #off' do
      value = 0
      desc = window.on(canonical_type) { value += 1 }
      window.off(desc)
      fire(window, canonical_callback)
      expect(value).to eq(0)
    end

    it 'routes every event type in the family to its callback' do
      all_types.each do |type|
        callback_name = type.to_s.sub(/^#{prefix}_/, '').to_sym
        value = 0
        window.on(type) { value += 1 }
        fire(window, callback_name)
        expect(value).to eq(1), "#{type} did not route to #{callback_name}"
      end
    end
  end

  describe 'key events' do
    def fire(window, name)
      window.key_callback(name, 'example_key')
    end

    include_examples 'event family', :key_down,
                     [:key, :key_down, :key_held, :key_up], 'key'
  end

  # The native event buffer carries only the integer scancode for key events;
  # the name is resolved (once per distinct key) and cached on the Ruby side.
  describe 'scancode dispatch' do
    let(:window) { Ruby2D::Window.new }

    # One held-key event: [category, type, id(scancode), 0.., str=nil]
    def key_event(type, scancode)
      [Ruby2D::Window::EVT_KEY, type, scancode, 0, 0, 0, 0, 0, 0, 0, 0, nil]
    end

    it 'resolves a scancode to its cached, frozen, lowercased name' do
      allow(Ruby2D::Ext).to receive(:scancode_name).with(44).and_return('Space')
      name = window.send(:key_name, 44)
      expect(name).to eq('space')
      expect(name).to be_frozen
    end

    it 'looks up each distinct scancode at most once' do
      allow(Ruby2D::Ext).to receive(:scancode_name).with(44).and_return('Space')
      3.times { window.send(:key_name, 44) }
      expect(Ruby2D::Ext).to have_received(:scancode_name).once
    end

    it 'dispatches a key event by scancode to the matching handler' do
      allow(Ruby2D::Ext).to receive(:scancode_name).with(44).and_return('Space')
      value = 0
      window.on(key_held: 'space') { value += 1 }
      window.send(:dispatch_events, key_event(2, 44)) # type 2 → :held
      expect(value).to eq(1)
    end
  end

  describe 'mouse events' do
    def fire(window, name)
      window.mouse_callback(name, nil, nil, 0, 0, 0, 0)
    end

    include_examples 'event family', :mouse_down,
                     [:mouse, :mouse_up, :mouse_down, :mouse_held, :mouse_scroll, :mouse_move], 'mouse'
  end

  # Gamepad events have a different shape (per-pad object, multi-arg blocks),
  # so they get their own dedicated tests rather than the shared family.
  describe 'gamepad events' do
    let(:window) { Ruby2D::Window.new }

    def connect(window, id: 1, name: 'Test Pad')
      window.gamepad_callback(id, :connect, nil, nil, name)
      window.gamepads.find { |p| p.id == id }
    end

    it 'fires :gamepad_connect with the gamepad object' do
      received = nil
      window.on(:gamepad_connect) { |pad| received = pad }
      pad = connect(window)
      expect(received).to equal(pad)
      expect(pad.name).to eq('Test Pad')
    end

    it 'tracks pads in connect order in #gamepads' do
      window.gamepad_callback(1, :connect, nil, nil, 'A')
      window.gamepad_callback(2, :connect, nil, nil, 'B')
      expect(window.gamepads.map(&:id)).to eq([1, 2])
    end

    it 'removes pads on :disconnect and fires :gamepad_disconnect' do
      pad = connect(window, id: 7)
      received = nil
      window.on(:gamepad_disconnect) { |p| received = p }
      window.gamepad_callback(7, :disconnect, nil, nil, 'Test Pad')
      expect(received).to equal(pad)
      expect(window.gamepads).to be_empty
      expect(pad.connected?).to be false
    end

    it 'fires :gamepad_button_down with (gamepad, button)' do
      pad = connect(window)
      received = nil
      window.on(:gamepad_button_down) { |p, b| received = [p, b] }
      window.gamepad_callback(pad.id, :button_down, :south, nil, nil)
      expect(received).to eq([pad, :south])
    end

    it 'fires :gamepad_axis with (gamepad, axis, value)' do
      pad = connect(window)
      received = nil
      window.on(:gamepad_axis) { |p, a, v| received = [p, a, v] }
      window.gamepad_callback(pad.id, :axis, :left_x, 0.8, nil)
      expect(received).to eq([pad, :left_x, 0.8])
    end

    it 'isolates state per pad' do
      pad1 = connect(window, id: 1, name: 'A')
      pad2 = connect(window, id: 2, name: 'B')
      window.gamepad_callback(1, :button_down, :south, nil, nil)
      expect(pad1.held?(:south)).to be true
      expect(pad2.held?(:south)).to be false
    end

    it 'filter form: scalar matcher uses primary predicate' do
      pad = connect(window)
      hit = 0
      window.on(gamepad_button_down: :south) { |_p| hit += 1 }
      window.gamepad_callback(pad.id, :button_down, :south, nil, nil)
      window.gamepad_callback(pad.id, :button_down, :east, nil, nil)
      expect(hit).to eq(1)
    end

    it 'filter form: array matcher matches any' do
      pad = connect(window)
      hit = 0
      window.on(gamepad_button_down: [:south, :east]) { |_p| hit += 1 }
      window.gamepad_callback(pad.id, :button_down, :south, nil, nil)
      window.gamepad_callback(pad.id, :button_down, :west, nil, nil)
      window.gamepad_callback(pad.id, :button_down, :east, nil, nil)
      expect(hit).to eq(2)
    end

    it 'filter form: hash matcher requires every predicate' do
      pad1 = connect(window, id: 1, name: 'A')
      pad2 = connect(window, id: 2, name: 'B')
      hit = 0
      window.on(gamepad_button_down: { gamepad: pad1, button: :south }) { hit += 1 }
      window.gamepad_callback(pad2.id, :button_down, :south, nil, nil) # wrong pad
      window.gamepad_callback(pad1.id, :button_down, :east,  nil, nil) # wrong button
      window.gamepad_callback(pad1.id, :button_down, :south, nil, nil) # match
      expect(hit).to eq(1)
    end

    it 'filter form: cross-source match composes with key events' do
      pad = connect(window)
      hit = 0
      window.on(key_down: :right, gamepad_button_down: :dpad_right) { hit += 1 }
      window.key_callback(:down, 'right')
      window.gamepad_callback(pad.id, :button_down, :dpad_right, nil, nil)
      expect(hit).to eq(2)
    end

    it 'unknown button or axis names return safe defaults from polling' do
      pad = connect(window)
      expect(pad.held?(:not_a_button)).to be false
      expect(pad.axis(:not_an_axis)).to eq(0.0)
    end

    it 'axes hash always includes every axis with default 0.0' do
      pad = connect(window)
      expect(pad.axes.keys).to match_array(Ruby2D::Gamepad::AXIS_NAMES)
      expect(pad.axes.values).to all(eq(0.0))
    end
  end

  describe 'gamepad polling and frame state' do
    let(:window) { Ruby2D::Window.new }

    def connect(window, id: 1)
      window.gamepad_callback(id, :connect, nil, nil, 'Pad')
      window.gamepads.find { |p| p.id == id }
    end

    it 'pressed? is frame-scoped; held? persists; clear_event_stores resets both' do
      pad = connect(window)
      window.gamepad_callback(pad.id, :button_down, :south, nil, nil)
      expect(pad.pressed?(:south)).to be true
      expect(pad.held?(:south)).to be true

      window.send(:clear_event_stores)
      expect(pad.pressed?(:south)).to be false
      expect(pad.held?(:south)).to be false  # cleared and refilled by C next frame
    end

    it 'released? fires once on transition' do
      pad = connect(window)
      window.gamepad_callback(pad.id, :button_down, :south, nil, nil)
      window.gamepad_callback(pad.id, :button_up,   :south, nil, nil)
      expect(pad.released?(:south)).to be true
      expect(pad.held?(:south)).to be false
    end

    it 'axis values stay sticky; axis_moved? is frame-scoped' do
      pad = connect(window)
      window.gamepad_callback(pad.id, :axis, :left_x, 0.5, nil)
      expect(pad.axis(:left_x)).to eq(0.5)
      expect(pad.axis_moved?(:left_x)).to be true

      window.send(:clear_event_stores)
      expect(pad.axis(:left_x)).to eq(0.5)
      expect(pad.axis_moved?(:left_x)).to be false
    end

    it 'dead zone suppresses motion entirely inside the threshold' do
      pad = connect(window)
      pad.dead_zone = 0.2
      hit = 0
      window.on(:gamepad_axis) { hit += 1 }
      window.gamepad_callback(pad.id, :axis, :left_x, 0.1,  nil)  # below dz
      window.gamepad_callback(pad.id, :axis, :left_x, -0.1, nil)  # still 0
      window.gamepad_callback(pad.id, :axis, :left_x, 0.5,  nil)  # outside
      expect(hit).to eq(1)
      expect(pad.axis(:left_x)).to eq(0.5)
      expect(pad.axis(:left_x, raw: true)).to eq(0.5)
    end

    it 'triggers bypass the dead zone — the full 0..1 range is reported' do
      pad = connect(window)
      pad.dead_zone = 0.2
      hit = 0
      window.on(:gamepad_axis) { hit += 1 }
      window.gamepad_callback(pad.id, :axis, :left_trigger,  0.05, nil)
      window.gamepad_callback(pad.id, :axis, :right_trigger, 0.10, nil)
      expect(hit).to eq(2)
      expect(pad.axis(:left_trigger)).to be_within(1e-9).of(0.05)
      expect(pad.axis(:right_trigger)).to be_within(1e-9).of(0.10)
    end
  end

  describe 'per-frame polling state' do
    let(:window) { Ruby2D::Window.new }

    it 'resets mouse scroll delta and direction each frame' do
      window.mouse_callback(:scroll, nil, :normal, nil, nil, 3, -2)
      expect(window.mouse_scrolled?).to be true
      expect(window.mouse_scroll_delta_x).to eq(3)
      expect(window.mouse_scroll_delta_y).to eq(-2)
      expect(window.mouse_scroll_direction).to eq(:normal)

      window.send(:clear_event_stores)
      expect(window.mouse_scrolled?).to be false
      expect(window.mouse_scroll_delta_x).to eq(0)
      expect(window.mouse_scroll_delta_y).to eq(0)
      expect(window.mouse_scroll_direction).to be_nil
    end

    it 'resets mouse move delta each frame' do
      window.mouse_callback(:move, nil, nil, 100, 200, 5, 7)
      expect(window.mouse_moved?).to be true
      expect(window.mouse_move_delta_x).to eq(5)
      expect(window.mouse_move_delta_y).to eq(7)

      window.send(:clear_event_stores)
      expect(window.mouse_moved?).to be false
      expect(window.mouse_move_delta_x).to eq(0)
      expect(window.mouse_move_delta_y).to eq(0)
    end
  end

  describe '#on with filters' do
    let(:window) { Ruby2D::Window.new }

    it 'fires when value matches' do
      value = 0
      window.on(key_down: 'space') { value += 1 }
      window.key_callback(:down, 'space')
      expect(value).to eq(1)
    end

    it 'does not fire when value does not match' do
      value = 0
      window.on(key_down: 'space') { value += 1 }
      window.key_callback(:down, 'escape')
      expect(value).to eq(0)
    end

    it 'matches any value when matcher is an array' do
      value = 0
      window.on(key_down: %w[escape space]) { value += 1 }
      window.key_callback(:down, 'space')
      window.key_callback(:down, 'escape')
      window.key_callback(:down, 'r')
      expect(value).to eq(2)
    end

    it 'accepts a symbol matcher for keys (treated as string)' do
      value = 0
      window.on(key_down: :space) { value += 1 }
      window.key_callback(:down, 'space')
      expect(value).to eq(1)
    end

    it 'returns a single descriptor for a single filter' do
      desc = window.on(key_down: :space) { }
      expect(desc).to be_a(Ruby2D::Window::EventDescriptor)
    end

    it 'returns an array of descriptors for multiple filters' do
      descs = window.on(key_down: :a, mouse_down: :left) { }
      expect(descs).to be_an(Array).and have_attributes(size: 2)
    end

    it 'raises for events that have no matcher field' do
      expect { window.on(mouse_scroll: :up) { } }.to raise_error(Ruby2D::Error)
    end

    it 'raises when both a positional event and filters are given' do
      expect { window.on(:key_down, key_up: :a) { } }.to raise_error(Ruby2D::Error)
    end

    it 'raises when a hash matcher is used on a non-gamepad event' do
      expect { window.on(key_down: { key: :a }) { } }.to raise_error(Ruby2D::Error)
    end
  end

  describe 'gamepad mappings' do
    let(:window) { Ruby2D::Window.new }

    it 'add_gamepad_mapping treats existing files as files, strings as mappings' do
      expect(Ruby2D::Ext).to receive(:window_load_gamepad_mappings_file).with(window, __FILE__)
      window.add_gamepad_mapping(__FILE__)

      mapping = '030000005e040000ea02000000007801,Test,a:b0,b:b1,'
      expect(Ruby2D::Ext).to receive(:window_add_gamepad_mapping).with(window, mapping)
      window.add_gamepad_mapping(mapping)
    end
  end

  # Capability queries follow `pad.has?(:rumble)` / `pad.has?(:button, name)`
  # forms documented in the redesign and USAGE.md. Caps come from a single
  # `ext_gamepad_caps` bitfield call at connect; per-button / per-axis
  # presence comes from individual `ext_gamepad_has_*` calls.
  describe 'gamepad capability queries (#has?)' do
    let(:window) { Ruby2D::Window.new }

    # `caps` is the bitfield C returns from `R2D_GetGamepadCaps`:
    # bit 0 = rumble, bit 1 = rumble_triggers, bit 2 = rgb_led.
    def connect(window, caps: 0, has_button: false, has_axis: false, id: 1)
      allow(Ruby2D::Ext).to receive(:window_gamepad_caps).and_return(caps)
      allow(Ruby2D::Ext).to receive(:window_gamepad_has_button).and_return(has_button)
      allow(Ruby2D::Ext).to receive(:window_gamepad_has_axis).and_return(has_axis)
      window.gamepad_callback(id, :connect, nil, nil, 'Test Pad')
      window.gamepads.find { |p| p.id == id }
    end

    it ':rumble reflects bit 0 of ext_gamepad_caps' do
      expect(connect(window, caps: 0x1, id: 1).has?(:rumble)).to be true
      expect(connect(window, caps: 0x6, id: 2).has?(:rumble)).to be false
    end

    it ':rumble_triggers reflects bit 1 of ext_gamepad_caps' do
      expect(connect(window, caps: 0x2, id: 1).has?(:rumble_triggers)).to be true
      expect(connect(window, caps: 0x5, id: 2).has?(:rumble_triggers)).to be false
    end

    it ':led reflects bit 2 of ext_gamepad_caps' do
      expect(connect(window, caps: 0x4, id: 1).has?(:led)).to be true
      expect(connect(window, caps: 0x3, id: 2).has?(:led)).to be false
    end

    it ':button delegates to ext_gamepad_has_button with the SDL enum (at connect)' do
      paddle1 = Ruby2D::Gamepad::BUTTON_ENUM[:paddle1]
      allow(Ruby2D::Ext).to receive(:window_gamepad_caps).and_return(0)
      allow(Ruby2D::Ext).to receive(:window_gamepad_has_button) { |_window, _id, enum| enum == paddle1 }
      allow(Ruby2D::Ext).to receive(:window_gamepad_has_axis).and_return(false)
      window.gamepad_callback(1, :connect, nil, nil, 'Test Pad')
      pad = window.gamepads.first

      # The right enum reaches SDL — only paddle1's enum returns true, so
      # only :paddle1 reads back as present.
      expect(pad.has?(:button, :paddle1)).to be true
      expect(pad.has?(:button, :south)).to be false
    end

    it ':axis delegates to ext_gamepad_has_axis with the SDL enum (at connect)' do
      left_trigger = Ruby2D::Gamepad::AXIS_ENUM[:left_trigger]
      allow(Ruby2D::Ext).to receive(:window_gamepad_caps).and_return(0)
      allow(Ruby2D::Ext).to receive(:window_gamepad_has_button).and_return(false)
      allow(Ruby2D::Ext).to receive(:window_gamepad_has_axis) { |_window, _id, enum| enum == left_trigger }
      window.gamepad_callback(1, :connect, nil, nil, 'Test Pad')
      pad = window.gamepads.first

      expect(pad.has?(:axis, :left_trigger)).to be true
      expect(pad.has?(:axis, :left_x)).to be false
    end

    it ':button with an unknown name returns false' do
      pad = connect(window)
      expect(pad.has?(:button, :no_such_button)).to be false
    end

    it ':axis with an unknown name returns false' do
      pad = connect(window)
      expect(pad.has?(:axis, :no_such_axis)).to be false
    end

    it 'caches :rumble / :rumble_triggers / :led — one ext_gamepad_caps call total' do
      # Caps are read once at connect via a single bitfield call; subsequent
      # `has?(:rumble | :rumble_triggers | :led)` reads should be free.
      expect(Ruby2D::Ext).to receive(:window_gamepad_caps).once.and_return(0x7)
      window.gamepad_callback(1, :connect, nil, nil, 'Test')
      pad = window.gamepads.first

      3.times do
        pad.has?(:rumble)
        pad.has?(:rumble_triggers)
        pad.has?(:led)
      end
    end

    it 'caches :button / :axis lookups — no SDL calls after connect' do
      # Each enum is queried once during init (BUTTON_ENUM × ext_gamepad_has_button,
      # AXIS_ENUM × ext_gamepad_has_axis). Subsequent `has?` reads hit the
      # cached hashes, never SDL.
      pad = connect(window, has_button: true, has_axis: true)
      expect(Ruby2D::Ext).not_to receive(:window_gamepad_has_button)
      expect(Ruby2D::Ext).not_to receive(:window_gamepad_has_axis)

      3.times do
        pad.has?(:button, :paddle1)
        pad.has?(:axis, :left_trigger)
      end
    end
  end

  # The redesign promises that polling and feedback against a disconnected
  # pad never raises and returns documented safe defaults — `rumble`,
  # `rumble_triggers`, `led=` all return `false`; `battery` returns `nil`.
  describe 'gamepad disconnect-safe contract' do
    let(:window) { Ruby2D::Window.new }

    def disconnected_pad(window, id: 1)
      window.gamepad_callback(id, :connect, nil, nil, 'Test Pad')
      pad = window.gamepads.find { |p| p.id == id }
      window.gamepad_callback(id, :disconnect, nil, nil, 'Test Pad')
      pad
    end

    it 'rumble returns false on a disconnected pad and does not raise' do
      pad = disconnected_pad(window)
      expect(pad.connected?).to be false
      expect { @result = pad.rumble(strength: 0.5, duration: 0.1) }.not_to raise_error
      expect(@result).to be false
    end

    it 'rumble_triggers returns false on a disconnected pad and does not raise' do
      pad = disconnected_pad(window)
      expect { @result = pad.rumble_triggers(left: 0.5, right: 0.5, duration: 0.1) }.not_to raise_error
      expect(@result).to be false
    end

    # Setter syntax (`pad.led = [...]`) always evaluates to the RHS, so we
    # exercise both: the no-raise path via the setter syntax users write,
    # and the documented `false` return via direct method invocation.
    it 'led= returns false on a disconnected pad and does not raise' do
      pad = disconnected_pad(window)
      expect { pad.led = [255, 0, 0] }.not_to raise_error
      expect(pad.send(:led=, [255, 0, 0])).to be false
    end

    it 'battery returns nil on a disconnected pad' do
      pad = disconnected_pad(window)
      expect(pad.battery).to be_nil
    end

    it 'feedback and battery do not call into SDL on a disconnected pad' do
      pad = disconnected_pad(window)
      expect(Ruby2D::Ext).not_to receive(:window_gamepad_rumble)
      expect(Ruby2D::Ext).not_to receive(:window_gamepad_rumble_triggers)
      expect(Ruby2D::Ext).not_to receive(:window_gamepad_set_led)
      expect(Ruby2D::Ext).not_to receive(:window_gamepad_battery)

      pad.rumble(strength: 0.5)
      pad.rumble_triggers(left: 0.5, right: 0.5)
      pad.led = [255, 0, 0]
      pad.battery
    end
  end

end
