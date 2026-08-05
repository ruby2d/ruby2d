RSpec.describe 'Per-object events' do
  # Use a fresh DSL window so shapes auto-add to it and on() registers with it
  before(:each) do
    Ruby2D::DSL.window = Ruby2D::Window.new
  end

  let(:window) { Ruby2D::DSL.window }

  def make_rect(x: 0, y: 0, width: 100, height: 100, z: 0)
    Ruby2D::Rectangle.new(x: x, y: y, width: width, height: height, z: z)
  end

  describe 'on / off / interactive?' do
    it 'registers a handler and marks the object as interactive' do
      rect = make_rect
      expect(rect.interactive?).to be false

      rect.on(:click) { }
      expect(rect.interactive?).to be true
      expect(rect.interactive?(:click)).to be true
      expect(rect.interactive?(:hover)).to be false
    end

    it 'raises a clear error when on is called without a block' do
      rect = make_rect
      expect { rect.on(:click) }.to raise_error(Ruby2D::Error, /requires a block/)
      expect { rect.on(click: :left) }.to raise_error(Ruby2D::Error, /requires a block/)
    end

    it 'raises a clear error for an unknown object event (no silent no-op)' do
      rect = make_rect
      expect { rect.on(:clik) { } }.to raise_error(Ruby2D::Error, /not a valid object event/)
      expect(rect.interactive?).to be false
    end

    it 'accepts every valid object event in the bare-symbol form' do
      rect = make_rect
      Ruby2D::Interactive::OBJECT_EVENTS.each do |event|
        expect { rect.on(event) { } }.not_to raise_error
        expect(rect.interactive?(event)).to be true
      end
    end

    it 'returns an ObjectEventDescriptor that can be used with off' do
      rect = make_rect
      desc = rect.on(:click) { }
      expect(desc).to be_a(Ruby2D::Window::ObjectEventDescriptor)
      expect(desc.object).to eq(rect)
      expect(desc.type).to eq(:click)

      rect.off(desc)
      expect(rect.interactive?(:click)).to be false
      expect(rect.interactive?).to be false
    end

    it 'raises a clear error when off is given a non-descriptor' do
      rect = make_rect
      expect { rect.off(nil) }.to raise_error(Ruby2D::Error, /descriptor/)
      expect { window.off(nil) }.to raise_error(Ruby2D::Error, /descriptor/)
    end

    it 'removes multiple handlers when off is given an array of descriptors' do
      rect = make_rect
      d1 = rect.on(:click) { }
      d2 = rect.on(:hover) { }
      rect.off([d1, d2])
      expect(rect.interactive?).to be false
    end

    it 'supports multiple handlers on the same event' do
      rect = make_rect
      values = []
      rect.on(:click) { values << :a }
      rect.on(:click) { values << :b }

      rect._fire_event(:click, Ruby2D::Window::MouseEvent.new(:click, :left, nil, 50, 50, nil, nil))
      expect(values).to eq([:a, :b])
    end
  end

  describe ':click dispatching' do
    it 'fires :click when mouse_down and mouse_up happen on the same object' do
      rect = make_rect(x: 10, y: 10, width: 80, height: 80)
      clicked = false
      rect.on(:click) { clicked = true }

      window.mouse_callback(:down, :left, nil, 50, 50, 0, 0)
      window.mouse_callback(:up, :left, nil, 50, 50, 0, 0)
      expect(clicked).to be true
    end

    it 'does not fire :click if mouse_up is on a different object' do
      rect1 = make_rect(x: 0, y: 0, width: 50, height: 50)
      rect2 = make_rect(x: 100, y: 100, width: 50, height: 50)
      clicked1 = false
      clicked2 = false
      rect1.on(:click) { clicked1 = true }
      rect2.on(:click) { clicked2 = true }

      # Press on rect1, release on rect2
      window.mouse_callback(:down, :left, nil, 25, 25, 0, 0)
      window.mouse_callback(:up, :left, nil, 125, 125, 0, 0)
      expect(clicked1).to be false
      expect(clicked2).to be false
    end

    it 'does not fire :click if mouse_up is outside all objects' do
      rect = make_rect(x: 0, y: 0, width: 50, height: 50)
      clicked = false
      rect.on(:click) { clicked = true }

      window.mouse_callback(:down, :left, nil, 25, 25, 0, 0)
      window.mouse_callback(:up, :left, nil, 200, 200, 0, 0)
      expect(clicked).to be false
    end
  end

  describe 'scene-graph-gated hit-testing' do
    def click(x, y)
      window.mouse_callback(:down, :left, nil, x, y, 0, 0)
      window.mouse_callback(:up, :left, nil, x, y, 0, 0)
    end

    it 'does not hit-test a Renderable built with add: false' do
      rect = Ruby2D::Rectangle.new(x: 0, y: 0, width: 100, height: 100, add: false)
      clicked = false
      rect.on(:click) { clicked = true }
      click(50, 50)
      expect(clicked).to be false
    end

    it 'hit-tests once the object is added, and stops after it is removed' do
      rect = Ruby2D::Rectangle.new(x: 0, y: 0, width: 100, height: 100, add: false)
      count = 0
      rect.on(:click) { count += 1 }

      rect.add
      click(50, 50)
      expect(count).to eq(1)

      rect.remove
      click(50, 50)
      expect(count).to eq(1)
    end

    it 'still hit-tests a hidden (but added) object' do
      rect = make_rect(x: 0, y: 0, width: 100, height: 100)
      rect.hide
      clicked = false
      rect.on(:click) { clicked = true }
      click(50, 50)
      expect(clicked).to be true
    end
  end

  describe ':mouse_down and :mouse_up' do
    it 'fires :mouse_down when pressing on the object' do
      rect = make_rect(x: 10, y: 10, width: 80, height: 80)
      down_fired = false
      rect.on(:mouse_down) { down_fired = true }

      window.mouse_callback(:down, :left, nil, 50, 50, 0, 0)
      expect(down_fired).to be true
    end

    it 'fires :mouse_up when releasing on the object' do
      rect = make_rect(x: 10, y: 10, width: 80, height: 80)
      up_fired = false
      rect.on(:mouse_up) { up_fired = true }

      window.mouse_callback(:up, :left, nil, 50, 50, 0, 0)
      expect(up_fired).to be true
    end

    it 'fires :mouse_up on the originally-pressed object even when released elsewhere' do
      rect = make_rect(x: 10, y: 10, width: 80, height: 80)
      up_count = 0
      rect.on(:mouse_up) { up_count += 1 }

      window.mouse_callback(:down, :left, nil, 50, 50, 0, 0)
      window.mouse_callback(:up,   :left, nil, 500, 500, 0, 0)
      expect(up_count).to eq(1)
    end

    it 'fires :mouse_up exactly once when press and release are on the same object' do
      rect = make_rect(x: 10, y: 10, width: 80, height: 80)
      up_count = 0
      rect.on(:mouse_up) { up_count += 1 }

      window.mouse_callback(:down, :left, nil, 50, 50, 0, 0)
      window.mouse_callback(:up,   :left, nil, 50, 50, 0, 0)
      expect(up_count).to eq(1)
    end

    it 'fires :mouse_up on both press origin and release target when different' do
      rect1 = make_rect(x: 0, y: 0, width: 50, height: 50)
      rect2 = make_rect(x: 100, y: 100, width: 50, height: 50)
      ups = []
      rect1.on(:mouse_up) { ups << :rect1 }
      rect2.on(:mouse_up) { ups << :rect2 }

      window.mouse_callback(:down, :left, nil, 25, 25, 0, 0)
      window.mouse_callback(:up,   :left, nil, 125, 125, 0, 0)
      expect(ups).to contain_exactly(:rect1, :rect2)
    end
  end

  describe ':hover and :hover_out' do
    it 'fires :hover when cursor enters and :hover_out when it leaves' do
      rect = make_rect(x: 10, y: 10, width: 80, height: 80)
      hover_count = 0
      hover_out_count = 0
      rect.on(:hover) { hover_count += 1 }
      rect.on(:hover_out) { hover_out_count += 1 }

      # Move into the object
      window.mouse_callback(:move, nil, nil, 50, 50, 1, 1)
      expect(hover_count).to eq(1)
      expect(hover_out_count).to eq(0)

      # Move within the object (no additional hover)
      window.mouse_callback(:move, nil, nil, 55, 55, 5, 5)
      expect(hover_count).to eq(1)

      # Move out
      window.mouse_callback(:move, nil, nil, 200, 200, 10, 10)
      expect(hover_out_count).to eq(1)
    end
  end

  describe '#on with filters' do
    it 'fires only when the button matches' do
      rect = make_rect(x: 10, y: 10, width: 80, height: 80)
      count = 0
      rect.on(click: :left) { count += 1 }

      window.mouse_callback(:down, :left, nil, 50, 50, 0, 0)
      window.mouse_callback(:up, :left, nil, 50, 50, 0, 0)
      expect(count).to eq(1)

      window.mouse_callback(:down, :right, nil, 50, 50, 0, 0)
      window.mouse_callback(:up, :right, nil, 50, 50, 0, 0)
      expect(count).to eq(1)
    end

    it 'matches any button when matcher is an array' do
      rect = make_rect(x: 10, y: 10, width: 80, height: 80)
      count = 0
      rect.on(click: [:left, :right]) { count += 1 }

      window.mouse_callback(:down, :left, nil, 50, 50, 0, 0)
      window.mouse_callback(:up, :left, nil, 50, 50, 0, 0)
      window.mouse_callback(:down, :right, nil, 50, 50, 0, 0)
      window.mouse_callback(:up, :right, nil, 50, 50, 0, 0)
      expect(count).to eq(2)
    end

    it 'subscribes to multiple events with one block' do
      rect = make_rect(x: 10, y: 10, width: 80, height: 80)
      count = 0
      rect.on(mouse_down: :left, mouse_up: :left) { count += 1 }

      window.mouse_callback(:down, :left, nil, 50, 50, 0, 0)
      window.mouse_callback(:up, :left, nil, 50, 50, 0, 0)
      expect(count).to eq(2)
    end

    it 'raises for events that have no matcher field' do
      rect = make_rect
      expect { rect.on(hover: :left) { } }.to raise_error(Ruby2D::Error)
    end
  end

  describe ':mouse_held' do
    it 'fires every frame on the originally-pressed object' do
      rect = make_rect(x: 10, y: 10, width: 80, height: 80)
      held_count = 0
      rect.on(:mouse_held) { held_count += 1 }

      window.mouse_callback(:down, :left, nil, 50, 50, 0, 0)
      window.mouse_callback(:held, :left, nil, 50, 50, 0, 0)
      window.mouse_callback(:held, :left, nil, 50, 50, 0, 0)
      expect(held_count).to eq(2)
    end

    it 'continues firing after the cursor leaves the object' do
      rect = make_rect(x: 10, y: 10, width: 80, height: 80)
      held_count = 0
      rect.on(:mouse_held) { held_count += 1 }

      window.mouse_callback(:down, :left, nil, 50, 50, 0, 0)
      window.mouse_callback(:move, nil, nil, 500, 500, 450, 450)
      window.mouse_callback(:held, :left, nil, 500, 500, 0, 0)
      expect(held_count).to eq(1)
    end

    it 'does not fire if the press did not start on the object' do
      rect = make_rect(x: 10, y: 10, width: 80, height: 80)
      held_count = 0
      rect.on(:mouse_held) { held_count += 1 }

      window.mouse_callback(:down, :left, nil, 500, 500, 0, 0)
      window.mouse_callback(:held, :left, nil, 50, 50, 0, 0)
      expect(held_count).to eq(0)
    end

    it 'stops firing once the button is released' do
      rect = make_rect(x: 10, y: 10, width: 80, height: 80)
      held_count = 0
      rect.on(:mouse_held) { held_count += 1 }

      window.mouse_callback(:down, :left, nil, 50, 50, 0, 0)
      window.mouse_callback(:held, :left, nil, 50, 50, 0, 0)
      window.mouse_callback(:up, :left, nil, 50, 50, 0, 0)
      window.mouse_callback(:held, :left, nil, 50, 50, 0, 0)
      expect(held_count).to eq(1)
    end
  end

  describe ':mouse_scroll' do
    it 'fires :mouse_scroll on the topmost object under the cursor' do
      rect = make_rect(x: 10, y: 10, width: 80, height: 80)
      scrolled = false
      rect.on(:mouse_scroll) { |e| scrolled = e }

      # Scroll events carry no coordinates of their own, so dispatch hit-tests
      # the window's tracked cursor position (kept current by the frame loop).
      window.instance_variable_set(:@mouse_x, 50)
      window.instance_variable_set(:@mouse_y, 50)
      window.mouse_callback(:scroll, nil, :up, 50, 50, 0, -1)
      expect(scrolled).to be_a(Ruby2D::Window::MouseEvent)
      expect(scrolled.delta_y).to eq(-1)
    end
  end

  describe ':drag' do
    it 'fires :drag while mouse moves with button held on object' do
      rect = make_rect(x: 10, y: 10, width: 80, height: 80)
      drag_events = []
      rect.on(:drag) { |e| drag_events << e }

      # Press on the object
      window.mouse_callback(:down, :left, nil, 50, 50, 0, 0)

      # Move (drag)
      window.mouse_callback(:move, nil, nil, 55, 55, 5, 5)
      window.mouse_callback(:move, nil, nil, 60, 60, 5, 5)

      expect(drag_events.length).to eq(2)
      expect(drag_events.first.delta_x).to eq(5)

      # Release ends drag
      window.mouse_callback(:up, :left, nil, 60, 60, 0, 0)
      window.mouse_callback(:move, nil, nil, 65, 65, 5, 5)
      expect(drag_events.length).to eq(2)
    end
  end

  describe 'top-only dispatch' do
    it 'only fires on the topmost (highest z) interactive object' do
      bottom = make_rect(x: 0, y: 0, width: 100, height: 100, z: 0)
      top = make_rect(x: 0, y: 0, width: 100, height: 100, z: 1)
      bottom_clicked = false
      top_clicked = false
      bottom.on(:click) { bottom_clicked = true }
      top.on(:click) { top_clicked = true }

      window.mouse_callback(:down, :left, nil, 50, 50, 0, 0)
      window.mouse_callback(:up, :left, nil, 50, 50, 0, 0)
      expect(top_clicked).to be true
      expect(bottom_clicked).to be false
    end
  end

  describe 'object removal cleanup' do
    it 'clears interaction state when an object is removed' do
      rect = make_rect(x: 0, y: 0, width: 100, height: 100)
      clicked = false
      rect.on(:click) { clicked = true }

      # Press on the object
      window.mouse_callback(:down, :left, nil, 50, 50, 0, 0)

      # Remove the object
      window.remove(rect)

      # Release — should not crash or fire
      window.mouse_callback(:up, :left, nil, 50, 50, 0, 0)
      expect(clicked).to be false
    end
  end

  describe 'Window#off with ObjectEventDescriptor' do
    it 'removes the handler via the window off method' do
      rect = make_rect(x: 0, y: 0, width: 100, height: 100)
      clicked = false
      desc = rect.on(:click) { clicked = true }

      window.off(desc)

      window.mouse_callback(:down, :left, nil, 50, 50, 0, 0)
      window.mouse_callback(:up, :left, nil, 50, 50, 0, 0)
      expect(clicked).to be false
    end
  end
end

RSpec.describe Ruby2D::Button do
  before(:each) do
    Ruby2D::DSL.window = Ruby2D::Window.new
  end

  let(:window) { Ruby2D::DSL.window }

  # Drive a click on the button at (cx, cy) by firing both mouse_down and
  # mouse_up at the same point. Mirrors `Window::ObjectEventDispatch`'s
  # click semantics (down + up on the same object).
  def click_at(cx, cy)
    window.mouse_callback(:down, :left, nil, cx, cy, 0, 0)
    window.mouse_callback(:up, :left, nil, cx, cy, 0, 0)
  end

  describe 'self-rendered form' do
    it 'creates a button with geometry and responds to click' do
      clicked = false
      btn = Ruby2D::Button.new(x: 10, y: 10, width: 100, height: 40,
                               label: 'Test') { clicked = true }

      expect(btn.label).to eq('Test')
      expect(btn.contains?(50, 30)).to be true
      expect(btn.contains?(200, 200)).to be false

      click_at(50, 30)
      expect(clicked).to be true
    end

    it 'fires :mouse_down, :mouse_up, :hover, and :hover_out through Button#on' do
      btn = Ruby2D::Button.new(x: 0, y: 0, width: 100, height: 40, color: '#333')
      events = []
      btn.on(:mouse_down) { events << :down }
      btn.on(:mouse_up)   { events << :up }
      btn.on(:hover)      { events << :hover }
      btn.on(:hover_out)  { events << :hover_out }

      window.mouse_callback(:move, nil, nil, 50, 20, 1, 1)
      window.mouse_callback(:down, :left, nil, 50, 20, 0, 0)
      window.mouse_callback(:up,   :left, nil, 50, 20, 0, 0)
      window.mouse_callback(:move, nil, nil, 500, 500, 450, 480)

      expect(events).to eq([:hover, :down, :up, :hover_out])
    end

    it 'supports filter syntax through Button#on' do
      btn = Ruby2D::Button.new(x: 0, y: 0, width: 100, height: 40, color: '#333')
      count = 0
      btn.on(click: :left) { count += 1 }

      click_at(50, 20)
      expect(count).to eq(1)

      window.mouse_callback(:down, :right, nil, 50, 20, 0, 0)
      window.mouse_callback(:up,   :right, nil, 50, 20, 0, 0)
      expect(count).to eq(1)
    end
  end

  describe 'wrapped-visual form' do
    it 'delegates contains? to the wrapped visual' do
      circle = Ruby2D::Circle.new(x: 50, y: 50, radius: 30)
      btn = Ruby2D::Button.new(circle)

      expect(btn.contains?(50, 50)).to be true
      expect(btn.contains?(50, 90)).to be false  # outside circle but inside its AABB
    end

    it 'tracks the wrapped visual when it moves (live bounds)' do
      rect = Ruby2D::Rectangle.new(x: 0, y: 0, width: 100, height: 40)
      btn = Ruby2D::Button.new(rect)
      btn.on(:click) { } # force interactive registration

      expect(btn.contains?(50, 20)).to be true

      rect.x = 200
      expect(btn.x).to eq(200)
      expect(btn.contains?(50, 20)).to be false
      expect(btn.contains?(250, 20)).to be true
    end

    it 'does not auto-tint on hover when hover_color is omitted' do
      rect = Ruby2D::Rectangle.new(x: 0, y: 0, width: 100, height: 40, color: '#333')
      Ruby2D::Button.new(rect) { }
      original = [rect.color.r, rect.color.g, rect.color.b]

      window.mouse_callback(:move, nil, nil, 50, 20, 1, 1)
      expect([rect.color.r, rect.color.g, rect.color.b]).to eq(original)
    end

    it 'tints on hover when hover_color: :auto is given' do
      rect = Ruby2D::Rectangle.new(x: 0, y: 0, width: 100, height: 40, color: 'red')
      original = [rect.color.r, rect.color.g, rect.color.b]
      Ruby2D::Button.new(rect, hover_color: :auto)

      window.mouse_callback(:move, nil, nil, 50, 20, 1, 1)
      expect([rect.color.r, rect.color.g, rect.color.b]).not_to eq(original)

      window.mouse_callback(:move, nil, nil, 500, 500, 450, 480)
      expect(rect.color.r).to be_within(0.001).of(original[0])
      expect(rect.color.g).to be_within(0.001).of(original[1])
      expect(rect.color.b).to be_within(0.001).of(original[2])
    end

    it 'tints on hover when hover_color is an explicit color' do
      rect = Ruby2D::Rectangle.new(x: 0, y: 0, width: 100, height: 40, color: 'red')
      Ruby2D::Button.new(rect, hover_color: '#0000ff')

      window.mouse_callback(:move, nil, nil, 50, 20, 1, 1)
      expect(rect.color.r).to be_within(0.001).of(0.0)
      expect(rect.color.g).to be_within(0.001).of(0.0)
      expect(rect.color.b).to be_within(0.001).of(1.0)
    end
  end

  describe 'visual-less form' do
    it 'does not add anything to the render list' do
      objects = window.instance_variable_get(:@objects)
      before_count = objects.length
      Ruby2D::Button.new(x: 0, y: 0, width: 100, height: 40) { }
      expect(objects.length).to eq(before_count)
    end

    it 'still receives click events' do
      clicked = false
      Ruby2D::Button.new(x: 0, y: 0, width: 100, height: 40) { clicked = true }

      click_at(50, 20)
      expect(clicked).to be true
    end

    it 'fires :mouse_down and :mouse_up via Button#on' do
      btn = Ruby2D::Button.new(x: 0, y: 0, width: 100, height: 40)
      events = []
      btn.on(:mouse_down) { events << :down }
      btn.on(:mouse_up)   { events << :up }

      window.mouse_callback(:down, :left, nil, 50, 20, 0, 0)
      window.mouse_callback(:up,   :left, nil, 50, 20, 0, 0)
      expect(events).to eq([:down, :up])
    end

    it 'is not registered as interactive when no handlers are attached' do
      Ruby2D::Button.new(x: 0, y: 0, width: 100, height: 40)

      # An interactive shape underneath should still receive clicks because
      # the visual-less Button (with no handlers) is not in the registry.
      bottom_rect = Ruby2D::Rectangle.new(x: 0, y: 0, width: 100, height: 40)
      bottom_clicked = false
      bottom_rect.on(:click) { bottom_clicked = true }

      click_at(50, 20)
      expect(bottom_clicked).to be true
    end
  end

  describe 'lifecycle' do
    it 'unregisters from the interactive registry on remove' do
      btn = Ruby2D::Button.new(x: 0, y: 0, width: 100, height: 40) { }
      btn.remove

      clicked = false
      btn.on(:click) { clicked = true } # this re-registers
      btn.remove
      click_at(50, 20)
      expect(clicked).to be false
    end
  end

  describe 'add: false' do
    it 'is not clickable when constructed with add: false (invisible and inert)' do
      clicked = false
      Ruby2D::Button.new(x: 0, y: 0, width: 100, height: 40, add: false) { clicked = true }
      click_at(50, 20)
      expect(clicked).to be false
    end

    it 'becomes clickable once #add is called' do
      clicked = false
      btn = Ruby2D::Button.new(x: 0, y: 0, width: 100, height: 40, add: false) { clicked = true }
      btn.add
      click_at(50, 20)
      expect(clicked).to be true
    end
  end

  describe '#color' do
    it 'reads and writes the fill color through the visual' do
      btn = Ruby2D::Button.new(x: 0, y: 0, width: 100, height: 40, color: '#333333')
      btn.color = '#00ff00'
      visual = btn.instance_variable_get(:@visual)
      expect(visual.color.g).to be_within(0.001).of(1.0)
      expect(btn.color.g).to be_within(0.001).of(1.0)
    end

    it 'updates the resting (base) color when a tint is configured' do
      btn = Ruby2D::Button.new(x: 0, y: 0, width: 100, height: 40,
                               color: 'red', pressed_color: '#00ff00')
      visual = btn.instance_variable_get(:@visual)
      btn.color = '#0000ff'
      # Not pressed or hovering, so the new base color shows immediately.
      expect(visual.color.b).to be_within(0.001).of(1.0)
      expect(visual.color.r).to be_within(0.001).of(0.0)
    end

    it 'returns nil and is a no-op on a visual-less button' do
      btn = Ruby2D::Button.new(x: 0, y: 0, width: 100, height: 40)
      expect(btn.color).to be_nil
      expect { btn.color = 'red' }.not_to raise_error
    end
  end

  describe 'pressed state' do
    # Read the visual's color as an RGB triple for value-based comparison.
    def rgb_of(rect)
      [rect.color.r, rect.color.g, rect.color.b]
    end

    it 'swaps fill on :mouse_down and restores on :mouse_up' do
      btn = Ruby2D::Button.new(x: 0, y: 0, width: 100, height: 40,
                               color: 'red', pressed_color: '#0000ff')
      visual = btn.instance_variable_get(:@visual)
      base = rgb_of(visual)

      window.mouse_callback(:move, nil, nil, 50, 20, 1, 1)
      window.mouse_callback(:down, :left, nil, 50, 20, 0, 0)
      expect(visual.color.b).to be_within(0.001).of(1.0)

      window.mouse_callback(:up, :left, nil, 50, 20, 0, 0)
      expect(rgb_of(visual)).to eq(base)
    end

    it 'swaps label color on press when pressed_label_color is set' do
      btn = Ruby2D::Button.new(x: 0, y: 0, width: 100, height: 40,
                               label: 'Go', color: '#333',
                               pressed_color: '#555',
                               label_color: 'white',
                               pressed_label_color: '#000000')
      label = btn.instance_variable_get(:@label)

      window.mouse_callback(:move, nil, nil, 50, 20, 1, 1)
      window.mouse_callback(:down, :left, nil, 50, 20, 0, 0)
      expect(label.color.r).to be_within(0.001).of(0.0)

      window.mouse_callback(:up, :left, nil, 50, 20, 0, 0)
      expect(label.color.r).to be_within(0.001).of(1.0)
    end

    it 'restores rest color when press is released off-button' do
      btn = Ruby2D::Button.new(x: 0, y: 0, width: 100, height: 40,
                               color: 'red', pressed_color: '#0000ff')
      visual = btn.instance_variable_get(:@visual)
      base = rgb_of(visual)

      window.mouse_callback(:move, nil, nil, 50, 20, 1, 1)
      window.mouse_callback(:down, :left, nil, 50, 20, 0, 0)
      window.mouse_callback(:move, nil, nil, 500, 500, 450, 480)
      window.mouse_callback(:up,   :left, nil, 500, 500, 0, 0)
      expect(rgb_of(visual)).to eq(base)
    end

    it 'reverts to base on drag-out-while-held and re-engages on re-entry' do
      btn = Ruby2D::Button.new(x: 0, y: 0, width: 100, height: 40,
                               color: 'red', pressed_color: '#0000ff')
      visual = btn.instance_variable_get(:@visual)
      base = rgb_of(visual)

      window.mouse_callback(:move, nil, nil, 50, 20, 1, 1)
      window.mouse_callback(:down, :left, nil, 50, 20, 0, 0)
      expect(visual.color.b).to be_within(0.001).of(1.0)

      # Drag out — drops press tint
      window.mouse_callback(:move, nil, nil, 500, 500, 450, 480)
      expect(rgb_of(visual)).to eq(base)

      # Drag back in — press tint re-engages
      window.mouse_callback(:move, nil, nil, 50, 20, -450, -480)
      expect(visual.color.b).to be_within(0.001).of(1.0)

      window.mouse_callback(:up, :left, nil, 50, 20, 0, 0)
      expect(rgb_of(visual)).to eq(base)
    end

    it 'pressed wins over hover when both are set' do
      btn = Ruby2D::Button.new(x: 0, y: 0, width: 100, height: 40,
                               color: '#888888',
                               hover_color:   '#00ff00',
                               pressed_color: '#ff0000')
      visual = btn.instance_variable_get(:@visual)

      # Hover only → green
      window.mouse_callback(:move, nil, nil, 50, 20, 1, 1)
      expect(visual.color.g).to be_within(0.001).of(1.0)
      expect(visual.color.r).to be_within(0.001).of(0.0)

      # Press while hovering → red wins
      window.mouse_callback(:down, :left, nil, 50, 20, 0, 0)
      expect(visual.color.r).to be_within(0.001).of(1.0)
      expect(visual.color.g).to be_within(0.001).of(0.0)

      # Release while still hovering → back to green
      window.mouse_callback(:up, :left, nil, 50, 20, 0, 0)
      expect(visual.color.g).to be_within(0.001).of(1.0)
      expect(visual.color.r).to be_within(0.001).of(0.0)
    end

    it ':auto darkens for pressed and lightens for hover' do
      btn = Ruby2D::Button.new(x: 0, y: 0, width: 100, height: 40,
                               color: '#808080',
                               hover_color: :auto,
                               pressed_color: :auto)
      visual = btn.instance_variable_get(:@visual)
      base = visual.color.r

      window.mouse_callback(:move, nil, nil, 50, 20, 1, 1)
      hovered = visual.color.r
      expect(hovered).to be > base

      window.mouse_callback(:down, :left, nil, 50, 20, 0, 0)
      pressed = visual.color.r
      expect(pressed).to be < base
    end

    it 'preserves stroke through state transitions' do
      btn = Ruby2D::Button.new(x: 0, y: 0, width: 100, height: 40,
                               color: 'red', pressed_color: '#0000ff',
                               stroke_color: 'green', stroke_width: 2)
      visual = btn.instance_variable_get(:@visual)
      stroke_before = visual.stroke_color
      width_before  = visual.stroke_width

      window.mouse_callback(:move, nil, nil, 50, 20, 1, 1)
      window.mouse_callback(:down, :left, nil, 50, 20, 0, 0)
      expect(visual.stroke_color).to eq(stroke_before)
      expect(visual.stroke_width).to eq(width_before)

      window.mouse_callback(:up, :left, nil, 50, 20, 0, 0)
      expect(visual.stroke_color).to eq(stroke_before)
      expect(visual.stroke_width).to eq(width_before)
    end
  end
end
