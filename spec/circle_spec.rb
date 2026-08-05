RSpec.describe Ruby2D::Circle do

  describe "#new" do
    include_examples 'renderable color defaults', Ruby2D::Circle
    include_examples 'shape dimensions', Ruby2D::Circle

    it 'rejects a negative radius at construction, allowing zero' do
      expect { Circle.new(radius: -5) }.to raise_error(ArgumentError, /Circle radius must be zero or positive/)
      expect { Circle.new(radius: 0) }.not_to raise_error
    end

    it 'leaves the runtime radius setter permissive (animation-safe, no raise)' do
      circle = Circle.new(radius: 10)
      expect { circle.radius = -5 }.not_to raise_error
    end

    it "creates a circle with options" do
      circle = Circle.new(
        x: 10, y: 20, z: 30,
        radius: 40, sectors: 50,
        color: 'gray', opacity: 0.5
      )

      expect(circle.x).to eq(10)
      expect(circle.y).to eq(20)
      expect(circle.z).to eq(30)
      expect(circle.radius).to eq(40)
      expect(circle.sectors).to eq(50)
    end

    it "raises when opacity is an array (per-vertex opacity is unsupported)" do
      expect { Circle.new(opacity: [0.1, 0.2]) }.to raise_error(ArgumentError)
    end

    it "raises a clear error for a per-vertex color array" do
      expect { Circle.new(color: %w[red green blue]) }
        .to raise_error(ArgumentError, /does not support per-vertex colors/)
    end

    it "raises a clear error for a per-vertex stroke_color array" do
      expect { Circle.new(stroke_width: 2, stroke_color: %w[red green blue]) }
        .to raise_error(ArgumentError, /per-vertex stroke colors/)
    end

    it "rejects a per-vertex stroke_color array in .render, like the constructor" do
      expect { Circle.render(x: 0, y: 0, radius: 10, stroke_width: 2, stroke_color: %w[red blue]) }
        .to raise_error(ArgumentError, /per-vertex stroke colors/)
    end

    it "reports width and height as the diameter" do
      c = Circle.new(radius: 40)
      expect(c.width).to eq(80)
      expect(c.height).to eq(80)
    end
  end

  describe "attributes" do
    it "can be set and read" do
      circle = Circle.new
      circle.x = 10
      circle.y = 20
      circle.z = 30
      circle.radius = 40
      circle.sectors = 50

      expect(circle.x).to eq(10)
      expect(circle.y).to eq(20)
      expect(circle.z).to eq(30)
      expect(circle.radius).to eq(40)
      expect(circle.sectors).to eq(50)
    end
  end

  describe "#opacity=" do
    it "fades both the fill and the stroke, matching construction-time opacity:" do
      circle = Circle.new(color: 'red', stroke_color: 'blue', stroke_width: 4)
      circle.opacity = 0.3
      expect(circle.color.opacity).to eq(0.3)
      expect(circle.stroke_color.opacity).to eq(0.3)
    end
  end

  describe "#contains? with rotation" do
    it "follows the rotated center when rx/ry are offset" do
      # Rotating the center (0,0) 90° about (50,0) moves the drawn circle to
      # (50,-50); contains? must test against that, not the original center.
      circle = Circle.new(x: 0, y: 0, radius: 10, rotate: 90, rx: 50, ry: 0, add: false)
      expect(circle.contains?(50, -50)).to be true
      expect(circle.contains?(0, 0)).to be false
    end
  end

end
