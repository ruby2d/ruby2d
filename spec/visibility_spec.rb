# Each Renderable subclass must wire `add:` and `visible:` kwargs through to
# the underlying Renderable methods. We test that wiring per-class, then
# verify the Renderable behaviors themselves once — re-testing #show / #hide /
# visible= for every subclass would only re-verify the module.
RSpec.describe 'add: and visible: kwargs' do
  test_image = ->(name) { "#{Ruby2D.test_images}/#{name}" }
  test_sheet = ->(name) { "#{Ruby2D.test_spritesheets}/#{name}" }

  # Optional third element is RSpec metadata applied to the case's describe.
  CASES = [
    ['Triangle',   ->(**o) { Ruby2D::Triangle.new(**o) }],
    ['Quad',       ->(**o) { Ruby2D::Quad.new(**o) }],
    ['Rectangle',  ->(**o) { Ruby2D::Rectangle.new(**o) }],
    ['Square',     ->(**o) { Ruby2D::Square.new(**o) }],
    ['Line',       ->(**o) { Ruby2D::Line.new(**o) }],
    ['Circle',     ->(**o) { Ruby2D::Circle.new(**o) }],
    ['Ellipse',    ->(**o) { Ruby2D::Ellipse.new(**o) }],
    ['Polygon',    ->(**o) { Ruby2D::Polygon.new(points: [[0, 0], [10, 0], [5, 10]], **o) }],
    ['Polyline',   ->(**o) { Ruby2D::Polyline.new(points: [[0, 0], [10, 10], [20, 0]], **o) }],
    ['Canvas',     ->(**o) { Ruby2D::Canvas.new(width: 50, height: 50, **o) }],
    ['Image',      ->(**o) { Ruby2D::Image.new(test_image.call('image.png'), **o) }],
    ['Sprite',     ->(**o) { Ruby2D::Sprite.new(test_sheet.call('coin.png'), **o) }],
    ['Tileset',    ->(**o) { Ruby2D::Tileset.new(test_sheet.call('texture_atlas.png'), **o) }],
    ['Text',       ->(**o) { Ruby2D::Text.new('hi', **o) }],
    ['BitmapText', ->(**o) { Ruby2D::BitmapText.new('hi', **o) }]
  ]

  describe 'constructor kwarg wiring (per-class)' do
    CASES.each do |label, build, tag|
      describe(label, *Array(tag)) do
        it 'adds to the window by default' do
          shape = build.call
          expect(Ruby2D::Window.remove(shape)).to be true
        end

        it 'does not add to the window when add: false' do
          shape = build.call(add: false)
          expect(Ruby2D::Window.remove(shape)).to be false
        end

        it 'respects visible: false at construction' do
          shape = build.call(add: false, visible: false)
          expect(shape.visible?).to be false
        end
      end
    end
  end

  # The Renderable methods (#add, #hide, #show, visible=) work the same on
  # every subclass — testing them once is enough.
  describe 'Renderable visibility methods' do
    let(:shape) { Ruby2D::Rectangle.new(add: false) }

    it '#add registers the shape in the scene graph' do
      shape.add
      expect(Ruby2D::Window.remove(shape)).to be true
    end

    it '#hide and #show toggle visibility' do
      shape.hide
      expect(shape.visible?).to be false
      shape.show
      expect(shape.visible?).to be true
    end

    it 'visible= accessor toggles visibility' do
      shape.visible = false
      expect(shape.visible?).to be false
      shape.visible = true
      expect(shape.visible?).to be true
    end
  end

  # Changing z re-sorts a member in the scene graph, but must not drag a
  # non-member back in: z= calls remove + add, and a naive add would resurrect
  # an `add: false` or already-removed object.
  describe '#z= and scene-graph membership' do
    it 're-inserts an added shape at the new depth, keeping it a member' do
      shape = Ruby2D::Rectangle.new
      shape.z = 10
      expect(shape.z).to eq(10)
      expect(Ruby2D::Window.remove(shape)).to be true
    end

    it 'does not add an add: false shape when its z changes' do
      shape = Ruby2D::Rectangle.new(add: false)
      shape.z = 10
      expect(shape.z).to eq(10)
      expect(Ruby2D::Window.remove(shape)).to be false
    end

    it 'does not resurrect a removed shape when its z changes' do
      shape = Ruby2D::Rectangle.new
      Ruby2D::Window.remove(shape)
      shape.z = 5
      expect(Ruby2D::Window.remove(shape)).to be false
    end
  end
end
