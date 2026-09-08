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

  it 'ranks a Button where its visual is drawn, below a shape added later' do
    button = Ruby2D::Button.new(x: 0, y: 0, width: 50, height: 50, color: 'red')
    cover = Ruby2D::Square.new(x: 0, y: 0, size: 50)
    button.on(:click) {}
    cover.on(:click) {}
    expect(topmost).to eq(cover)
  end

  it 'ranks a Button wrapping a visual where that visual is drawn, above a shape added earlier' do
    under = Ruby2D::Square.new(x: 0, y: 0, size: 50)
    button = Ruby2D::Button.new(Ruby2D::Square.new(x: 0, y: 0, size: 50))
    under.on(:click) {}
    button.on(:click) {}
    expect(topmost).to eq(button)
  end

  it 'follows a wrapped visual when that visual is restacked' do
    visual = Ruby2D::Square.new(x: 0, y: 0, size: 50)
    button = Ruby2D::Button.new(visual)
    button.on(:click) {}
    cover = Ruby2D::Square.new(x: 0, y: 0, size: 50)
    cover.on(:click) {}
    expect(topmost).to eq(cover)

    visual.z = 0 # re-asserting z moves the visual to the top of its bucket
    expect(topmost).to eq(button)

    cover.z = 0
    expect(topmost).to eq(cover)
  end

  it 'ranks a Button just above its own visual when both have handlers' do
    visual = Ruby2D::Square.new(x: 0, y: 0, size: 50)
    button = Ruby2D::Button.new(visual)
    visual.on(:click) {}
    button.on(:click) {}
    expect(topmost).to eq(button)

    # The same with handlers attached the other way round, and after the
    # registry has been re-sorted by the fallback path
    Ruby2D::DSL.window.clear
    visual = Ruby2D::Square.new(x: 0, y: 0, size: 50)
    button = Ruby2D::Button.new(visual)
    button.on(:click) {}
    visual.on(:click) {}
    detached = Ruby2D::Square.new(x: 0, y: 0, size: 50, add: false)
    detached.on(:click) {}
    detached.z = -1
    expect(topmost).to eq(button)
  end

  it 'keys a Button by its visual once that visual is added' do
    visual = Ruby2D::Square.new(x: 0, y: 0, size: 50, add: false)
    button = Ruby2D::Button.new(visual)
    button.on(:click) {}
    cover = Ruby2D::Square.new(x: 0, y: 0, size: 50)
    cover.on(:click) {}
    visual.add
    expect(topmost).to eq(button)
  end

  it 'keeps equal-z draw order when a registered object outside the scene changes z' do
    detached = Ruby2D::Square.new(x: 0, y: 0, size: 50, add: false)
    detached.on(:mouse_down) {}
    back = Ruby2D::Square.new(x: 0, y: 0, size: 50)
    back.on(:mouse_down) {}
    detached.z = 5
    front = Ruby2D::Square.new(x: 0, y: 0, size: 50)
    front.on(:mouse_down) {}
    expect(topmost).to eq(front)
  end

  it 'answers the same before and after a fallback re-sort when a Button visual is detached' do
    visual = Ruby2D::Square.new(x: 0, y: 0, size: 50, z: 1)
    button = Ruby2D::Button.new(visual)
    button.on(:click) {}
    scene = Ruby2D::Square.new(x: 0, y: 0, size: 50)
    scene.on(:click) {}
    visual.remove
    visual.z = 0
    first = topmost

    other = Ruby2D::Square.new(x: 0, y: 0, size: 50, add: false)
    other.on(:click) {}
    other.instance_variable_set(:@z, -3) # a z change the window wasn't told about
    expect(topmost).to eq(first)
    expect(topmost).to eq(first)
  end

  it 'recovers draw order when an object changes z behind the window back' do
    _back, front = overlapping_pair(z_low: 0, z_high: 0)
    other = Ruby2D::Square.new(x: 0, y: 0, size: 50, z: 1)
    other.on(:mouse_down) {}
    other.instance_variable_set(:@z, -1)
    expect(topmost).to eq(front)
    expect(topmost).to eq(front) # and again on the re-sorted fast path
  end
end
