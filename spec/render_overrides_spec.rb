# A one-shot `instance.render(...)` inside a render block draws the object as
# the scene would draw it holding those values, then puts it back — even when
# the draw raises. These specs stub the viewport and the native draw calls
# and read the object's state at the moment the draw runs.
RSpec.describe 'One-shot render overrides' do
  before do
    allow(Ruby2D::Window).to receive(:shown?).and_return(true)
    allow(Ruby2D::Window).to receive(:viewport_width).and_return(800)
    allow(Ruby2D::Window).to receive(:viewport_height).and_return(600)
  end

  # Stub `ext_method` and return what `block` reads from the object at the
  # moment of the draw (nil if the draw never ran).
  def at_draw(ext_method)
    seen = nil
    allow(Ruby2D::Ext).to receive(ext_method) { |obj, *| seen = yield(obj) }
    proc { seen }
  end

  def pose(obj)
    [obj.x, obj.y]
  end

  describe Ruby2D::Image do
    let(:image) { Ruby2D::Image.new(test_image('image.png'), x: 10, y: 20, add: false) }

    it 'leaves the image as it was when an override is invalid' do
      expect { image.render(x: 200, width: 50, tint: 'not-a-color') }.to raise_error(Ruby2D::Error)
      expect { image.render(x: 200, opacity: 'faint') }.to raise_error(ArgumentError)
      expect { image.render(x: :sideways) }.to raise_error(ArgumentError)
      expect(image.x).to eq(10)
      expect(image.width).to eq(image.instance_variable_get(:@orig_width))
      expect(image.tint.to_a).to eq(Ruby2D::Color.new('white').to_a)
      expect(image.x_align).to be_nil
    end

    it 'puts the image back after the draw, even when the draw raises' do
      allow(Ruby2D::Ext).to receive(:image_draw).and_raise(RuntimeError, 'boom')
      tint = image.tint
      expect { image.render(x: 5, y: 6, width: 7, height: 8, rotate: 9, tint: '#ff0000', opacity: 0.5) }
        .to raise_error(RuntimeError)
      expect([image.x, image.y, image.width, image.height, image.rotate]).to eq([10, 20, image.instance_variable_get(:@orig_width), image.instance_variable_get(:@orig_height), 0])
      expect(image.tint).to be(tint)
    end

    it 'draws with the overrides and the given tint at the given opacity' do
      seen = at_draw(:image_draw) { |i| [i.x, i.y, i.width, i.height, i.rotate, i.tint.to_a] }
      image.render(x: 5, y: 6, width: 7, height: 8, rotate: 9, tint: '#ff0000', opacity: 0.5)
      expect(seen.call).to eq([5, 6, 7, 8, 9, [1.0, 0.0, 0.0, 0.5]])
    end

    it 'keeps the tint and fades it for an opacity-only override' do
      image.tint = '#0000ff'
      seen = at_draw(:image_draw) { |i| i.tint.to_a }
      image.render(opacity: 0.25)
      expect(seen.call).to eq([0.0, 0.0, 1.0, 0.25])
      expect(image.tint.opacity).to eq(1.0)
    end

    context 'aligned to the window' do
      let(:image) { Ruby2D::Image.new(test_image('image.png'), x: :right, y: :bottom, add: false) }

      it 'draws an aligned image where the scene would, for a tint-only override' do
        seen = at_draw(:image_draw) { |i| pose(i) }
        image.render(tint: '#ff0000')
        expect(seen.call).to eq([800 - image.width, 600 - image.height])
        expect(pose(image)).to eq([0, 0])
        expect([image.x_align, image.y_align]).to eq([:right, :bottom])
      end

      it 'aligns the axis the caller did not position' do
        seen = at_draw(:image_draw) { |i| pose(i) }
        image.render(x: 5)
        expect(seen.call).to eq([5, 600 - image.height])
        expect([image.x_align, image.y_align]).to eq([:right, :bottom])
      end

      it 'aligns against the size of this draw' do
        seen = at_draw(:image_draw) { |i| pose(i) }
        image.render(width: 100, height: 50)
        expect(seen.call).to eq([700, 550])
      end

      it 'respects the image padding' do
        image = Ruby2D::Image.new(test_image('image.png'), x: :right, y: :bottom, padding: 10, add: false)
        seen = at_draw(:image_draw) { |i| pose(i) }
        image.render(tint: '#ff0000')
        expect(seen.call).to eq([790 - image.width, 590 - image.height])
      end
    end

    it 'takes an alignment symbol as a position override, for this draw only' do
      seen = at_draw(:image_draw) { |i| pose(i) }
      image.render(x: :center, y: :bottom)
      expect(seen.call).to eq([(800 - image.width) / 2.0, 600 - image.height])
      expect(pose(image)).to eq([10, 20])
      expect([image.x_align, image.y_align]).to eq([nil, nil])
    end
  end

  describe Ruby2D::Text do
    let(:text) { Ruby2D::Text.new('hi', x: :right, y: :bottom, add: false) }

    it 'leaves the text as it was when an override is invalid' do
      text = Ruby2D::Text.new('hi', x: 10, add: false)
      expect { text.render(x: 200, rotate: 45, color: 'not-a-color') }.to raise_error(Ruby2D::Error)
      expect([text.x, text.rotate]).to eq([10, 0])
    end

    it 'draws an aligned text where the scene would, for a color-only override' do
      seen = at_draw(:text_draw) { |t| [pose(t), t.color.to_a] }
      text.render(colour: '#ff0000')
      expect(seen.call).to eq([[800 - text.width, 600 - text.height], [1.0, 0.0, 0.0, 1.0]])
      expect(pose(text)).to eq([0, 0])
      expect(text.color.to_a).to eq([1.0, 1.0, 1.0, 1.0])
    end

    it 'aligns the axis the caller did not position' do
      seen = at_draw(:text_draw) { |t| pose(t) }
      text.render(y: 5)
      expect(seen.call).to eq([800 - text.width, 5])
    end

    it 'rotates about the drawn position' do
      seen = nil
      allow(Ruby2D::Ext).to receive(:text_draw) { |_t, rx, ry| seen = [rx, ry] }
      text.render(x: 100, y: 50, rotate: 90)
      expect(seen).to eq([100 + text.width / 2.0, 50 + text.height / 2.0])
    end
  end

  describe Ruby2D::BitmapText do
    let(:text) { Ruby2D::BitmapText.new('HI', x: 10, y: 20, scale: 1, add: false) }

    it 'leaves the text as it was when an override is invalid' do
      expect { text.render(x: 200, scale: -1) }.to raise_error(Ruby2D::Error)
      expect { text.render(x: 200, color: 'not-a-color') }.to raise_error(Ruby2D::Error)
      expect { text.render(x: :center) }.to raise_error(Ruby2D::Error, /must be a number/)
      expect([text.x, text.scale]).to eq([10, 1])
    end

    it 'rotates a scaled draw about the center of the scaled text' do
      scaled = Ruby2D::BitmapText.new('HI', scale: 3, add: false)
      seen = nil
      allow(Ruby2D::Ext).to receive(:bitmap_text_draw) { |t, rx, ry| seen = [t.scale, t.width, t.height, rx, ry] }
      text.render(x: 100, y: 20, scale: 3, rotate: 180)
      expect(seen).to eq([3, scaled.width, scaled.height, 100 + scaled.width / 2.0, 20 + scaled.height / 2.0])
      expect([text.scale, text.width, text.height]).to eq([1, scaled.width / 3, scaled.height / 3])
    end

    it 'keeps an explicit rotation center' do
      text.rx = 3
      text.ry = 4
      seen = nil
      allow(Ruby2D::Ext).to receive(:bitmap_text_draw) { |_t, rx, ry| seen = [rx, ry] }
      text.render(scale: 2, rotate: 45)
      expect(seen).to eq([3, 4])
    end

    it 'draws the given color at the given opacity and puts the color back' do
      color = text.color
      seen = at_draw(:bitmap_text_draw) { |t| t.color.to_a }
      text.render(color: '#ff0000', opacity: 0.5)
      expect(seen.call).to eq([1.0, 0.0, 0.0, 0.5])
      expect(text.color).to be(color)
    end
  end

  describe Ruby2D::Canvas do
    let(:canvas) { Ruby2D::Canvas.new(width: 40, height: 30, x: 10, y: 20, add: false) }

    it 'leaves the canvas as it was when an override is invalid' do
      expect { canvas.render(x: 200, tint: 'not-a-color') }.to raise_error(Ruby2D::Error)
      expect { canvas.render(x: :center) }.to raise_error(Ruby2D::Error, /must be a number/)
      expect([canvas.x, canvas.y]).to eq([10, 20])
    end

    it 'draws with the overrides and rotates about the drawn size, then puts the canvas back' do
      seen = nil
      allow(Ruby2D::Ext).to receive(:canvas_draw) { |c, rx, ry| seen = [c.x, c.y, c.width, c.height, c.rotate, c.tint.to_a, rx, ry] }
      canvas.render(x: 100, y: 50, width: 80, height: 60, rotate: 90, tint: '#ff0000', opacity: 0.5)
      expect(seen).to eq([100, 50, 80, 60, 90, [1.0, 0.0, 0.0, 0.5], 140.0, 80.0])
      expect([canvas.x, canvas.y, canvas.width, canvas.height, canvas.rotate]).to eq([10, 20, 40, 30, 0])
      expect(canvas.tint.to_a).to eq([1.0, 1.0, 1.0, 1.0])
    end
  end

  describe Ruby2D::Sprite do
    include_context 'sprite sheet'

    let(:trimmed_rect) do
      { x: 0, y: 0, width: 80, height: 120,
        source_width: 256, source_height: 256, trim_x: 40, trim_y: 70 }
    end

    def geometry(sprite)
      [sprite.clip_x, sprite.clip_y, sprite.clip_width, sprite.clip_height,
       sprite.instance_variable_get(:@source_width), sprite.instance_variable_get(:@source_height),
       sprite.instance_variable_get(:@trim_x), sprite.instance_variable_get(:@trim_y),
       sprite.width, sprite.height]
    end

    let(:trimmed) do
      stub_frame(sheet, 'tr', trimmed_rect)
      Ruby2D::Sprite.new(sheet, frame: 'tr', x: 10, y: 20, add: false)
    end

    it 'leaves the sprite as it was when an override is invalid' do
      expect { trimmed.render(x: 200, clip_x: 5, tint: 'not-a-color') }.to raise_error(Ruby2D::Error)
      expect(trimmed.x).to eq(10)
      expect(geometry(trimmed)).to eq([0, 0, 80, 120, 256, 256, 40, 70, 256, 256])
    end

    it 'keeps a trimmed frame as it is for a position, tint, or opacity override' do
      seen = at_draw(:image_draw) { |s| [pose(s), geometry(s), s.tint.to_a] }
      trimmed.render(x: 20)
      expect(seen.call).to eq([[20, 20], [0, 0, 80, 120, 256, 256, 40, 70, 256, 256], [1.0, 1.0, 1.0, 1.0]])
      trimmed.render(opacity: 0.5)
      expect(seen.call).to eq([[10, 20], [0, 0, 80, 120, 256, 256, 40, 70, 256, 256], [1.0, 1.0, 1.0, 0.5]])
    end

    it 'draws a clip override like the clip setter would, then puts the frame back' do
      seen = at_draw(:image_draw) { |s| geometry(s) }
      trimmed.render(clip_x: 8, clip_width: 30)
      expect(seen.call).to eq([8, 0, 30, 120, 30, 256, 0, 70, 30, 256])
      trimmed.render(clip_width: 30, width: 60)
      expect(seen.call).to eq([0, 0, 30, 120, 30, 256, 0, 70, 60, 256])
      expect(geometry(trimmed)).to eq([0, 0, 80, 120, 256, 256, 40, 70, 256, 256])

      sized = Ruby2D::Sprite.new(sheet, frame: 'tr', width: 50, add: false)
      sized.render(clip_width: 30, clip_height: 40)
      expect(seen.call).to eq([0, 0, 30, 40, 30, 40, 0, 0, 50, 40])
    end

    it 'validates a position override before advancing the animation' do
      strip = Ruby2D::Sprite.new("#{Ruby2D.test_spritesheets}/coin.png", clip_width: 84, time: 100,
                                                                           animations: { walk: 0..3 }, add: false)
      allow(Ruby2D::Ext).to receive(:image_draw)
      strip.play(animation: :walk, loop: true)
      allow(Ruby2D::Window).to receive(:_clock).and_return(5.0)
      strip.render(x: 1)
      allow(Ruby2D::Window).to receive(:_clock).and_return(5.35)
      expect { strip.render(x: :sideways) }.to raise_error(ArgumentError, /sideways/)
      expect { strip.render(y: 'low') }.to raise_error(ArgumentError, /"low"/)
      expect(strip.clip_x).to eq(0)
      strip.render(x: 1)
      expect(strip.clip_x).to eq(252)
    end

    it 'draws an aligned sprite where the scene would, against the size of this draw' do
      stub_frame(sheet, 'tr', trimmed_rect)
      sprite = Ruby2D::Sprite.new(sheet, frame: 'tr', x: :right, y: :bottom, add: false)
      seen = at_draw(:image_draw) { |s| pose(s) }
      sprite.render(tint: '#ff0000')
      expect(seen.call).to eq([800 - 256, 600 - 256])
      sprite.render(width: 100, height: 50)
      expect(seen.call).to eq([700, 550])
      expect(pose(sprite)).to eq([0, 0])
    end

    it 'advances a playing animation like a scene draw, once per tick' do
      strip = Ruby2D::Sprite.new("#{Ruby2D.test_spritesheets}/coin.png", clip_width: 84, time: 100,
                                                                           animations: { walk: 0..3 }, add: false)
      allow(Ruby2D::Ext).to receive(:image_draw)
      strip.play(animation: :walk, loop: true)
      allow(Ruby2D::Window).to receive(:_clock).and_return(5.0)
      strip.render(x: 1)
      expect(strip.clip_x).to eq(0)
      allow(Ruby2D::Window).to receive(:_clock).and_return(5.15)
      strip.render(x: 1)
      strip.render(x: 2)
      expect(strip.clip_x).to eq(84)
    end

    it 'draws a hidden sprite, but not when hidden by its own completion block' do
      strip = Ruby2D::Sprite.new("#{Ruby2D.test_spritesheets}/coin.png", clip_width: 84, time: 100,
                                                                           animations: { walk: 0..1 }, add: false)
      draws = 0
      allow(Ruby2D::Ext).to receive(:image_draw) { draws += 1 }
      strip.play(animation: :walk, loop: false) { strip.visible = false }
      allow(Ruby2D::Window).to receive(:_clock).and_return(5.0)
      strip.render(x: 1)
      expect(draws).to eq(1)
      allow(Ruby2D::Window).to receive(:_clock).and_return(5.25)
      strip.render(x: 1)
      expect(draws).to eq(1)
      expect(strip.visible?).to be(false)
      strip.render(x: 1)
      expect(draws).to eq(2)
    end

    it 'fades the tint a completion block just set for an opacity-only override' do
      strip = Ruby2D::Sprite.new("#{Ruby2D.test_spritesheets}/coin.png", clip_width: 84, time: 100,
                                                                           animations: { walk: 0..1 }, add: false)
      seen = at_draw(:image_draw) { |s| s.tint.to_a }
      strip.play(animation: :walk, loop: false) { strip.tint = '#0000ff' }
      allow(Ruby2D::Window).to receive(:_clock).and_return(5.0)
      strip.render(opacity: 0.5)
      expect(seen.call).to eq([1.0, 1.0, 1.0, 0.5])
      allow(Ruby2D::Window).to receive(:_clock).and_return(5.25)
      strip.render(opacity: 0.5)
      expect(seen.call).to eq([0.0, 0.0, 1.0, 0.5])
      expect(strip.tint.to_a).to eq([0.0, 0.0, 1.0, 1.0])
    end
  end
end
