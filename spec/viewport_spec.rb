# The viewport (`viewport_width` × `viewport_height`) is the fixed logical
# drawing area. It defaults to the initial width/height, but in `:letterbox`
# (and every mode except `:expand`) it must stay fixed across a live resize and
# letterbox into the window — so a bare runtime `set width:` must not overwrite
# an explicitly-configured viewport.
RSpec.describe 'Window viewport on resize' do
  it 'auto-derives the viewport from width/height before show' do
    w = Ruby2D::Window.new
    w.set(width: 800, height: 600)
    expect(w.viewport_width).to eq(800)
    expect(w.viewport_height).to eq(600)
  end

  it 'keeps an explicit viewport when width/height are set later, before show' do
    w = Ruby2D::Window.new
    w.set(viewport_width: 100, viewport_height: 50)
    w.set(width: 400, height: 200)
    expect(w.viewport_width).to eq(100)
    expect(w.viewport_height).to eq(50)
    expect(w.width).to eq(400)
    expect(w.height).to eq(200)
  end

  it 'lets a dimension not set explicitly keep following the window' do
    w = Ruby2D::Window.new
    w.set(viewport_width: 100)
    w.set(width: 400, height: 200)
    expect(w.viewport_width).to eq(100)
    expect(w.viewport_height).to eq(200)
  end

  # A live resize publishes the renderer's viewport back to the window (in
  # :expand it changed with the size). A viewport dimension the same `set`
  # carries must survive that for the viewport setter, called next, which
  # adopts a dimension that differs from the renderer's.
  it 'hands a viewport dimension carried by a live resize to the viewport setter' do
    w = Ruby2D::Window.new
    allow(Ruby2D::Ext).to receive(:window_set_size) do |win|
      win.instance_variable_set(:@viewport_width, win.width)
      win.instance_variable_set(:@viewport_height, win.height)
    end
    seen = nil
    allow(Ruby2D::Ext).to receive(:window_set_viewport_mode) do |win|
      seen = [win.viewport_width, win.viewport_height]
    end
    Ruby2D::Window.shown = true
    begin
      w.set(width: 800, height: 600, viewport_width: 400, viewport_height: 300)
      expect(seen).to eq([400, 300])
    ensure
      Ruby2D::Window.shown = false
    end
  end

  it 'keeps an explicit viewport fixed across a live set width: after show' do
    w = Ruby2D::Window.new
    w.set(viewport_width: 320, viewport_height: 240)
    expect(w.viewport_width).to eq(320)

    # Simulate the window being shown. A live resize must leave the fixed
    # logical viewport alone; stub the native size call since there is no real
    # SDL window in the suite, and restore the global shown flag afterward.
    allow(Ruby2D::Ext).to receive(:window_set_size)
    Ruby2D::Window.shown = true
    begin
      w.set(width: 800, height: 600)
      expect(w.viewport_width).to eq(320)
      expect(w.viewport_height).to eq(240)
      expect(w.width).to eq(800)
      expect(w.height).to eq(600)
    ensure
      Ruby2D::Window.shown = false
    end
  end
end

# The native parser silently falls back to letterbox for an unrecognized
# `viewport:` value, so the Ruby setter validates up front — otherwise
# `viewport_mode` would report a value the renderer never applied.
RSpec.describe 'Window viewport mode validation' do
  it 'accepts every recognized viewport mode' do
    Ruby2D::Window::VIEWPORT_MODES.each do |mode|
      w = Ruby2D::Window.new
      expect { w.set(viewport: mode) }.not_to raise_error
      expect(w.viewport_mode).to eq(mode)
      Ruby2D::DSL.window = nil # single-window: clear before the next iteration
    end
  end

  it 'raises a clear error on an unrecognized viewport mode and leaves the mode unchanged' do
    w = Ruby2D::Window.new
    expect { w.set(viewport: :lettrbox) }.to raise_error(Ruby2D::Error, /Invalid viewport mode/)
    expect(w.viewport_mode).to eq(:letterbox) # the default, untouched
  end
end
