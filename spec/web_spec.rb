# `Ruby2D.web?` is baked in by the C extension at compile time: true only for
# the Emscripten (WASM) build, false for native builds and the CRuby gem. Specs
# run under CRuby, so an app branching on it here must take the native path.
RSpec.describe 'Ruby2D.web?' do
  it 'is false under CRuby' do
    expect(Ruby2D.web?).to be false
  end
end

# A page can't close itself, so `close` does nothing on the web rather than
# half-closing: no `:close` handler, no closed flag, and the loop runs on. The
# native path is exercised throughout the rest of the suite, which runs with
# `web?` false; these stub it true to reach the branch CRuby never takes.
RSpec.describe 'Window#close on the web' do
  let(:window) { Ruby2D::Window.new }

  before { allow(Ruby2D).to receive(:web?).and_return(true) }

  it 'does not fire the close handler' do
    fired = false
    window.on(:close) { fired = true }
    window.close
    expect(fired).to be false
  end

  it 'does not mark the window closed' do
    window.close
    expect(window.instance_variable_get(:@close)).to be_falsey
  end

  it 'still closes on a native build' do
    allow(Ruby2D).to receive(:web?).and_return(false)
    fired = false
    window.on(:close) { fired = true }
    window.close
    expect(fired).to be true
    expect(window.instance_variable_get(:@close)).to be true
  end
end

# The browser has no filesystem a viewer can reach, so `screenshot` doesn't
# capture at all there — rather than paying for a framebuffer read and a PNG
# encode to write into Emscripten's in-memory filesystem.
RSpec.describe 'Window#screenshot on the web' do
  let(:window) { Ruby2D::Window.new }

  before { allow(Ruby2D).to receive(:web?).and_return(true) }

  it 'returns nil' do
    expect(window.screenshot('shot.png')).to be_nil
  end

  it 'does not reach the native capture' do
    expect(Ruby2D::Ext).not_to receive(:window_screenshot)
    window.screenshot('shot.png')
  end

  it 'still captures on a native build' do
    allow(Ruby2D).to receive(:web?).and_return(false)
    expect(Ruby2D::Ext).to receive(:window_screenshot).with(window, 'shot.png')
    window.screenshot('shot.png')
  end
end
