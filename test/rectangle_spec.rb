require 'ruby2d'

RSpec.describe Ruby2D::Rectangle do
  describe '#contains?' do
    it "returns true if point is inside rectangle" do
      rectangle = Rectangle.new(x: 0, y: 0, width: 50, height: 50)
      expect(rectangle.contains?(25, 25)).to be true
    end

    it "returns true if point is not inside rectangle" do
      rectangle = Rectangle.new(x: 0, y: 0, width: 50, height: 50)
      expect(rectangle.contains?(-25,  25)).to be false
      expect(rectangle.contains?( 25, -25)).to be false
      expect(rectangle.contains?( 25,  50)).to be false
      expect(rectangle.contains?( 50,  25)).to be false
    end
  end

  describe '#collided_with?' do
    it "returns false if passed rectangle is not inside rectangle" do
      rectangleA = Rectangle.new(x: 0, y: 0, width: 50, height: 50)
      rectangleB = Rectangle.new(x: 100, y: 100, width: 50, height: 50)

      expect(rectangleA.collided_with?(rectangleB)).to be false
    end

    it "returns true if passed rectangle is inside rectangle" do
        rectangleA = Rectangle.new(x: 0, y: 0, width: 50, height: 50)
        rectangleB = Rectangle.new(x: 25, y: 25, width: 50, height: 50)

        expect(rectangleA.collided_with?(rectangleB)).to be true
    end
  end
end
