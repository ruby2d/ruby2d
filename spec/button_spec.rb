RSpec.describe Ruby2D::Button do
  # A fresh DSL window so the button's visual auto-adds and on() can register.
  before(:each) { Ruby2D::DSL.window = Ruby2D::Window.new }

  let(:gradient) { ['red', 'blue', 'green', 'yellow'] }

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
end
