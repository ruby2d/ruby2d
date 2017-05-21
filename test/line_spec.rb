require 'ruby2d'

RSpec.describe Ruby2D::Triangle do
  describe '#contains?' do
    it "returns true if point is inside line" do
      line = Line.new(
        0, 0,
        100, 100
      )
      expect(line.contains?(25, 25)).to be true
    end

    it "returns true if point is inside text" do
      line = Line.new(
        0, 0,
        100, 100
      )

      expect(line.contains?(0, 10)).to be false
      expect(line.contains?(10, 0)).to be false
    end
  end
end
