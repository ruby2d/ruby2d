# The `render` block is spliced into the scene's z-order at the `z:` passed to
# `render`. `:foreground` (the default) draws it on top of every object,
# `:background` behind them, and a number interleaves it at that depth: objects
# with `z` at or below it draw first, then the block, then the rest.
RSpec.describe 'Render block z-order' do
  # A minimal drawable that records its name when the frame draws it. The
  # scene graph draws objects via the zero-arg `_render_scene` hook, not the
  # public keyword `render` — see Renderable#_render_scene.
  def drawable(z, log, name)
    Object.new.tap do |obj|
      obj.define_singleton_method(:z) { z }
      obj.define_singleton_method(:visible?) { true }
      obj.define_singleton_method(:_render_scene) { log << name }
    end
  end

  # Build a window with objects at the given z's plus a render block, run one
  # frame's object pass, and return the order things drew in.
  def draw_order(object_zs, render_kwargs = {})
    win = Ruby2D::Window.new
    log = []
    object_zs.each { |z| win.add(drawable(z, log, "obj#{z}")) }
    win.render(**render_kwargs) { log << 'block' }
    win.render_objects
    log
  end

  it 'draws the block on top of every object by default' do
    expect(draw_order([0, 10, 20])).to eq(%w[obj0 obj10 obj20 block])
  end

  it 'draws the block on top with an explicit :foreground' do
    expect(draw_order([0, 10, 20], z: :foreground)).to eq(%w[obj0 obj10 obj20 block])
  end

  it 'draws the block behind every object with :background' do
    expect(draw_order([0, 10, 20], z: :background)).to eq(%w[block obj0 obj10 obj20])
  end

  it 'interleaves at a numeric z, drawing objects at or below it first' do
    expect(draw_order([0, 10, 20], z: 10)).to eq(%w[obj0 obj10 block obj20])
  end

  it 'still draws the block when there are no objects (:background)' do
    expect(draw_order([], z: :background)).to eq(%w[block])
  end

  it 'still draws the block when there are no objects (numeric z)' do
    expect(draw_order([], z: 5)).to eq(%w[block])
  end

  it 'raises on an invalid z' do
    win = Ruby2D::Window.new
    expect { win.render(z: :sideways) {} }
      .to raise_error(Ruby2D::Error, /:foreground.*:background|:background.*:foreground/)
  end
end
