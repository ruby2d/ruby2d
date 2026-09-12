# frozen_string_literal: true

RSpec.describe Ruby2D::Polyline do
  include_examples 'renderable color defaults',
                   Ruby2D::Polyline, points: [[0, 0], [50, 50], [100, 0], [150, 100]]
  include_examples 'shape dimensions',
                   Ruby2D::Polyline, points: [[0, 0], [50, 50], [100, 0], [150, 100]]

  describe '#new' do
    let(:path_pts) { [[0, 0], [50, 50], [100, 0], [150, 100]] }

    it 'raises if a point is not an [x, y] pair' do
      expect do
        Polyline.new(points: [[0, 0], [10, 10], [20]])
      end.to raise_error('points must be an array of [x, y] pairs')
    end

    it 'raises if fewer than 2 points' do
      expect do
        Polyline.new(points: [[0, 0]])
      end.to raise_error('Polyline requires at least 2 points')
    end

    it 'accepts a single color via string' do
      line = Polyline.new(points: path_pts, color: 'red')
      expect(line.color).to be_a(Ruby2D::Color)
    end

    it 'accepts a Color::Set matching the vertex count (per-vertex gradient)' do
      line = Polyline.new(points: path_pts, color: %w[red yellow lime aqua])
      expect(line.color).to be_a(Ruby2D::Color::Set)
    end

    it 'raises when the color array length does not match vertex count' do
      expect do
        Polyline.new(points: path_pts, color: %w[red green])
      end.to raise_error('`Ruby2D::Polyline` requires 4 colors, one for each vertex. 2 were given.')
    end

    it 'accepts a per-vertex opacity array matching the vertex count' do
      line = Polyline.new(points: path_pts, opacity: [0.1, 0.2, 0.3, 0.4])
      expect(line.opacity).to eq([0.1, 0.2, 0.3, 0.4])
    end

    it 'accepts a single scalar opacity' do
      line = Polyline.new(points: path_pts, opacity: 0.5)
      expect(line.opacity).to eq(0.5)
    end

    it 'clamps out-of-range per-vertex opacity values to 0.0..1.0' do
      line = Polyline.new(points: [[0, 0], [100, 0]], opacity: [1.5, -0.1])
      expect(line.opacity).to eq([1.0, 0.0])
    end

    it 'does not alter in-range per-vertex opacity values' do
      line = Polyline.new(points: [[0, 0], [100, 0]], opacity: [0.0, 1.0])
      expect(line.opacity).to eq([0.0, 1.0])
    end

    it 'raises when the opacity array length does not match vertex count' do
      expect do
        Polyline.new(points: path_pts, opacity: [0.1, 0.2])
      end.to raise_error(ArgumentError, /opacity array must have 4 values/)
    end

    it 'defaults closed to false and accepts true' do
      open_line   = Polyline.new(points: path_pts)
      closed_line = Polyline.new(points: path_pts, closed: true)
      expect(open_line.closed).to be false
      expect(closed_line.closed).to be true
    end

    it 'stores stroke_width and rotate' do
      line = Polyline.new(points: path_pts, stroke_width: 5, rotate: 30)
      expect(line.stroke_width).to eq(5)
      expect(line.rotate).to eq(30)
    end
  end

  describe 'attributes' do
    it 'exposes vertex_count and centroid' do
      line = Polyline.new(points: [[0, 0], [10, 0], [10, 10], [0, 10]])
      expect(line.vertex_count).to eq(4)
      expect(line.x).to be_within(0.0001).of(5.0)
      expect(line.y).to be_within(0.0001).of(5.0)
    end

    it 'exposes points as [x, y] pairs' do
      line = Polyline.new(points: [[0, 0], [10, 0], [10, 10]])
      expect(line.points).to eq([[0.0, 0.0], [10.0, 0.0], [10.0, 10.0]])
    end

    it 'translates all vertices when x= or y= is set' do
      line = Polyline.new(points: [[0, 0], [10, 0], [10, 10], [0, 10]])
      line.x = 100
      expect(line.x).to be_within(0.0001).of(100.0)
      expect(line.points).to eq([[95.0, 0.0], [105.0, 0.0], [105.0, 10.0], [95.0, 10.0]])
      line.y = 200
      expect(line.y).to be_within(0.0001).of(200.0)
      expect(line.points).to eq([[95.0, 195.0], [105.0, 195.0], [105.0, 205.0], [95.0, 205.0]])
    end
  end

  describe '#contains?' do
    # Horizontal then vertical: (0,0) → (100,0) → (100,100), stroke_width 4
    let(:path) { Polyline.new(points: [[0, 0], [100, 0], [100, 100]], stroke_width: 4) }

    it 'returns true on a vertex' do
      expect(path.contains?(0, 0)).to be true
      expect(path.contains?(100, 0)).to be true
    end

    it 'returns true within stroke_width / 2 of a segment' do
      expect(path.contains?(50, 1)).to be true   # near the horizontal segment
      expect(path.contains?(99, 50)).to be true  # near the vertical segment
    end

    it 'returns false outside stroke_width / 2 of every segment' do
      expect(path.contains?(50, 5)).to be false
      expect(path.contains?(200, 200)).to be false
    end

    it 'returns false for points off the ends of segments' do
      # x=-5 is past the start of the horizontal segment, not within tolerance
      expect(path.contains?(-5, 0)).to be false
    end

    it 'does not extend past the open ends of the path' do
      # (100,101) is 1px past the final endpoint (100,100), within stroke_width/2
      # of it — inside the old rounded cap, but outside the drawn band now.
      expect(path.contains?(100, 101)).to be false
    end

    it 'covers the mitered corner at an interior joint' do
      # (101,-1) is in the corner wedge where the two segments meet at the
      # interior joint (100,0): outside the straight segment bands, but inside
      # the drawn miter. contains? hit-tests the exact rendered outline, so the
      # corner — including the miter spike — is covered, while the open ends
      # (checked above) stay butt-capped.
      expect(path.contains?(101, -1)).to be true
    end

    it 'includes the closing segment when closed: true' do
      # Triangle path; the closing segment is from (50,100) back to (0,0)
      tri = Polyline.new(points: [[0, 0], [100, 0], [50, 100]],
                         stroke_width: 4, closed: true)
      # Midpoint of the closing edge
      expect(tri.contains?(25, 50)).to be true
    end

    it 'does not include the closing segment when closed: false (default)' do
      tri = Polyline.new(points: [[0, 0], [100, 0], [50, 100]], stroke_width: 4)
      expect(tri.contains?(25, 50)).to be false
    end

    # A repeated point has no direction of its own. It used to collapse the
    # stroke to zero width there and taper the segments on either side; now it
    # counts as the point it repeats, so the path keeps its full width.
    it 'keeps its width across a repeated point' do
      plain = Polyline.new(points: [[5, 10], [30, 10], [55, 10]], stroke_width: 10)
      repeated = Polyline.new(points: [[5, 10], [30, 10], [30, 10], [55, 10]], stroke_width: 10)
      [[29, 13], [31, 7], [30, 14]].each do |px, py|
        expect(repeated.contains?(px, py)).to eq(plain.contains?(px, py)),
          "expected (#{px}, #{py}) to hit the same with the repeated point"
      end
      expect(repeated.contains?(29, 13)).to be true
      expect(repeated.contains?(30, 16)).to be false
    end

    it 'strokes a closed path of two distinct points as one segment' do
      back = Polyline.new(points: [[10, 10], [90, 10], [90, 10], [10, 10]],
                          stroke_width: 6, closed: true)
      expect(back.contains?(50, 12)).to be true
      expect(back.contains?(50, 14)).to be false
    end

    # An edge shorter than the reach of a sharp corner's miter can't share
    # the corner's inner point with its neighbor: the ribbon between them
    # folded over itself, painting a blob beside the path and pinching the
    # second segment's band, which the old hit test followed. Such a corner
    # keeps plain rectangle ends and draws the miter wedge on its own, so the
    # stroke is the two full bands plus the wedge.
    it 'keeps a sharp corner on a short segment within the stroke' do
      hook = Polyline.new(points: [[40, 80], [50, 70], [20, 70]], stroke_width: 30)
      expect(hook.contains?(34, 77)).to be true  # in the second segment's band, once pinched out
      expect(hook.contains?(19, 80)).to be false # past the second segment's butt cap, once inside the fold
      expect(hook.contains?(30, 86)).to be false # beside the path, where the blob was drawn
      expect(hook.contains?(30, 90)).to be false # past the first segment's butt cap
      expect(hook.contains?(50, 70)).to be true  # on the corner
      expect(hook.contains?(45, 75)).to be true  # on the first segment
      expect(hook.contains?(60, 62)).to be true  # in the miter wedge past the corner
    end

    # A ribbon join cuts each rectangle at the bisector and relies on the
    # neighbor to paint what it cut. A butt-capped end segment shorter than
    # that corner's reach can't, so the corner keeps plain ends instead of
    # leaving a notch in the long segment's band.
    it 'keeps the full band beside a short end segment' do
      elbow = Polyline.new(points: [[60, 200], [60, 100], [74.55, 87.79]], stroke_width: 80)
      expect(elbow.contains?(97, 110)).to be true
      expect(elbow.contains?(98, 114)).to be true
    end

    # A corner within about a degree of a reversal has no usable bisector;
    # it keeps plain ends rather than a miter computed from noise.
    it 'stays within the stroke at a near reversal' do
      pin = Polyline.new(points: [[97, 24], [86, 197], [94, 72]], stroke_width: 10)
      expect(pin.contains?(96, 4)).to be false
      expect(pin.contains?(90, 205)).to be false
      expect(pin.contains?(90, 100)).to be true
    end

    it 'rebuilds the stroke layout when the path, width, or closure changes' do
      path = Polyline.new(points: [[0, 0], [100, 0]], stroke_width: 4)
      expect(path.contains?(50, 5)).to be false
      path.stroke_width = 20
      expect(path.contains?(50, 5)).to be true
      path.y = 30
      expect(path.contains?(50, 5)).to be false
      expect(path.contains?(50, 35)).to be true
      tri = Polyline.new(points: [[0, 0], [100, 0], [50, 100]], stroke_width: 4)
      expect(tri.contains?(25, 50)).to be false
      tri.closed = true
      expect(tri.contains?(25, 50)).to be true
    end

    it 'is false with no stroke width, as nothing is drawn' do
      path = Polyline.new(points: [[0, 0], [100, 0]], stroke_width: 4)
      path.stroke_width = nil
      expect(path.contains?(50, 0)).to be false
    end
  end

  # A rotated polyline writes its rotated coordinates into a per-object buffer
  # reused across frames (the native draw copies the values out, so reuse is
  # safe). These pin the rotated values and the reuse.
  describe 'rotation at render' do
    it 'draws rotated coordinates, reusing one buffer across frames' do
      line = Polyline.new(points: [[0, 0], [100, 0]],
                          rotate: 90, rx: 0, ry: 0, add: false)
      captured = []
      allow(Ruby2D::Ext).to receive(:stroke_path) { |coords, *_| captured << coords }
      line.send(:render)
      line.send(:render)

      # 90° about the origin maps (x, y) to (-y, x)
      [0, 0, 0, 100].each_with_index do |expected, i|
        expect(captured.last[i]).to be_within(1e-9).of(expected)
      end
      # Same buffer both frames — no per-frame allocation
      expect(captured[0]).to be(captured[1])
      # The stored coordinates are untouched
      expect(line.instance_variable_get(:@coordinates)).to eq([0, 0, 100, 0])
    end
  end

  describe '#opacity with a per-vertex array' do
    it 'returns a copy, so the array read back cannot change the line' do
      line = Polyline.new(points: [[0, 0], [100, 0]], opacity: [1, 1], add: false)
      line.opacity.replace([0.0, 0.0])
      expect(line.opacity).to eq([1.0, 1.0])
    end

    it 'draws the alphas assigned through the setter' do
      line = Polyline.new(points: [[0, 0], [100, 0]], stroke_width: 4, opacity: [1, 1], add: false)
      alphas = nil
      allow(Ruby2D::Ext).to receive(:stroke_path) { |_, _, pvs, _| alphas = [pvs[3], pvs[7]] }
      line.send(:render)
      line.opacity.replace([0.0, 0.0])
      line.send(:render)
      expect(alphas).to eq([1.0, 1.0])
      expect(line.opacity).to eq([1.0, 1.0])
      line.opacity = [0.0, 0.5]
      line.send(:render)
      expect(alphas).to eq([0.0, 0.5])
    end
  end
end
