# `Window#screenshot` defers the file write to the end of the current frame, so
# the one way it can fail is when no frame will follow. A window that has already
# closed is that case, and it used to return a path and save nothing at all.
RSpec.describe 'Window#screenshot' do
  after { Ruby2D::Window.shown = false }

  it 'returns the path it will write to' do
    win = Ruby2D::Window.new
    expect(win.screenshot('./ruby2d-spec.png')).to eq('./ruby2d-spec.png')
  end

  it 'defaults to a timestamped file' do
    win = Ruby2D::Window.new
    expect(win.screenshot).to match(%r{\A\./screenshot-[\d-]+\.png\z})
  end

  it 'is allowed before the window is shown, landing on the first frame' do
    win = Ruby2D::Window.new
    expect { win.screenshot('./ruby2d-spec.png') }.not_to raise_error
  end

  it 'raises once the window has closed rather than saving nothing' do
    win = Ruby2D::Window.new
    Ruby2D::Window.shown = true # shown, but the frame loop is no longer running
    expect { win.screenshot('./ruby2d-spec.png') }
      .to raise_error(Ruby2D::Error, /after the window closed/)
  end
end
