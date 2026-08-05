# Ruby 2D is single-window by design. Constructing a second `Window` while one
# already exists would silently reassign the shared `DSL.window` and strand the
# first window's objects and event handlers, so it is refused. (The suite's
# global `before(:each)` resets `DSL.window` to nil, so each example below
# starts with no window.)
RSpec.describe 'Single-window enforcement' do
  it 'raises when a second Window is constructed while one already exists' do
    Ruby2D::Window.new
    expect { Ruby2D::Window.new }.to raise_error(Ruby2D::Error, /single window per process/i)
  end

  it 'raises when the first window was auto-created via the DSL' do
    Ruby2D::DSL.window # auto-constructs the default window
    expect { Ruby2D::Window.new }.to raise_error(Ruby2D::Error, /single window per process/i)
  end

  it 'allows a new Window once the current one is released' do
    Ruby2D::Window.new
    Ruby2D::DSL.window = nil
    expect { Ruby2D::Window.new }.not_to raise_error
  end
end
