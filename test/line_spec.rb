require 'ruby2d'

RSpec.describe Ruby2D::Line do

  describe "#contains?" do
    line = Line.new(x1: 0, y1: 0, x2: 100, y2: 100)

    it "returns true if point is inside the line" do
      expect(line.contains?(  0,   1)).to be true
      expect(line.contains?(100, 100)).to be true
    end

    it "returns false if point is outside the line" do
      expect(line.contains?(  0, 2)).to be false
      expect(line.contains?(101, 0)).to be false
    end
  end

end
