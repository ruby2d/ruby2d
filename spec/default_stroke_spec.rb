# frozen_string_literal: true

# A shape constructed without a stroke color outlines itself in its fill
# color. The stroke is a copy of the resolved fill: independent state, so the
# two fade separately, and the same colors, even for a `'random'` fill, which
# a second parse of the input would roll again.
RSpec.describe 'default stroke color' do
  let(:polygon_pts) { [[0, 0], [40, 0], [20, 30]] }

  def build(klass, **opts)
    geometry = klass == Polygon ? { points: polygon_pts } : {}
    klass.new(**geometry, stroke_width: 3, add: false, **opts)
  end

  describe 'from a Color::Set fill' do
    [Quad, Rectangle, Square, Triangle, Polygon].each do |klass|
      it "gives #{klass} a stroke set that fades independently of the fill" do
        n = klass == Triangle || klass == Polygon ? 3 : 4
        palette = Ruby2D::Color::Set.new(%w[red green blue white].first(n))
        shape = build(klass, color: palette)
        expect(shape.color).to be(palette)
        expect(shape.stroke_color).to be_a(Ruby2D::Color::Set)
        expect(shape.stroke_color).not_to be(palette)
        expect(shape.stroke_color.map(&:to_a)).to eq(palette.map(&:to_a))

        shape.color.opacity = 0.25
        expect(shape.stroke_color.opacity).to eq(1.0)
        shape.stroke_color.opacity = 0.5
        expect(shape.color.opacity).to eq(0.25)
      end
    end

    it 'carries a construction-time opacity into the stroke copy' do
      palette = Ruby2D::Color::Set.new(%w[red green blue white])
      shape = build(Rectangle, color: palette, opacity: 0.5)
      expect(shape.color.opacity).to eq(0.5)
      expect(shape.stroke_color.opacity).to eq(0.5)
      expect(shape.stroke_color).not_to be(shape.color)
    end
  end

  describe 'from a single Color fill' do
    [Quad, Rectangle, Square, Triangle, Polygon, Circle, Ellipse].each do |klass|
      it "gives #{klass} its own stroke color with the fill's values" do
        shape = build(klass, color: 'lime')
        expect(shape.stroke_color).not_to be(shape.color)
        expect(shape.stroke_color.to_a).to eq(shape.color.to_a)
        shape.color.opacity = 0.25
        expect(shape.stroke_color.opacity).to eq(1.0)
      end
    end
  end

  describe "from a 'random' fill" do
    [Quad, Rectangle, Square, Triangle, Polygon, Circle, Ellipse].each do |klass|
      it "outlines #{klass} in the color it rolled" do
        shape = build(klass, color: 'random')
        expect(shape.stroke_color.to_a).to eq(shape.color.to_a)
      end
    end

    [[Quad, 4], [Rectangle, 4], [Square, 4], [Triangle, 3], [Polygon, 3]].each do |klass, n|
      it "outlines #{klass} in the per-vertex colors it rolled" do
        shape = build(klass, color: ['random'] * n)
        expect(shape.stroke_color.map(&:to_a)).to eq(shape.color.map(&:to_a))
      end
    end
  end

  describe 'in immediate mode' do
    before { allow(Ruby2D::Window).to receive(:render_ready_check) }

    it 'strokes Quad.render in the rolled single color' do
      fill = stroke = nil
      allow(Ruby2D::Ext).to receive(:draw_quad_uniform) { |*a| fill = a[8, 4] }
      allow(Ruby2D::Ext).to receive(:stroke_quad_uniform) { |*a| stroke = a[9, 4] }
      Quad.render(color: 'random', stroke_width: 2)
      expect(fill).not_to be_nil
      expect(stroke).to eq(fill)
    end

    it 'strokes Quad.render in the rolled per-vertex colors, with the opacity override' do
      fill = stroke = nil
      allow(Ruby2D::Ext).to receive(:draw_quad) { |*a| fill = 4.times.map { |i| a[i * 6 + 2, 4] } }
      allow(Ruby2D::Ext).to receive(:stroke_quad) { |*a| stroke = 4.times.map { |i| a[9 + i * 4, 4] } }
      Rectangle.render(x: 0, y: 0, width: 10, height: 10, color: ['random'] * 4, stroke_width: 2, opacity: 0.5)
      expect(stroke).to eq(fill)
      expect(fill.map(&:last)).to eq([0.5] * 4)
    end

    it 'strokes Triangle.render in the rolled per-vertex colors' do
      fill = stroke = nil
      allow(Ruby2D::Ext).to receive(:draw_triangle) { |*a| fill = 3.times.map { |i| a[i * 6 + 2, 4] } }
      allow(Ruby2D::Ext).to receive(:stroke_triangle) { |*a| stroke = 3.times.map { |i| a[7 + i * 4, 4] } }
      Triangle.render(color: ['random'] * 3, stroke_width: 2)
      expect(fill).not_to be_nil
      expect(stroke).to eq(fill)
    end

    it 'strokes Polygon.render in the rolled colors' do
      fill = stroke = nil
      allow(Ruby2D::Ext).to receive(:draw_polygon) { |_, pvc| fill = pvc }
      allow(Ruby2D::Ext).to receive(:stroke_path) { |_, _, pvs, _| stroke = pvs }
      Polygon.render(points: polygon_pts, color: 'random', stroke_width: 2)
      expect(fill).not_to be_nil
      expect(stroke).to eq(fill)
    end

    it 'strokes Circle.render and Ellipse.render in the rolled color' do
      fill = stroke = nil
      allow(Ruby2D::Ext).to receive(:draw_circle) { |*a| fill = a[4, 4] }
      allow(Ruby2D::Ext).to receive(:stroke_circle) { |*a| stroke = a[5, 4] }
      Circle.render(color: 'random', stroke_width: 2, opacity: 0.5)
      expect(stroke).to eq(fill)
      expect(fill.last).to eq(0.5)

      allow(Ruby2D::Ext).to receive(:draw_ellipse) { |*a| fill = a[6, 4] }
      allow(Ruby2D::Ext).to receive(:stroke_ellipse) { |*a| stroke = a[7, 4] }
      Ellipse.render(color: 'random', stroke_width: 2)
      expect(fill).not_to be_nil
      expect(stroke).to eq(fill)
    end

    it 'clamps a scalar opacity for Circle.render and Ellipse.render, fill and stroke alike' do
      fill = stroke = nil
      allow(Ruby2D::Ext).to receive(:draw_circle) { |*a| fill = a[7] }
      allow(Ruby2D::Ext).to receive(:stroke_circle) { |*a| stroke = a[8] }
      Circle.render(color: 'red', opacity: 1.5, stroke_width: 2)
      expect([fill, stroke]).to eq([1.0, 1.0])
      Circle.render(color: 'red', opacity: -0.2, stroke_color: 'blue', stroke_width: 2)
      expect([fill, stroke]).to eq([0.0, 0.0])

      allow(Ruby2D::Ext).to receive(:draw_ellipse) { |*a| fill = a[9] }
      allow(Ruby2D::Ext).to receive(:stroke_ellipse) { |*a| stroke = a[10] }
      Ellipse.render(color: 'red', opacity: -0.2, stroke_width: 2)
      expect([fill, stroke]).to eq([0.0, 0.0])
    end

    it 'still resolves an explicit stroke color on its own' do
      stroke = nil
      allow(Ruby2D::Ext).to receive(:draw_quad_uniform)
      allow(Ruby2D::Ext).to receive(:stroke_quad_uniform) { |*a| stroke = a[9, 4] }
      Quad.render(color: 'random', stroke_color: 'red', stroke_width: 2)
      expect(stroke).to eq(Ruby2D::Color.new('red').to_a)
    end
  end
end
