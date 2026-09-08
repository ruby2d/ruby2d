RSpec.describe Ruby2D::Line do

  describe "#new" do
    include_examples 'renderable color defaults', Ruby2D::Line
    include_examples 'shape dimensions', Ruby2D::Line

    it "creates a line with options" do
      line = Line.new(
        x1: 10, y1: 20, x2: 30, y2: 40, z: 50, stroke_width: 60,
        color: 'gray', opacity: 0.5
      )

      expect(line.x1).to eq(10)
      expect(line.y1).to eq(20)
      expect(line.x2).to eq(30)
      expect(line.y2).to eq(40)
      expect(line.z).to eq(50)
      expect(line.stroke_width).to eq(60)
      expect(line.length).to be_within(0.0001).of(28.2843)
    end

    it "accepts endpoints as points: [[x, y], [x, y]]" do
      line = Line.new(points: [[10, 20], [30, 40]])
      expect(line.x1).to eq(10)
      expect(line.y1).to eq(20)
      expect(line.x2).to eq(30)
      expect(line.y2).to eq(40)
    end

    it "raises if points: has the wrong length" do
      expect { Line.new(points: [[0, 0]]) }
        .to raise_error('Line requires exactly 2 points')
    end

    it "raises if points: contains a non-pair" do
      expect { Line.new(points: [[0, 0], [10]]) }
        .to raise_error('points must be an array of [x, y] pairs')
    end

    # Line uses 2 colors (start, end) for gradients, not per-vertex
    it "creates a new line with 2 colors via array of 2 strings" do
      line = Line.new(color: ['red', 'blue'])
      expect(line.color).to be_a(Ruby2D::Color::Set)
    end

    it "creates a new line with 2 colors via array of 2 [r, g, b, a]" do
      line = Line.new(color: [[0.1, 0.3, 0.5, 0.7], [0.2, 0.4, 0.6, 0.8]])
      expect(line.color).to be_a(Ruby2D::Color::Set)
    end

    it "raises when given 3 colors (gradient requires exactly 2)" do
      expect { Line.new(color: %w[red green blue]) }
        .to raise_error('`Ruby2D::Line` requires 2 colors (start, end) for a gradient. 3 were given.')
    end

    it "accepts dash: and gap: for a dashed line" do
      line = Line.new(dash: 12, gap: 4)
      expect(line.dash).to eq(12)
      expect(line.gap).to eq(4)
    end

    it "defaults dash to 0 (solid line)" do
      expect(Line.new.dash).to eq(0)
    end
  end

  describe "attributes" do
    it "can be set and read" do
      line = Line.new
      line.x1 = 10
      line.y1 = 20
      line.x2 = 30
      line.y2 = 40
      line.z = 50
      line.stroke_width = 60
      line.dash = 20
      line.gap = 10

      expect(line.x1).to eq(10)
      expect(line.y1).to eq(20)
      expect(line.x2).to eq(30)
      expect(line.y2).to eq(40)
      expect(line.z).to eq(50)
      expect(line.stroke_width).to eq(60)
      expect(line.dash).to eq(20)
      expect(line.gap).to eq(10)
      expect(line.length).to be_within(0.0001).of(28.2843)
    end
  end

  describe "#contains?" do
    line = Line.new(x1: 0, y1: 0, x2: 100, y2: 100, stroke_width: 2, add: false)

    it "returns true if point is inside the line" do
      expect(line.contains?(  0,   1)).to be true
      expect(line.contains?(100, 100)).to be true
    end

    it "returns false if point is outside the line" do
      expect(line.contains?(  0, 2)).to be false
      expect(line.contains?(101, 0)).to be false
    end

    # A non-positive stroke width draws nothing, so even a point exactly on the
    # segment must not be contained.
    it "returns false for any point when stroke_width is non-positive" do
      thin = Line.new(x1: 0, y1: 0, x2: 100, y2: 100, stroke_width: -2)
      expect(thin.contains?(50, 50)).to be false
    end

    # Regression: integer coordinates must not trigger integer floor division in
    # the segment projection. That would snap the projection parameter to 0/1
    # and measure distance to an endpoint, so the middle of the line — here the
    # exact midpoint — would wrongly read as outside.
    it "contains the midpoint when coordinates are integers" do
      expect(line.contains?(50, 50)).to be true
    end

    # The hit region matches the drawn (butt-capped) rectangle: it must not
    # extend past the segment ends, even within half the stroke width of an
    # endpoint (which the old clamped-distance test wrongly included).
    it "does not contain points past the butt-cap ends" do
      thick = Line.new(x1: 0, y1: 0, x2: 100, y2: 0, stroke_width: 20)
      expect(thick.contains?(100, 0)).to be true   # exactly at the end
      expect(thick.contains?( 99, 5)).to be true   # inside, near the end
      expect(thick.contains?(105, 0)).to be false  # 5px past the end
      expect(thick.contains?( -5, 0)).to be false  # 5px before the start
    end

    # A dashed line draws only its dashes, starting at (x1, y1) and repeating
    # every dash + gap, so a point in a gap is on the segment but not on the
    # stroke.
    context "when dashed" do
      it "contains the dashes and not the gaps" do
        dashed = Line.new(x1: 0, y1: 10, x2: 60, y2: 10, stroke_width: 4, dash: 10, gap: 10, add: false)
        expect(dashed.contains?( 5, 10)).to be true   # first dash
        expect(dashed.contains?(15, 10)).to be false  # first gap
        expect(dashed.contains?(25, 10)).to be true   # second dash
        expect(dashed.contains?(15, 11)).to be false  # the gap spans the stroke width too
        expect(dashed.contains?(25, 11)).to be true
      end

      it "cuts the last dash at the endpoint, which a whole number of steps leaves in a gap" do
        # Length 25: dashes 0-10 and 20-25.
        cut = Line.new(x1: 0, y1: 0, x2: 25, y2: 0, stroke_width: 2, dash: 10, gap: 10, add: false)
        expect(cut.contains?(24, 0)).to be true
        expect(cut.contains?(25, 0)).to be true
        # Length 40: dashes 0-10 and 20-30, then a gap to the end.
        even = Line.new(x1: 0, y1: 0, x2: 40, y2: 0, stroke_width: 2, dash: 10, gap: 10, add: false)
        expect(even.contains?(35, 0)).to be false
        expect(even.contains?(40, 0)).to be false
      end

      it "treats a negative gap as none, like the renderer" do
        # A gap that would cancel the dash: without the normalization the
        # step is zero and nothing is on a dash.
        solid = Line.new(x1: 0, y1: 0, x2: 60, y2: 0, stroke_width: 2, dash: 10, gap: -10, add: false)
        expect(solid.contains?(15, 0)).to be true
      end

      it "follows the rotated segment" do
        # Rotated 90° about its center (30, 10), the line runs from (30, -20)
        # to (30, 40) with the pattern starting at (30, -20): dash to -10, gap
        # to 0, dash to 10.
        rotated = Line.new(x1: 0, y1: 10, x2: 60, y2: 10, stroke_width: 4, dash: 10, gap: 10, rotate: 90, add: false)
        expect(rotated.contains?(30, -5)).to be false
        expect(rotated.contains?(30,  5)).to be true
      end

      it "scales the pattern up past 10,000 steps, as the renderer does" do
        # 50,000 steps of 2 would stall a frame, so the renderer draws 10,000
        # steps of 10 (dash 5, gap 5) instead, and the hit region follows.
        long = Line.new(x1: 0, y1: 0, x2: 100_000, y2: 0, stroke_width: 2, dash: 1, gap: 1, add: false)
        expect(long.contains?(3, 0)).to be true   # dash 0-5
        expect(long.contains?(7, 0)).to be false  # gap 5-10; a dash under the unscaled pattern
      end
    end
  end

end
