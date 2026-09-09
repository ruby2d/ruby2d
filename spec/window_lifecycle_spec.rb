# A frame draws the scene list as it stood when the frame began. Callbacks
# that run mid-draw (a Sprite's completion block, the render block) may edit
# the scene; the edit lands on a copy and shows from the next frame, so no
# object drawing this frame is skipped or drawn twice by the shift.
RSpec.describe 'Window scene edits while a frame draws' do
  let(:window) { Ruby2D::Window.new }
  let(:log) { [] }

  # A minimal drawable that logs its name when drawn and runs `on_draw` first,
  # standing in for a callback fired from inside `_render_scene`.
  def drawable(name, z: 0, &on_draw)
    entries = log
    Object.new.tap do |obj|
      obj.define_singleton_method(:z) { z }
      obj.define_singleton_method(:visible?) { true }
      obj.define_singleton_method(:_render_scene) do
        on_draw&.call
        entries << name
      end
    end
  end

  it 'still draws the object after one that removes itself mid-draw' do
    first = drawable(:first) { window.remove(first) }
    second = drawable(:second)
    window.add([first, second])

    window.render_objects

    expect(log).to eq(%i[first second])
    expect(window.instance_variable_get(:@objects)).to eq([second])
  end

  it 'draws an object added mid-draw from the next frame' do
    late = drawable(:late)
    first = drawable(:first) { window.add(late) unless log.include?(:first) }
    window.add(first)

    window.render_objects
    expect(log).to eq(%i[first])

    window.render_objects
    expect(log).to eq(%i[first first late])
  end

  it 'finishes the frame when the render block clears the scene' do
    window.add([drawable(:a), drawable(:b)])
    window.render(z: :background) { window.clear }

    window.render_objects

    expect(log).to eq(%i[a b])
    expect(window.instance_variable_get(:@objects)).to be_empty
  end

  it 'draws the frame it was in from the reordered list only next frame' do
    low = drawable(:low, z: 0)
    high = drawable(:high, z: 5)
    first = drawable(:first, z: 1) do
      high.define_singleton_method(:z) { -1 }
      window.reorder(high)
    end
    window.add([low, first, high])

    window.render_objects
    expect(log).to eq(%i[low first high])

    window.render_objects
    expect(log.last(3)).to eq(%i[high low first])
  end

  it 'edits the live list directly outside a frame' do
    obj = drawable(:obj)
    window.add(obj)
    list = window.instance_variable_get(:@objects)
    window.remove(obj)
    expect(window.instance_variable_get(:@objects)).to equal(list)
  end
end

# `show` runs the frame loop and marks the window as no longer running when it
# returns. An exception out of a callback ends the loop the same way, so the
# flag must clear then too: `screenshot` relies on it to refuse a capture no
# frame will ever write.
RSpec.describe 'Window#show unwinding' do
  after { Ruby2D::Window.shown = false }

  it 'clears the running flag when a callback raises, so a later screenshot raises' do
    window = Ruby2D::Window.new
    allow(Ruby2D::Ext).to receive(:window_show)
    allow(Ruby2D::Ext).to receive(:window_load_gamepad_mappings_file)
    allow(window).to receive(:tick).and_raise('application failure')

    expect { window.show }.to raise_error(RuntimeError, 'application failure')
    expect(window.instance_variable_get(:@running)).to be false
    expect { window.screenshot('./ruby2d-spec.png') }
      .to raise_error(Ruby2D::Error, /after the frame loop ended/)
  end

  it 'keeps the running flag when a callback calls show again and rescues' do
    window = Ruby2D::Window.new
    allow(Ruby2D::Ext).to receive(:window_show)
    allow(Ruby2D::Ext).to receive(:window_load_gamepad_mappings_file)
    allow(Ruby2D::Ext).to receive(:window_screenshot) { |_, path| path }
    running_after = nil
    allow(window).to receive(:tick) do
      expect { window.show }.to raise_error(Ruby2D::Error, /multiple times/)
      running_after = window.instance_variable_get(:@running)
      expect(window.screenshot('./ruby2d-spec.png')).to eq('./ruby2d-spec.png')
      window.instance_variable_set(:@close, true)
    end

    window.show
    expect(running_after).to be true
    expect(window.instance_variable_get(:@running)).to be false
  end
end
