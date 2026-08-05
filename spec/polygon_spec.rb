# frozen_string_literal: true

RSpec.describe Ruby2D::Polygon do
  include_examples 'renderable color defaults',
                   Ruby2D::Polygon, points: [[0, 0], [100, 0], [50, 100]]
  include_examples 'shape dimensions',
                   Ruby2D::Polygon, points: [[0, 0], [100, 0], [50, 100]]

  describe '#new' do
    let(:triangle_pts) { [[0, 0], [100, 0], [50, 100]] }
    let(:pentagon_pts) { [[50, 0], [100, 40], [80, 100], [20, 100], [0, 40]] }

    it 'raises if a point is not an [x, y] pair' do
      expect do
        Polygon.new(points: [[0, 0], [10, 10], [20]])
      end.to raise_error('points must be an array of [x, y] pairs')
    end

    it 'raises if fewer than 3 points' do
      expect do
        Polygon.new(points: [[0, 0], [10, 10]])
      end.to raise_error('Polygon requires at least 3 points')
    end

    it 'accepts a single color via string' do
      poly = Polygon.new(points: triangle_pts, color: 'red')
      expect(poly.color).to be_a(Ruby2D::Color)
    end

    it 'accepts a Color::Set matching the vertex count (3)' do
      poly = Polygon.new(points: triangle_pts, color: %w[red green blue])
      expect(poly.color).to be_a(Ruby2D::Color::Set)
    end

    it 'accepts a Color::Set matching the vertex count (5)' do
      poly = Polygon.new(points: pentagon_pts,
                         color: %w[red yellow green blue fuchsia])
      expect(poly.color).to be_a(Ruby2D::Color::Set)
    end

    it 'raises when the color array length does not match vertex count' do
      expect do
        Polygon.new(points: triangle_pts, color: %w[red green])
      end.to raise_error('`Ruby2D::Polygon` requires 3 colors, one for each vertex. 2 were given.')
    end

    it 'accepts a single stroke_color' do
      poly = Polygon.new(points: triangle_pts, stroke_width: 2, stroke_color: 'red')
      expect(poly.stroke_color).to be_a(Ruby2D::Color)
    end

    it 'accepts a Color::Set of stroke colors matching the vertex count' do
      poly = Polygon.new(points: triangle_pts, stroke_width: 2,
                         stroke_color: %w[red green blue])
      expect(poly.stroke_color).to be_a(Ruby2D::Color::Set)
    end

    it 'raises when stroke_color length does not match vertex count' do
      expect do
        Polygon.new(points: triangle_pts, stroke_width: 2,
                    stroke_color: %w[red green])
      end.to raise_error('`Ruby2D::Polygon` requires 3 colors, one for each vertex. 2 were given.')
    end

    it 'defaults stroke_color to the fill color when unspecified' do
      poly = Polygon.new(points: triangle_pts, stroke_width: 2, color: 'lime')
      expect(poly.stroke_color.r).to eq(Ruby2D::Color.new('lime').r)
    end

    it 'preserves a per-vertex fill as the default stroke_color' do
      poly = Polygon.new(points: triangle_pts, stroke_width: 2,
                         color: %w[red green blue])
      expect(poly.stroke_color).to be_a(Ruby2D::Color::Set)
    end
  end

  describe 'attributes' do
    it 'exposes vertex_count' do
      poly = Polygon.new(points: [[0, 0], [10, 0], [10, 10], [0, 10]])
      expect(poly.vertex_count).to eq(4)
    end

    it 'exposes points as [x, y] pairs' do
      poly = Polygon.new(points: [[0, 0], [10, 0], [5, 10]])
      expect(poly.points).to eq([[0.0, 0.0], [10.0, 0.0], [5.0, 10.0]])
    end

    it 'has a centroid (x, y) at the average of vertices' do
      poly = Polygon.new(points: [[0, 0], [10, 0], [5, 10]])
      expect(poly.x).to be_within(0.0001).of(5.0)
      expect(poly.y).to be_within(0.0001).of(10.0 / 3.0)
    end

    it 'translates all vertices when x= or y= is set' do
      poly = Polygon.new(points: [[0, 0], [10, 0], [10, 10], [0, 10]])
      poly.x = 100
      expect(poly.x).to be_within(0.0001).of(100.0)
      expect(poly.points).to eq([[95.0, 0.0], [105.0, 0.0], [105.0, 10.0], [95.0, 10.0]])
      poly.y = 200
      expect(poly.y).to be_within(0.0001).of(200.0)
      expect(poly.points).to eq([[95.0, 195.0], [105.0, 195.0], [105.0, 205.0], [95.0, 205.0]])
    end
  end

  describe '#contains?' do
    # Triangle: (0, 0), (100, 0), (50, 100)
    let(:triangle) { Polygon.new(points: [[0, 0], [100, 0], [50, 100]]) }

    it 'returns true for a point clearly inside' do
      expect(triangle.contains?(50, 25)).to be true
    end

    it 'returns false for a point clearly outside' do
      expect(triangle.contains?(200, 200)).to be false
      expect(triangle.contains?(-10, 50)).to be false
      expect(triangle.contains?(50, -10)).to be false
    end

    it 'returns false for a point in the bounding box but outside the shape' do
      # At y=80 the triangle spans x ∈ [40, 60]; (10, 80) is in the bbox
      # but well outside the triangle's left edge.
      expect(triangle.contains?(10, 80)).to be false
    end

    it 'handles a concave polygon (star-shaped notch)' do
      # An arrow/chevron pointing right with a notch on the left side
      arrow = Polygon.new(points: [[0, 0], [50, 0], [100, 50], [50, 100], [0, 100], [25, 50]])
      expect(arrow.contains?(50, 50)).to be true   # in the body
      expect(arrow.contains?(10, 50)).to be false  # in the notch
      expect(arrow.contains?(90, 50)).to be true   # near the tip
    end

    it 'tests against the rotated polygon' do
      # A wide 100×20 polygon rotated 90° about its centroid (50, 10) becomes
      # tall and thin; hit-testing must follow the rendered shape.
      poly = Polygon.new(points: [[0, 0], [100, 0], [100, 20], [0, 20]],
                         rotate: 90, add: false)
      expect(poly.contains?(50, 50)).to be true
      expect(poly.contains?(90, 10)).to be false
    end
  end

  # A rotated polygon writes its rotated coordinates into a per-object buffer
  # reused across frames (the native draw copies the values out, so reuse is
  # safe). These pin the rotated values and the reuse.
  describe 'rotation at render' do
    it 'draws rotated coordinates, reusing one buffer across frames' do
      poly = Polygon.new(points: [[0, 0], [100, 0], [100, 20], [0, 20]],
                         rotate: 90, rx: 0, ry: 0, add: false)
      captured = []
      allow(Ruby2D::Ext).to receive(:draw_polygon) { |coords, _| captured << coords }
      poly.send(:render)
      poly.send(:render)

      # 90° about the origin maps (x, y) to (-y, x)
      [0, 0, 0, 100, -20, 100, -20, 0].each_with_index do |expected, i|
        expect(captured.last[i]).to be_within(1e-9).of(expected)
      end
      # Same buffer both frames — no per-frame allocation
      expect(captured[0]).to be(captured[1])
      # The stored coordinates are untouched
      expect(poly.instance_variable_get(:@coordinates)).to eq([0, 0, 100, 0, 100, 20, 0, 20])
    end
  end
end
