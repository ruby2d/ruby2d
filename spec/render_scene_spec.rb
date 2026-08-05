# The scene graph draws each visible object once per frame through its
# zero-arg `_render_scene` hook rather than the public keyword `render` — on
# wasm mruby a zero-arg call into a keyword-heavy method still pays ~5µs of
# keyword setup. These specs pin the contract: every built-in renderable
# defines its own hook (not the Renderable fallback, which would add a
# dispatch hop), the hook is public (the scene loop calls it directly — a
# `send` per object per frame is measurable at scene-graph scale), the hook
# draws exactly what the no-argument `render` draws, and the no-argument
# `render` delegates to it.
RSpec.describe '_render_scene scene-graph hook' do
  # Every class the window can hold. Square is covered by Rectangle (it
  # inherits the hook from there), which the owner check below allows.
  RENDERABLE_CLASSES = [
    Ruby2D::Triangle, Ruby2D::Quad, Ruby2D::Rectangle, Ruby2D::Square,
    Ruby2D::Line, Ruby2D::Circle, Ruby2D::Ellipse, Ruby2D::Polygon,
    Ruby2D::Polyline, Ruby2D::Image, Ruby2D::Sprite, Ruby2D::Text,
    Ruby2D::BitmapText, Ruby2D::Canvas, Ruby2D::Tileset
  ].freeze

  it 'is defined directly by every built-in renderable, not the module fallback' do
    RENDERABLE_CLASSES.each do |klass|
      owner = klass.instance_method(:_render_scene).owner
      expect(owner).not_to eq(Ruby2D::Renderable),
                           "#{klass} falls back to Renderable#_render_scene"
    end
  end

  it 'is public on every built-in renderable, so the scene loop needs no send' do
    RENDERABLE_CLASSES.each do |klass|
      expect(klass.public_method_defined?(:_render_scene)).to be(true),
        "#{klass} keeps _render_scene private — render_objects calls it directly"
    end
  end

  it 'draws a vertex shape identically to its zero-arg render' do
    q = Ruby2D::Quad.new(add: false)
    calls = []
    allow(Ruby2D::Ext).to receive(:draw_quad_uniform) { |*args| calls << args }
    q.send(:render)
    q._render_scene
    expect(calls.length).to eq(2)
    expect(calls[0]).to eq(calls[1])
  end

  it 'draws an Image' do
    img = Ruby2D::Image.new(test_image('image.png'), add: false)
    expect(Ruby2D::Ext).to receive(:image_draw).with(img)
    img._render_scene
  end

  it 'advances a playing Sprite and draws it' do
    sprite = Ruby2D::Sprite.new(test_image('image.png'), add: false)
    expect(sprite).to receive(:update).with(no_args)
    expect(Ruby2D::Ext).to receive(:image_draw).with(sprite)
    sprite._render_scene
  end

  it 'draws a Text' do
    txt = Ruby2D::Text.new('hello', add: false)
    expect(Ruby2D::Ext).to receive(:text_draw).with(txt, txt.rx, txt.ry)
    txt._render_scene
  end

  it 'draws a BitmapText' do
    bt = Ruby2D::BitmapText.new('hello', add: false)
    expect(Ruby2D::Ext).to receive(:bitmap_text_draw).with(bt, bt.rx, bt.ry)
    bt._render_scene
  end

  it 'draws a Canvas' do
    canvas = Ruby2D::Canvas.new(width: 10, height: 10, add: false)
    expect(Ruby2D::Ext).to receive(:canvas_draw).with(canvas, canvas.rx, canvas.ry)
    canvas._render_scene
  end

  it 'is what the no-argument public render delegates to' do
    img = Ruby2D::Image.new(test_image('image.png'), add: false)
    expect(img).to receive(:_render_scene)
    img.render
  end

  it 'is reached through Renderable#_render_scene by custom renderables' do
    klass = Class.new do
      include Ruby2D::Renderable

      def initialize
        @drawn = 0
      end
      attr_reader :drawn

      def render
        @drawn += 1
      end
    end
    obj = klass.new
    obj._render_scene
    expect(obj.drawn).to eq(1)
  end

  it 'is how the window draws scene objects' do
    win = Ruby2D::Window.new
    win.render {} # register an empty render block for render_callback
    q = Ruby2D::Quad.new(add: false)
    win.add(q)
    expect(Ruby2D::Ext).to receive(:draw_quad_uniform)
    win.render_objects
  end
end
