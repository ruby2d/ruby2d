require 'ruby2d'

RSpec.describe Ruby2D::Rectangle do

  describe "#contains?" do
    it "returns true if point is inside the rectangle" do
      rectangle = Rectangle.new(x: 0, y: 0, width: 50, height: 50)
      expect(rectangle.contains?(25, 25)).to be true
    end

    it "returns true if point is outside the rectangle" do
      rectangle = Rectangle.new(x: 0, y: 0, width: 50, height: 50)
      expect(rectangle.contains?( 0,  0)).to be true
      expect(rectangle.contains?(50,  0)).to be true
      expect(rectangle.contains?(50, 50)).to be true
      expect(rectangle.contains?( 0, 50)).to be true

      expect(rectangle.contains?(25, 25)).to be true

      expect(rectangle.contains?(-1,  0)).to be false
      expect(rectangle.contains?(0,  -1)).to be false
      expect(rectangle.contains?(51, 50)).to be false
      expect(rectangle.contains?(50, 51)).to be false
    end
  end

end
