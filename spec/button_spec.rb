RSpec.describe Ruby2D::Button do
  # A fresh DSL window so the button's visual auto-adds and on() can register.
  before(:each) { Ruby2D::DSL.window = Ruby2D::Window.new }

  let(:window) { Ruby2D::DSL.window }
  let(:gradient) { ['red', 'blue', 'green', 'yellow'] }

  def rgb(object)
    [object.color.r, object.color.g, object.color.b]
  end

  def press(button = :left, x = 25, y = 25)
    window.mouse_callback(:down, button, nil, x, y, nil, nil)
  end

  def release(button = :left, x = 25, y = 25)
    window.mouse_callback(:up, button, nil, x, y, nil, nil)
  end

  def move_to(x, y)
    window.mouse_callback(:move, nil, nil, x, y, 0, 0)
  end

  describe 'gradient fill with a hover/pressed tint' do
    it 'does not raise when combining a gradient fill with :auto tints' do
      expect do
        Ruby2D::Button.new(color: gradient, hover_color: :auto, pressed_color: :auto)
      end.not_to raise_error
    end

    it 'lightens every vertex on hover and darkens every vertex on press' do
      button  = Ruby2D::Button.new(color: gradient, hover_color: :auto, pressed_color: :auto)
      base    = button.instance_variable_get(:@base_color)
      hover   = button.instance_variable_get(:@hover_color)
      pressed = button.instance_variable_get(:@pressed_color)

      expect(base).to be_a(Ruby2D::Color::Set)
      expect(hover).to be_a(Ruby2D::Color::Set)
      expect(pressed).to be_a(Ruby2D::Color::Set)
      expect(hover.length).to eq(4)

      4.times do |i|
        # lighten only raises channels (clamped), darken only lowers them
        expect(hover.vertex(i).r).to be >= base.vertex(i).r
        expect(pressed.vertex(i).r).to be <= base.vertex(i).r
      end
    end

    it 'applies the gradient hover tint to the visual on hover' do
      button = Ruby2D::Button.new(color: gradient, hover_color: :auto)
      button._fire_event(:hover, nil)

      # #color reports the resting base; the live tint lands on the visual
      visual = button.instance_variable_get(:@visual)
      hover  = button.instance_variable_get(:@hover_color)
      expect(visual.color).to be_a(Ruby2D::Color::Set)
      expect(visual.color.length).to eq(4)
      4.times { |i| expect(visual.color.vertex(i).to_a).to eq(hover.vertex(i).to_a) }
    end

    it 'reverts to the base gradient on hover_out' do
      button = Ruby2D::Button.new(color: gradient, hover_color: :auto)
      base = button.instance_variable_get(:@base_color)

      button._fire_event(:hover, nil)
      button._fire_event(:hover_out, nil)

      4.times { |i| expect(button.color.vertex(i).to_a).to eq(base.vertex(i).to_a) }
    end

    it 'accepts an explicit gradient as the hover color' do
      button = Ruby2D::Button.new(color: gradient, hover_color: %w[white white white white])
      hover = button.instance_variable_get(:@hover_color)
      expect(hover).to be_a(Ruby2D::Color::Set)
      expect(hover.length).to eq(4)
    end
  end

  describe 'label centering' do
    # A stand-in label with known metrics, so centering math is exercised
    # without loading a font/texture. center_label only reads width/height and
    # writes x/y.
    def fake_label(width, height)
      Struct.new(:width, :height, :x, :y).new(width, height, 0, 0)
    end

    it 'centers the label on a wrapped Circle (center anchor, not top-left)' do
      circle = Ruby2D::Circle.new(x: 200, y: 150, radius: 50, add: false)
      button = Ruby2D::Button.new(circle, add: false)
      label  = fake_label(40, 20)
      button.instance_variable_set(:@label, label)

      button.send(:center_label)

      # Circle center is (200, 150); the label centers on that center
      expect(label.x).to be_within(1e-6).of(200 - 40 / 2.0) # 180
      expect(label.y).to be_within(1e-6).of(150 - 20 / 2.0) # 140
    end

    it 'centers the label on a wrapped Ellipse' do
      ellipse = Ruby2D::Ellipse.new(x: 200, y: 150, xradius: 80, yradius: 40, add: false)
      button  = Ruby2D::Button.new(ellipse, add: false)
      label   = fake_label(40, 20)
      button.instance_variable_set(:@label, label)

      button.send(:center_label)

      expect(label.x).to be_within(1e-6).of(200 - 40 / 2.0) # 180
      expect(label.y).to be_within(1e-6).of(150 - 20 / 2.0) # 140
    end

    it 'centers the label on a top-left-anchored self-rendered button' do
      button = Ruby2D::Button.new(x: 0, y: 0, width: 200, height: 50, color: 'navy', add: false)
      label  = fake_label(40, 20)
      button.instance_variable_set(:@label, label)

      button.send(:center_label)

      expect(label.x).to be_within(1e-6).of((200 - 40) / 2.0) # 80
      expect(label.y).to be_within(1e-6).of((50 - 20) / 2.0)  # 15
    end

    # The centroid-anchored vertex shapes: `x`/`y` is the centroid, so the
    # label is centered on the bounding box, not placed at the centroid.
    it 'centers the label on the bounding box of a wrapped Quad, Triangle, Polygon, and Polyline' do
      shapes = [
        Ruby2D::Quad.new(points: [[20, 20], [120, 20], [120, 60], [20, 60]], add: false),
        Ruby2D::Triangle.new(points: [[20, 60], [120, 60], [70, 20]], add: false),
        Ruby2D::Polygon.new(points: [[20, 20], [120, 20], [120, 60], [70, 40], [20, 60]], add: false),
        Ruby2D::Polyline.new(points: [[20, 20], [120, 20], [120, 60], [20, 60]], add: false)
      ]
      shapes.each do |shape|
        button = Ruby2D::Button.new(shape, add: false)
        label  = fake_label(40, 20)
        button.instance_variable_set(:@label, label)

        button.send(:center_label)

        # The box is (20, 20)-(120, 60) for each, so the label centers on (70, 40)
        expect(label.x).to be_within(1e-6).of(70 - 40 / 2.0), shape.class.name
        expect(label.y).to be_within(1e-6).of(40 - 20 / 2.0), shape.class.name
      end
    end

    it 'follows a wrapped visual that was resized or moved directly' do
      rect   = Ruby2D::Rectangle.new(x: 0, y: 20, width: 100, height: 40, add: false)
      button = Ruby2D::Button.new(rect, label: 'Go', add: false)
      label  = button.instance_variable_get(:@label)

      rect.width = 200
      rect.x = 50
      button.send(:center_label)

      expect(label.x + label.width / 2.0).to be_within(1e-6).of(150)
      expect(label.y + label.height / 2.0).to be_within(1e-6).of(40)
    end
  end

  describe 'drawing the label' do
    it 'draws the label with the visual, re-centered on its current box, instead of as a scene object' do
      rect   = Ruby2D::Rectangle.new(x: 0, y: 0, width: 100, height: 40)
      button = Ruby2D::Button.new(rect, label: 'Go')
      label  = button.instance_variable_get(:@label)
      objects = window.instance_variable_get(:@objects)
      expect(objects).to include(rect)
      expect(objects).not_to include(label)

      calls = []
      allow(Ruby2D::Ext).to receive(:draw_quad_uniform) { |*args| calls << :visual }
      allow(Ruby2D::Ext).to receive(:text_draw) { |*args| calls << :label }
      rect.width = 300
      rect._render_scene

      expect(calls).to eq([:visual, :label])
      expect(label.x + label.width / 2.0).to be_within(1e-6).of(150)
    end

    it 'keeps the label at the depth of a wrapped visual restacked directly' do
      rect   = Ruby2D::Rectangle.new(x: 0, y: 0, width: 100, height: 40)
      button = Ruby2D::Button.new(rect, label: 'Go')
      label  = button.instance_variable_get(:@label)

      rect.z = 10

      # The raised visual draws last, and the label with it, not from a
      # scene position of its own that the visual would now cover
      expect(button.z).to eq(10)
      objects = window.instance_variable_get(:@objects)
      expect(objects.last).to be(rect)
      expect(objects).not_to include(label)
      calls = []
      allow(Ruby2D::Ext).to receive(:draw_quad_uniform) { calls << :visual }
      allow(Ruby2D::Ext).to receive(:text_draw) { |text, *| calls << :label if text.equal?(label) }
      rect._render_scene
      expect(calls).to eq([:visual, :label])
    end

    it 'moves the visual with z= and re-sorts a visual-less button' do
      button = Ruby2D::Button.new(x: 0, y: 0, width: 100, height: 40, color: 'navy')
      visual = button.instance_variable_get(:@visual)
      button.z = 3
      expect(visual.z).to eq(3)
      expect(button.z).to eq(3)

      under = Ruby2D::Button.new(x: 0, y: 0, width: 100, height: 40) { }
      over  = Ruby2D::Button.new(x: 0, y: 0, width: 100, height: 40) { }
      expect(window.topmost_interactive_at(10, 10)).to be(over)
      under.z = 5
      expect(under.z).to eq(5)
      expect(window.topmost_interactive_at(10, 10)).to be(under)
    end
  end

  describe 'wrapping a visual' do
    it 'rejects a Line, which has no position to move or to center a label on' do
      line = Ruby2D::Line.new(x1: 0, y1: 0, x2: 100, y2: 0, add: false)
      expect { Ruby2D::Button.new(line) }
        .to raise_error(ArgumentError, /can't wrap a `Ruby2D::Line`/)
    end

    it 'takes the visual into and out of the scene with add:, add, and remove' do
      rect = Ruby2D::Rectangle.new(x: 0, y: 0, width: 100, height: 40, add: false)
      objects = window.instance_variable_get(:@objects)

      button = Ruby2D::Button.new(rect)
      expect(objects).to include(rect)

      button.remove
      expect(objects).not_to include(rect)

      button.add
      expect(objects).to include(rect)

      added = Ruby2D::Rectangle.new(x: 0, y: 0, width: 100, height: 40)
      Ruby2D::Button.new(added, add: false)
      expect(objects).not_to include(added)
    end

    it 'reads position, size, depth, and visibility from the visual live' do
      circle = Ruby2D::Circle.new(x: 50, y: 50, radius: 20, z: 2)
      button = Ruby2D::Button.new(circle)

      circle.x = 80
      circle.radius = 30
      circle.z = 7
      circle.hide

      expect([button.x, button.y]).to eq([80, 50])
      expect([button.width, button.height]).to eq([60, 60])
      expect(button.z).to eq(7)
      expect(button.visible?).to be false
      expect(button.contains?(105, 50)).to be true

      # The owned visual too, which used to be copied at construction: its
      # alignment resolves at draw time, and the button reads the result
      owned  = Ruby2D::Button.new(x: 0, y: 0, width: 100, height: 40, color: 'navy', label: 'Go')
      visual = owned.instance_variable_get(:@visual)
      visual.x = 300
      visual.width = 50
      expect(owned.x).to eq(300)
      expect(owned.width).to eq(50)
      expect(owned.contains?(340, 20)).to be true
      expect(owned.contains?(50, 20)).to be false
    end

    it 'forwards alignment and padding to the visual, and ignores them without one' do
      rect   = Ruby2D::Rectangle.new(x: 0, y: 0, width: 100, height: 40, add: false)
      button = Ruby2D::Button.new(rect, add: false)
      button.x = :right
      button.padding_right = 12
      expect(rect.x_align).to eq(:right)
      expect(rect.padding_right).to eq(12)
      expect(button.padding_right).to eq(12)

      quad = Ruby2D::Quad.new(add: false)
      expect { Ruby2D::Button.new(quad, add: false).x = :center }.to raise_error(Ruby2D::Error, /Quad x must be a number/)

      hit_area = Ruby2D::Button.new(x: 0, y: 0, width: 100, height: 40, add: false)
      hit_area.x = :right
      hit_area.padding = 12
      expect(hit_area.x).to eq(0)
      expect(hit_area.padding_left).to be_nil
    end
  end

  describe 'padding accessors' do
    it "read and write the owned visual's padding" do
      button = Ruby2D::Button.new(x: :right, y: 0, width: 100, height: 40, color: 'navy',
                                  padding: 16, add: false)
      visual = button.instance_variable_get(:@visual)
      expect(button.padding_right).to eq(16)

      button.padding_right = 32
      button.padding_top = 4
      expect(visual.padding_right).to eq(32)
      expect(visual.padding_top).to eq(4)

      button.padding = 8
      expect([visual.padding_top, visual.padding_right, visual.padding_bottom, visual.padding_left]).to eq([8, 8, 8, 8])
      expect([button.padding_top, button.padding_right, button.padding_bottom, button.padding_left]).to eq([8, 8, 8, 8])
    end
  end

  describe 'visibility' do
    it 'assigns visible= like show and hide, on the visual' do
      owned   = Ruby2D::Button.new(x: 0, y: 0, width: 100, height: 40, label: 'Go', add: false)
      wrapped = Ruby2D::Button.new(Ruby2D::Rectangle.new(width: 100, height: 40, add: false), add: false)
      [owned, wrapped].each do |button|
        visual = button.instance_variable_get(:@visual)
        button.visible = false
        expect(button.visible?).to be false
        expect(visual.visible?).to be false
        button.visible = true
        expect(button.visible?).to be true
        expect(visual.visible?).to be true
      end
    end

    it 'keeps its own flag on a visual-less button' do
      button = Ruby2D::Button.new(x: 0, y: 0, width: 100, height: 40, add: false)
      button.visible = false
      expect(button.visible?).to be false
      button.show
      expect(button.visible?).to be true
    end
  end

  describe 'tints on a visual without a color' do
    let(:image) { Ruby2D::Image.new(test_image('image.png'), add: false) }

    it 'tints the label of a Button wrapping an Image or Canvas' do
      canvas = Ruby2D::Canvas.new(width: 100, height: 40, add: false)
      [image, canvas].each do |visual|
        button = Ruby2D::Button.new(visual, label: 'Go', hover_label_color: 'yellow', add: false)
        label  = button.instance_variable_get(:@label)
        button._fire_event(:hover, nil)
        expect(rgb(label)).to eq(rgb(Ruby2D::Text.new('', color: 'yellow', add: false)))
        button._fire_event(:hover_out, nil)
        expect(rgb(label)).to eq([1.0, 1.0, 1.0])
      end
    end

    it 'rejects a fill tint on a visual with no color, and on a visual-less button' do
      expect { Ruby2D::Button.new(image, hover_color: :auto, add: false) }
        .to raise_error(ArgumentError, /`Ruby2D::Image` has no `color`/)
      expect { Ruby2D::Button.new(x: 0, y: 0, width: 100, height: 40, pressed_color: 'red', add: false) }
        .to raise_error(ArgumentError, /visual-less `Button` draws nothing/)
    end
  end

  describe ':auto tints after a color change' do
    it 'derives the hover and pressed tints from the new base color' do
      button = Ruby2D::Button.new(x: 0, y: 0, width: 100, height: 50, color: '#f00',
                                  hover_color: :auto, pressed_color: :auto)
      visual = button.instance_variable_get(:@visual)
      button.color = '#00f'

      move_to(25, 25)
      expect(visual.color.to_a).to eq([0.15, 0.15, 1.0, 1.0])
      press
      expect(visual.color.to_a).to eq([0.0, 0.0, 0.85, 1.0])
    end

    it 'keeps an explicit tint as it was' do
      button = Ruby2D::Button.new(x: 0, y: 0, width: 100, height: 50, color: '#f00',
                                  hover_color: '#0f0')
      visual = button.instance_variable_get(:@visual)
      button.color = '#00f'

      move_to(25, 25)
      expect(rgb(visual)).to eq([0.0, 1.0, 0.0])
    end

    it 'derives the tints per vertex from a new gradient base' do
      button = Ruby2D::Button.new(x: 0, y: 0, width: 100, height: 50, color: gradient,
                                  hover_color: :auto, pressed_color: :auto)
      visual = button.instance_variable_get(:@visual)
      button.color = %w[navy blue teal aqua]
      base = button.color

      move_to(25, 25)
      4.times { |i| expect(visual.color.vertex(i).r).to be_within(1e-6).of([base.vertex(i).r + 0.15, 1.0].min) }
      press
      4.times { |i| expect(visual.color.vertex(i).b).to be_within(1e-6).of([base.vertex(i).b - 0.15, 0.0].max) }
      expect(visual.color.vertex(3).to_a).not_to eq(visual.color.vertex(0).to_a)
    end
  end

  describe 'press state' do
    let(:button) do
      Ruby2D::Button.new(x: 0, y: 0, width: 50, height: 50, color: '#00f',
                         hover_color: '#0f0', pressed_color: '#f00')
    end
    let(:visual) { button.instance_variable_get(:@visual) }

    it 'tints on a press with no prior mouse move, as on a button that appeared under the cursor' do
      move_to(25, 25)
      button
      press
      expect(rgb(visual)).to eq([1.0, 0.0, 0.0])

      # A drag out still drops the tint, and a drag back in restores it
      move_to(200, 200)
      expect(rgb(visual)).to eq([0.0, 0.0, 1.0])
      move_to(25, 25)
      expect(rgb(visual)).to eq([1.0, 0.0, 0.0])
    end

    it 'stays pressed until the last of several mouse buttons is released' do
      button
      move_to(25, 25)
      press(:left)
      press(:right)
      release(:right)
      expect(rgb(visual)).to eq([1.0, 0.0, 0.0])

      release(:left)
      expect(rgb(visual)).to eq([0.0, 1.0, 0.0])
    end

    it 'is cancelled by remove, so the re-added button hovers without a stale press' do
      button
      move_to(25, 25)
      press
      button.remove
      expect(rgb(visual)).to eq([0.0, 0.0, 1.0])

      release(:left, 100, 100)
      button.add
      move_to(26, 25)
      expect(rgb(visual)).to eq([0.0, 1.0, 0.0])
    end

    it 'is cancelled by removing the wrapped visual directly, with the capture and hover it held' do
      rect = Ruby2D::Rectangle.new(x: 0, y: 0, width: 50, height: 50, color: '#00f')
      Ruby2D::Button.new(rect, hover_color: '#0f0', pressed_color: '#f00')
      events = []
      rect.on(:mouse_held) { events << :held }
      move_to(25, 25)
      press
      rect.remove
      expect(rgb(rect)).to eq([0.0, 0.0, 1.0])
      window.mouse_callback(:held, :left, nil, 25, 25, nil, nil)
      expect(events).to eq([])
      expect(window.instance_variable_get(:@pressed_objects)).to be_empty
      expect(window.instance_variable_get(:@hovered_object)).to be_nil

      release(:left, 100, 100)
      rect.add
      move_to(26, 25)
      expect(rgb(rect)).to eq([0.0, 1.0, 0.0])
    end

    it 'is cancelled by clearing the window' do
      button
      move_to(25, 25)
      press
      window.clear
      expect(rgb(visual)).to eq([0.0, 0.0, 1.0])

      button.add
      move_to(26, 25)
      expect(rgb(visual)).to eq([0.0, 1.0, 0.0])
    end

    it 'survives an add on a button that is already added' do
      button
      move_to(25, 25)
      button.add
      expect(rgb(visual)).to eq([0.0, 1.0, 0.0])
    end
  end

  describe 'after the window is cleared' do
    it 'is dormant, with or without a visual, until added again' do
      drawn = Ruby2D::Button.new(x: 0, y: 0, width: 50, height: 50, color: '#00f') { }
      hit_area = Ruby2D::Button.new(x: 100, y: 0, width: 50, height: 50) { }
      # Not registered when the window is cleared, having no handler yet
      idle_area = Ruby2D::Button.new(x: 200, y: 0, width: 50, height: 50)
      window.clear

      clicks = []
      drawn.on(:click) { clicks << :drawn }
      hit_area.on(:click) { clicks << :hit_area }
      idle_area.on(:click) { clicks << :idle_area }
      [25, 125, 225].each do |x|
        press(:left, x, 25)
        release(:left, x, 25)
      end
      expect(clicks).to eq([])

      drawn.add
      hit_area.add
      idle_area.add
      [25, 125, 225].each do |x|
        press(:left, x, 25)
        release(:left, x, 25)
      end
      expect(clicks).to eq([:drawn, :hit_area, :idle_area])
    end
  end

  describe 'moving a wrapped visual via x=/y=' do
    it 'moves the visual, the getter, and the hit region together' do
      rect   = Ruby2D::Rectangle.new(x: 100, y: 100, width: 50, height: 50, add: false)
      button = Ruby2D::Button.new(rect, add: false)

      # Before: the (delegated) hit region sits on the visual's start position
      expect(button.contains?(120, 120)).to be true
      expect(button.contains?(320, 220)).to be false

      button.x = 300
      button.y = 200

      expect(rect.x).to eq(300)    # the wrapped visual moved
      expect(rect.y).to eq(200)
      expect(button.x).to eq(300)  # the getter agrees with the setter
      expect(button.y).to eq(200)
      expect(button.contains?(320, 220)).to be true  # hit region followed
      expect(button.contains?(120, 120)).to be false
    end

    it 'keeps a wrapped center-anchored Circle in sync' do
      circle = Ruby2D::Circle.new(x: 200, y: 150, radius: 30, add: false)
      button = Ruby2D::Button.new(circle, add: false)

      button.x = 400

      expect(circle.x).to eq(400)                     # Circle center moved
      expect(button.x).to eq(400)
      expect(button.contains?(400, 150)).to be true   # new center is inside
      expect(button.contains?(200, 150)).to be false  # old center no longer is
    end
  end

  describe 'solid fill with an :auto tint (no regression)' do
    it 'keeps a single Color for solid fills' do
      button = Ruby2D::Button.new(color: 'navy', hover_color: :auto, pressed_color: :auto)
      base  = button.instance_variable_get(:@base_color)
      hover = button.instance_variable_get(:@hover_color)

      expect(base).to be_a(Ruby2D::Color)
      expect(hover).to be_a(Ruby2D::Color)
      expect(hover.r).to be >= base.r
    end
  end

  describe '#color on a tinted button' do
    it 'returns the resting base color, not the live tint, while hovered' do
      button = Ruby2D::Button.new(color: 'navy', hover_color: :auto)
      base   = button.instance_variable_get(:@base_color)
      button._fire_event(:hover, nil) # visual now shows the lightened tint

      expect(button.color.to_a).to eq(base.to_a)
      expect(button.color.to_a)
        .not_to eq(button.instance_variable_get(:@visual).color.to_a)
    end

    it 'round-trips a set value while hovered (get matches set)' do
      button = Ruby2D::Button.new(color: 'navy', hover_color: :auto)
      button._fire_event(:hover, nil)
      button.color = 'lime'

      expect(button.color.to_a).to eq(Ruby2D::Color.new('lime').to_a)
    end

    it 'accepts a gradient on a tinted button without raising' do
      button = Ruby2D::Button.new(color: 'navy', hover_color: :auto)

      expect { button.color = ['red', 'blue', 'green', 'yellow'] }.not_to raise_error
      expect(button.color).to be_a(Ruby2D::Color::Set)
      expect(button.color.length).to eq(4)
    end
  end

  describe 'label tint without a label' do
    it 'raises when hover_label_color is given without a label (wrapped visual)' do
      circle = Ruby2D::Circle.new(x: 0, y: 0, radius: 20, add: false)
      expect { Ruby2D::Button.new(circle, hover_label_color: 'red') }
        .to raise_error(ArgumentError, /require a `label:`/)
    end

    it 'raises when pressed_label_color is given without a label (self-rendered)' do
      expect { Ruby2D::Button.new(color: 'navy', pressed_label_color: 'red') }
        .to raise_error(ArgumentError, /require a `label:`/)
    end

    it 'does not raise when a label is present' do
      expect { Ruby2D::Button.new(color: 'navy', label: 'Go', hover_label_color: 'red') }
        .not_to raise_error
    end
  end

  describe '#contains? on a button not wrapping a visual' do
    it 'is half-open like a Rectangle, so the right and bottom edges are outside' do
      visual_less = Ruby2D::Button.new(x: 10, y: 10, width: 100, height: 40, add: false)
      self_drawn  = Ruby2D::Button.new(x: 10, y: 10, width: 100, height: 40, color: 'navy', add: false)
      [visual_less, self_drawn].each do |button|
        expect(button.contains?(10, 10)).to be true
        expect(button.contains?(109, 49)).to be true
        expect(button.contains?(110, 30)).to be false
        expect(button.contains?(50, 50)).to be false
      end
    end
  end
end
