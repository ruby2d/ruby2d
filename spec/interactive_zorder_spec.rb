# Interactive hit-testing returns the topmost (highest-z) object under a point.
# The interactive registry is sorted by z at registration, but an object's z can
# change at runtime — so dispatch must re-establish z order, and preserve the
# registration-order tie-break among equal-z objects.
RSpec.describe 'Interactive hit-test z-order' do
  before(:each) { Ruby2D::DSL.window = Ruby2D::Window.new }

  # Two fully overlapping interactive squares; both contain (10, 10).
  def overlapping_pair(z_low:, z_high:)
    low  = Ruby2D::Square.new(x: 0, y: 0, size: 50, z: z_low)
    high = Ruby2D::Square.new(x: 0, y: 0, size: 50, z: z_high)
    [low, high].each { |s| s.on(:mouse_down) {} }
    [low, high]
  end

  it 'returns the higher-z object when both contain the point' do
    low, high = overlapping_pair(z_low: 0, z_high: 1)
    expect(Ruby2D::DSL.window.topmost_interactive_at(10, 10)).to eq(high)
  end

  it 'reflects a runtime z change without re-registering' do
    low, high = overlapping_pair(z_low: 0, z_high: 1)
    expect(Ruby2D::DSL.window.topmost_interactive_at(10, 10)).to eq(high)

    low.z = 5 # now the visually-topmost object
    expect(Ruby2D::DSL.window.topmost_interactive_at(10, 10)).to eq(low)
  end

  it 'keeps the most recently registered object topmost among equal z' do
    first, second = overlapping_pair(z_low: 0, z_high: 0)
    expect(Ruby2D::DSL.window.topmost_interactive_at(10, 10)).to eq(second)
  end
end
