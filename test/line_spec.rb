require 'ruby2d'

RSpec.describe Ruby2D::Line do

  describe "#contains?" do
    it "returns true if point is inside the line" do
      line = Line.new(x1: 0, y1: 0, x2: 100, y2: 100)
      expect(line.contains?(25, 25)).to be true
    end

    it "returns false if point is outside the line" do
      line = Line.new(x1: 0, y1: 0, x2: 100, y2: 100)
      expect(line.contains?(0, 10)).to be false
      expect(line.contains?(10, 0)).to be false
    end
  end

end
