RSpec.describe Ruby2D::Ellipse do

  describe "#new" do
    include_examples 'renderable color defaults', Ruby2D::Ellipse
    include_examples 'shape dimensions', Ruby2D::Ellipse

    it 'rejects negative radii at construction, allowing zero' do
      expect { Ellipse.new(xradius: -5) }.to raise_error(ArgumentError, /Ellipse xradius must be zero or positive/)
      expect { Ellipse.new(yradius: -5) }.to raise_error(ArgumentError, /Ellipse yradius must be zero or positive/)
      expect { Ellipse.new(xradius: 0, yradius: 0) }.not_to raise_error
    end

    it "creates an ellipse with options" do
      ellipse = Ellipse.new(
        x: 10, y: 20, z: 30,
        xradius: 40, yradius: 25, sectors: 50,
        color: 'gray', opacity: 0.5
      )

      expect(ellipse.x).to eq(10)
      expect(ellipse.y).to eq(20)
      expect(ellipse.z).to eq(30)
      expect(ellipse.xradius).to eq(40)
      expect(ellipse.yradius).to eq(25)
      expect(ellipse.sectors).to eq(50)
    end

    it "accepts stroke_width and stroke_color" do
      ellipse = Ellipse.new(stroke_width: 3, stroke_color: 'red')
      expect(ellipse.stroke_width).to eq(3)
      expect(ellipse.stroke_color).to be_a(Ruby2D::Color)
    end

    it "defaults stroke_color to the fill color when unspecified" do
      ellipse = Ellipse.new(stroke_width: 2, color: 'lime')
      expect(ellipse.stroke_color.r).to eq(Ruby2D::Color.new('lime').r)
      expect(ellipse.stroke_color.g).to eq(Ruby2D::Color.new('lime').g)
      expect(ellipse.stroke_color.b).to eq(Ruby2D::Color.new('lime').b)
    end

    it "defaults fill to true" do
      expect(Ellipse.new.fill).to be true
    end

    it "accepts fill: false" do
      expect(Ellipse.new(fill: false).fill).to be false
    end

    it "raises a clear error for a per-vertex color array" do
      expect { Ellipse.new(color: %w[red green blue]) }
        .to raise_error(ArgumentError, /does not support per-vertex colors/)
    end

    it "raises a clear error for a per-vertex stroke_color array" do
      expect { Ellipse.new(stroke_width: 2, stroke_color: %w[red green blue]) }
        .to raise_error(ArgumentError, /per-vertex stroke colors/)
    end

    it "rejects a per-vertex stroke_color array in .render, like the constructor" do
      expect { Ellipse.render(x: 0, y: 0, xradius: 10, yradius: 8, stroke_width: 2, stroke_color: %w[red blue]) }
        .to raise_error(ArgumentError, /per-vertex stroke colors/)
    end

    it "reports width and height as the axis diameters" do
      e = Ellipse.new(xradius: 60, yradius: 30)
      expect(e.width).to eq(120)
      expect(e.height).to eq(60)
    end
  end

  describe "attributes" do
    it "can be set and read" do
      ellipse = Ellipse.new
      ellipse.x = 10
      ellipse.y = 20
      ellipse.z = 30
      ellipse.xradius = 40
      ellipse.yradius = 25
      ellipse.sectors = 50

      expect(ellipse.x).to eq(10)
      expect(ellipse.y).to eq(20)
      expect(ellipse.z).to eq(30)
      expect(ellipse.xradius).to eq(40)
      expect(ellipse.yradius).to eq(25)
      expect(ellipse.sectors).to eq(50)
    end

    it "exposes rotation center defaulting to (x, y)" do
      ellipse = Ellipse.new(x: 15, y: 25)
      expect(ellipse.rx).to eq(15)
      expect(ellipse.ry).to eq(25)
    end

    it "allows overriding rotation center via rx=/ry=" do
      ellipse = Ellipse.new(x: 15, y: 25)
      ellipse.rx = 0
      ellipse.ry = 0
      expect(ellipse.rx).to eq(0)
      expect(ellipse.ry).to eq(0)
    end
  end

  describe "rotation" do
    it "reads back a rotate option (degrees)" do
      expect(Ellipse.new(rotate: 30).rotate).to eq(30)
    end

    it "tilts the shape so #contains? follows the rotation" do
      # A 50×10 ellipse rotated 90° about its center swaps its axes: a point far
      # along the now-vertical major axis lands inside, while the same distance
      # along the now-horizontal minor axis lands outside.
      tilted = Ellipse.new(x: 100, y: 100, xradius: 50, yradius: 10, rotate: 90, add: false)
      expect(tilted.contains?(100, 145)).to be true
      expect(tilted.contains?(145, 100)).to be false

      # Unrotated, those two verdicts are reversed.
      flat = Ellipse.new(x: 100, y: 100, xradius: 50, yradius: 10, add: false)
      expect(flat.contains?(100, 145)).to be false
      expect(flat.contains?(145, 100)).to be true
    end
  end

  describe "#contains?" do
    let(:ellipse) { Ellipse.new(x: 100, y: 100, xradius: 50, yradius: 25) }

    it "returns true at the center" do
      expect(ellipse.contains?(100, 100)).to be true
    end

    it "returns true on the x-axis boundary" do
      expect(ellipse.contains?(150, 100)).to be true
      expect(ellipse.contains?( 50, 100)).to be true
    end

    it "returns true on the y-axis boundary" do
      expect(ellipse.contains?(100, 125)).to be true
      expect(ellipse.contains?(100,  75)).to be true
    end

    it "returns false outside the x-axis extent" do
      expect(ellipse.contains?(151, 100)).to be false
      expect(ellipse.contains?( 49, 100)).to be false
    end

    it "returns false outside the y-axis extent" do
      expect(ellipse.contains?(100, 126)).to be false
      expect(ellipse.contains?(100,  74)).to be false
    end

    it "returns false outside the ellipse even within the bounding box" do
      # Corner of the (50, 25) bounding box — inside the rectangle, outside the ellipse
      expect(ellipse.contains?(150, 125)).to be false
    end

    context "with a degenerate (zero) radius" do
      it "is inside only at the center when both radii are 0 (matching Circle)" do
        point = Ellipse.new(x: 100, y: 100, xradius: 0, yradius: 0)
        expect(point.contains?(100, 100)).to be true
        expect(point.contains?(101, 100)).to be false
        expect(point.contains?(100, 101)).to be false
      end

      it "collapses to a vertical segment when xradius is 0" do
        seg = Ellipse.new(x: 100, y: 100, xradius: 0, yradius: 25)
        expect(seg.contains?(100, 100)).to be true  # center
        expect(seg.contains?(100, 125)).to be true  # on the segment
        expect(seg.contains?(100, 126)).to be false # past the segment
        expect(seg.contains?(101, 100)).to be false # off the segment axis
      end
    end
  end

end
