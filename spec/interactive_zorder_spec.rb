# Interactive hit-testing returns the topmost (highest-z) object under a point.
# The interactive registry is sorted by z at registration, but an object's z can
# change at runtime — so dispatch must re-establish z order. Among equal z the
# tie-break follows draw order: the object most recently added to the scene is
# drawn on top, and receives the events, however its handlers were attached.
RSpec.describe 'Interactive hit-test z-order' do
  before(:each) { Ruby2D::DSL.window = Ruby2D::Window.new }

  def topmost
    Ruby2D::DSL.window.topmost_interactive_at(10, 10)
  end

  # Two fully overlapping interactive squares; both contain (10, 10).
  def overlapping_pair(z_low:, z_high:)
    low  = Ruby2D::Square.new(x: 0, y: 0, size: 50, z: z_low)
    high = Ruby2D::Square.new(x: 0, y: 0, size: 50, z: z_high)
    [low, high].each { |s| s.on(:mouse_down) {} }
    [low, high]
  end

  it 'returns the higher-z object when both contain the point' do
    low, high = overlapping_pair(z_low: 0, z_high: 1)
    expect(topmost).to eq(high)
  end

  it 'reflects a runtime z change without re-registering' do
    low, high = overlapping_pair(z_low: 0, z_high: 1)
    expect(topmost).to eq(high)

    low.z = 5 # now the visually-topmost object
    expect(topmost).to eq(low)
  end

  it 'keeps the most recently added object topmost among equal z' do
    first, second = overlapping_pair(z_low: 0, z_high: 0)
    expect(topmost).to eq(second)
  end

  it 'follows draw order among equal z, whatever order handlers were attached' do
    back  = Ruby2D::Square.new(x: 0, y: 0, size: 50)
    front = Ruby2D::Square.new(x: 0, y: 0, size: 50)
    front.on(:mouse_down) {}
    back.on(:mouse_down) {}
    expect(topmost).to eq(front)
  end

  it 'moves an object to the top of its z-bucket when its z is reassigned' do
    first, _second = overlapping_pair(z_low: 0, z_high: 0)
    first.z = 0
    expect(topmost).to eq(first)
  end

  it 'moves a re-added object to the top of its z-bucket' do
    first, _second = overlapping_pair(z_low: 0, z_high: 0)
    first.remove
    first.add
    expect(topmost).to eq(first)
  end
end
