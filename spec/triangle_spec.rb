RSpec.describe Ruby2D::Triangle do

  describe "#new" do
    include_examples 'renderable color defaults', Ruby2D::Triangle
    include_examples 'vertex color set', Ruby2D::Triangle, 3
    include_examples 'shape dimensions', Ruby2D::Triangle

    it 'reports width and height as the vertex bounding box' do
      tri = Ruby2D::Triangle.new(x1: 10, y1: 20, x2: 60, y2: 20, x3: 30, y3: 90)
      expect(tri.width).to eq(50)   # 60 - 10
      expect(tri.height).to eq(70)  # 90 - 20
    end

    it "creates a triangle with options" do
      triangle = Triangle.new(
        x1: 10, y1: 20, x2: 30, y2: 40, x3: 50, y3: 60, z: 70,
        color: 'gray', opacity: 0.5
      )

      expect(triangle.x1).to eq(10)
      expect(triangle.y1).to eq(20)
      expect(triangle.x2).to eq(30)
      expect(triangle.y2).to eq(40)
      expect(triangle.x3).to eq(50)
      expect(triangle.y3).to eq(60)
      expect(triangle.z).to eq(70)
    end

    it "accepts vertices as points: [[x, y], ...]" do
      triangle = Triangle.new(points: [[10, 20], [30, 40], [50, 60]])
      expect(triangle.x1).to eq(10)
      expect(triangle.y1).to eq(20)
      expect(triangle.x2).to eq(30)
      expect(triangle.y2).to eq(40)
      expect(triangle.x3).to eq(50)
      expect(triangle.y3).to eq(60)
    end

    it "raises if points: has the wrong length" do
      expect { Triangle.new(points: [[0, 0], [10, 0]]) }
        .to raise_error('Triangle requires exactly 3 points')
    end

    it "raises if points: contains a non-pair" do
      expect { Triangle.new(points: [[0, 0], [10, 0], [20]]) }
        .to raise_error('points must be an array of [x, y] pairs')
    end

    it "accepts a single stroke_color" do
      triangle = Triangle.new(stroke_width: 2, stroke_color: 'red')
      expect(triangle.stroke_color).to be_a(Ruby2D::Color)
    end

    it "accepts a Color::Set of 3 stroke colors (one per vertex)" do
      triangle = Triangle.new(stroke_width: 2, stroke_color: ['red', 'green', 'blue'])
      expect(triangle.stroke_color).to be_a(Ruby2D::Color::Set)
    end

    it "throws an error when stroke_color is an array of wrong length" do
      expect do
        Triangle.new(stroke_width: 2, stroke_color: ['red', 'green'])
      end.to raise_error("`Ruby2D::Triangle` requires 3 colors, one for each vertex. 2 were given.")
    end
  end

  describe "attributes" do
    it "can be set and read" do
      triangle = Triangle.new
      triangle.x1 = 10
      triangle.y1 = 20
      triangle.x2 = 30
      triangle.y2 = 40
      triangle.x3 = 50
      triangle.y3 = 60
      triangle.z = 70

      expect(triangle.x1).to eq(10)
      expect(triangle.y1).to eq(20)
      expect(triangle.x2).to eq(30)
      expect(triangle.y2).to eq(40)
      expect(triangle.x3).to eq(50)
      expect(triangle.y3).to eq(60)
      expect(triangle.z).to eq(70)
    end
  end

  describe "#contains?" do
    triangle = Triangle.new(
      x1:   0, y1:   0,
      x2:   0, y2: 100,
      x3: 100, y3:   0,
      add: false
    )

    it "returns true if point is inside the triangle" do
      expect(triangle.contains?( 0,  0)).to be true
      expect(triangle.contains?(25, 25)).to be true
    end

    it "returns false if point is outside the triangle" do
      expect(triangle.contains?( 25, -25)).to be false
      expect(triangle.contains?(-25,  25)).to be false
      expect(triangle.contains?(100,   1)).to be false
    end
  end

  describe "#contains? with rotation" do
    it "tests against the rotated triangle" do
      # Triangle (0,0),(60,0),(0,60) rotated 180° about its centroid (20,20).
      tri = Triangle.new(x1: 0, y1: 0, x2: 60, y2: 0, x3: 0, y3: 60,
                         rotate: 180, add: false)
      expect(tri.contains?(35, 35)).to be true   # inside the rotated triangle
      expect(tri.contains?(5, 5)).to be false    # only inside the unrotated one
    end
  end

  # The rotation math is inlined into the render paths (no per-frame array
  # allocation); these pin the rotated vertices actually handed to the native
  # draw so the inlining can't drift from the rotation formula.
  describe 'rotation at render' do
    it 'draws rotated vertices from the instance render path' do
      tri = Triangle.new(x1: 0, y1: 0, x2: 60, y2: 0, x3: 0, y3: 60,
                         rotate: 180, add: false)
      captured = nil
      allow(Ruby2D::Ext).to receive(:draw_triangle_uniform) { |*args| captured = args }
      tri.send(:render)
      # 180° about the centroid (20, 20) maps (x, y) to (40 - x, 40 - y)
      [40, 40, -20, 40, 40, -20].each_with_index do |expected, i|
        expect(captured[i]).to be_within(1e-9).of(expected)
      end
    end

    it 'draws rotated vertices from the immediate render path' do
      allow(Ruby2D::Window).to receive(:render_ready_check)
      captured = nil
      allow(Ruby2D::Ext).to receive(:draw_triangle_uniform) { |*args| captured = args }
      Triangle.render(x1: 0, y1: 0, x2: 60, y2: 0, x3: 0, y3: 60, rotate: 180)
      [40, 40, -20, 40, 40, -20].each_with_index do |expected, i|
        expect(captured[i]).to be_within(1e-9).of(expected)
      end
    end
  end

end
