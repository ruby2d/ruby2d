# frozen_string_literal: true

RSpec.describe Ruby2D::Quad do
  describe '#new' do
    include_examples 'renderable color defaults', Ruby2D::Quad
    include_examples 'vertex color set', Ruby2D::Quad, 4
    include_examples 'shape dimensions', Ruby2D::Quad

    it 'creates a quad with options' do
      quad = Quad.new(
        x1: 10, y1: 20,
        x2: 30, y2: 40,
        x3: 50, y3: 60,
        x4: 70, y4: 80,
        z: 90,
        color: 'gray', opacity: 0.5
      )

      expect(quad.x1).to eq(10)
      expect(quad.y1).to eq(20)
      expect(quad.x2).to eq(30)
      expect(quad.y2).to eq(40)
      expect(quad.x3).to eq(50)
      expect(quad.y3).to eq(60)
      expect(quad.x4).to eq(70)
      expect(quad.y4).to eq(80)
      expect(quad.z).to eq(90)
    end

    it 'accepts vertices as points: [[x, y], ...]' do
      quad = Quad.new(points: [[10, 20], [30, 40], [50, 60], [70, 80]])
      expect(quad.x1).to eq(10)
      expect(quad.y1).to eq(20)
      expect(quad.x2).to eq(30)
      expect(quad.y2).to eq(40)
      expect(quad.x3).to eq(50)
      expect(quad.y3).to eq(60)
      expect(quad.x4).to eq(70)
      expect(quad.y4).to eq(80)
    end

    it 'raises if points: has the wrong length' do
      expect { Quad.new(points: [[0, 0], [10, 0], [10, 10]]) }
        .to raise_error('Quad requires exactly 4 points')
    end

    it 'raises if points: contains a non-pair' do
      expect { Quad.new(points: [[0, 0], [10, 0], [10, 10], [0]]) }
        .to raise_error('points must be an array of [x, y] pairs')
    end

    it 'accepts a single stroke_color' do
      quad = Quad.new(stroke_width: 2, stroke_color: 'red')
      expect(quad.stroke_color).to be_a(Ruby2D::Color)
    end

    it 'accepts a Color::Set of 4 stroke colors (one per vertex)' do
      quad = Quad.new(stroke_width: 2, stroke_color: %w[red green blue black])
      expect(quad.stroke_color).to be_a(Ruby2D::Color::Set)
    end

    it 'throws an error when stroke_color is an array of wrong length' do
      expect do
        Quad.new(stroke_width: 2, stroke_color: %w[red green])
      end.to raise_error('`Ruby2D::Quad` requires 4 colors, one for each vertex. 2 were given.')
    end
  end

  describe 'centroid (x, y)' do
    it 'reads x as the average of the four vertex x coordinates' do
      quad = Quad.new(x1: 0, y1: 0, x2: 100, y2: 0, x3: 100, y3: 60, x4: 0, y4: 60)
      expect(quad.x).to be_within(0.0001).of(50.0)
      expect(quad.y).to be_within(0.0001).of(30.0)
    end

    it 'translates all vertices when x= or y= is set' do
      quad = Quad.new(x1: 0, y1: 0, x2: 10, y2: 0, x3: 10, y3: 10, x4: 0, y4: 10)
      quad.x = 100
      expect(quad.x1).to eq(95)
      expect(quad.x2).to eq(105)
      quad.y = 200
      expect(quad.y1).to eq(195)
      expect(quad.y3).to eq(205)
    end
  end

  describe 'attributes' do
    it 'can be set and read' do
      quad = Quad.new
      quad.x1 = 10
      quad.y1 = 20
      quad.x2 = 30
      quad.y2 = 40
      quad.x3 = 50
      quad.y3 = 60
      quad.x4 = 70
      quad.y4 = 80
      quad.z = 90

      expect(quad.x1).to eq(10)
      expect(quad.y1).to eq(20)
      expect(quad.x2).to eq(30)
      expect(quad.y2).to eq(40)
      expect(quad.x3).to eq(50)
      expect(quad.y3).to eq(60)
      expect(quad.x4).to eq(70)
      expect(quad.y4).to eq(80)
      expect(quad.z).to eq(90)
    end
  end

  # `contains?` ray-casts over the four vertices, so it means "inside the
  # rendered fill" — like Polygon, and matching what SDL actually draws.
  describe '#contains?' do
    # A 2x2 axis-aligned quad with its top-left corner at (1, 1).
    quad = Quad.new(x1: 1, y1: 1, x2: 3, y2: 1, x3: 3, y3: 3, x4: 1, y4: 3, add: false)

    it 'returns true for interior points' do
      expect(quad.contains?(2, 2)).to be true
      expect(quad.contains?(1.5, 1.5)).to be true
      expect(quad.contains?(2.5, 2.5)).to be true
    end

    it 'returns false for points outside the quad' do
      [[0, 0], [2, 0], [4, 2], [2, 4], [0, 2], [4, 4]].each do |px, py|
        expect(quad.contains?(px, py)).to be(false), "expected (#{px}, #{py}) outside"
      end
    end

    # Matching rasterization, the boundary is half-open: the lower/left edges
    # read as inside, the upper/right edges as outside.
    it 'treats the boundary as half-open' do
      expect(quad.contains?(2, 1)).to be true  # bottom edge — inside
      expect(quad.contains?(1, 2)).to be true  # left edge — inside
      expect(quad.contains?(2, 3)).to be false # top edge — outside
      expect(quad.contains?(3, 2)).to be false # right edge — outside
    end

    # A concave (dart) quad: the right side comes to a point at (4, 2) and the
    # left side is notched inward to the reflex vertex (2, 2). The old area
    # method wrongly reported the notch point (1, 2) as inside; ray-casting
    # against the rendered fill excludes it.
    it 'excludes points in a concave quad’s notch' do
      dart = Quad.new(x1: 0, y1: 0, x2: 4, y2: 2, x3: 0, y3: 4, x4: 2, y4: 2)
      expect(dart.contains?(3, 2)).to be true  # solid part, near the tip
      expect(dart.contains?(1, 2)).to be false # inside the notch
    end
  end

  # The rotation math is inlined into the render paths (no per-frame array
  # allocation); these pin the rotated vertices actually handed to the native
  # draw so the inlining can't drift from the rotation formula.
  describe 'rotation at render' do
    it 'draws rotated vertices from the instance render path' do
      quad = Quad.new(x1: 10, y1: 0, x2: 20, y2: 0, x3: 20, y3: 10, x4: 10, y4: 10,
                      rotate: 90, rx: 0, ry: 0, add: false)
      captured = nil
      allow(Ruby2D::Ext).to receive(:draw_quad_uniform) { |*args| captured = args }
      quad.send(:render)
      # 90° about the origin maps (x, y) to (-y, x)
      [0, 10, 0, 20, -10, 20, -10, 10].each_with_index do |expected, i|
        expect(captured[i]).to be_within(1e-9).of(expected)
      end
    end

    it 'draws rotated vertices from the immediate render path' do
      allow(Ruby2D::Window).to receive(:render_ready_check)
      captured = nil
      allow(Ruby2D::Ext).to receive(:draw_quad_uniform) { |*args| captured = args }
      Quad.render(x1: 10, y1: 0, x2: 20, y2: 0, x3: 20, y3: 10, x4: 10, y4: 10,
                  rotate: 90, rx: 0, ry: 0)
      [0, 10, 0, 20, -10, 20, -10, 10].each_with_index do |expected, i|
        expect(captured[i]).to be_within(1e-9).of(expected)
      end
    end
  end
end
