# pixel_scale maps the logical drawing space onto physical pixels (and only has
# an effect when highdpi is on). The actual logical→physical mapping is
# C/window-driven; here we lock the Ruby-side flag handling — default, explicit
# set before show, and a live toggle after show (native refresh stubbed, since
# there's no real SDL window in the suite).
RSpec.describe 'Window pixel_scale' do
  it 'defaults to false' do
    expect(Ruby2D::Window.new.pixel_scale).to be false
  end

  it 'stores an explicit pixel_scale before show' do
    w = Ruby2D::Window.new
    w.set(pixel_scale: true)
    expect(w.pixel_scale).to be true
  end

  it 'toggles live after show without raising and keeps the reader honest' do
    w = Ruby2D::Window.new
    w.set(pixel_scale: true)
    allow(Ruby2D::Ext).to receive(:window_set_viewport_mode)
    Ruby2D::Window.shown = true
    begin
      expect { w.set(pixel_scale: false) }.not_to raise_error
      expect(w.pixel_scale).to be false
    ensure
      Ruby2D::Window.shown = false
    end
  end
end
