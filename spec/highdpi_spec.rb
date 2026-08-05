# highdpi is baked into the native window at creation and re-read once at
# `show`; it cannot change afterward. The runtime setter must keep the reader
# honest after show — never reporting a value the renderer never applied — and
# warn only when the call would actually differ from the active value.
RSpec.describe 'Window highdpi' do
  it 'accepts a highdpi change before show' do
    w = Ruby2D::Window.new
    expect(w.highdpi).to be true # default
    w.set(highdpi: false)
    expect(w.highdpi).to be false
  end

  it 'ignores a changed highdpi after show, keeps the reader honest, and warns' do
    w = Ruby2D::Window.new # default highdpi: true
    Ruby2D::Window.shown = true
    begin
      expect { w.set(highdpi: false) }.to output(/highdpi/).to_stderr
      expect(w.highdpi).to be true # unchanged — matches what the renderer applied
    ensure
      Ruby2D::Window.shown = false
    end
  end

  it 'does not warn when set highdpi: matches the active value after show' do
    w = Ruby2D::Window.new # default highdpi: true
    Ruby2D::Window.shown = true
    begin
      expect { w.set(highdpi: true) }.not_to output.to_stderr
      expect(w.highdpi).to be true
    ensure
      Ruby2D::Window.shown = false
    end
  end
end
