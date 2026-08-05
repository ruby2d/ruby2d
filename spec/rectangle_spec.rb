RSpec.describe Ruby2D::Rectangle do
  describe '#new' do
    include_examples 'renderable color defaults', Ruby2D::Rectangle
    include_examples 'vertex color set', Ruby2D::Rectangle, 4
    include_examples 'shape dimensions', Ruby2D::Rectangle

    it 'rejects negative dimensions at construction, allowing zero' do
      expect { Rectangle.new(width: -20) }.to raise_error(ArgumentError, /Rectangle width must be zero or positive/)
      expect { Rectangle.new(height: -10) }.to raise_error(ArgumentError, /Rectangle height must be zero or positive/)
      expect { Rectangle.new(width: 0, height: 0) }.not_to raise_error
    end

    it 'creates a rectangle with options' do
      rectangle = Rectangle.new(
        x: 10, y: 20, z: 30,
        width: 40, height: 50,
        color: 'gray', opacity: 0.5
      )

      expect(rectangle.x).to eq(10)
      expect(rectangle.y).to eq(20)
      expect(rectangle.z).to eq(30)
      expect(rectangle.width).to eq(40)
      expect(rectangle.height).to eq(50)
    end
  end

  describe 'attributes' do
    it 'can be set and read' do
      rectangle = Rectangle.new
      rectangle.x = 10
      rectangle.y = 20
      rectangle.z = 30
      rectangle.width = 40
      rectangle.height = 50

      expect(rectangle.x).to eq(10)
      expect(rectangle.y).to eq(20)
      expect(rectangle.z).to eq(30)
      expect(rectangle.width).to eq(40)
      expect(rectangle.height).to eq(50)
    end
  end

  describe '#contains? with rotation' do
    it 'tests against the rotated footprint, not the unrotated one' do
      # A 100×20 rect rotated 90° about its center (50, 10) renders as a tall,
      # thin rect; hit-testing must follow the rendered shape.
      rect = Rectangle.new(x: 0, y: 0, width: 100, height: 20, rotate: 90, add: false)
      expect(rect.contains?(50, 50)).to be true   # inside the rotated shape
      expect(rect.contains?(90, 10)).to be false  # only inside the unrotated footprint
    end
  end
end
