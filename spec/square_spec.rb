RSpec.describe Ruby2D::Square do
  describe '#new' do
    include_examples 'renderable color defaults', Ruby2D::Square
    include_examples 'vertex color set', Ruby2D::Square, 4
    include_examples 'shape dimensions', Ruby2D::Square

    it 'rejects a negative size at construction, allowing zero' do
      expect { Square.new(size: -5) }.to raise_error(ArgumentError, /Square size must be zero or positive/)
      expect { Square.new(size: 0) }.not_to raise_error
    end

    it 'creates a square with options' do
      square = Square.new(
        x: 10, y: 20, z: 30,
        size: 40,
        color: 'gray', opacity: 0.5
      )

      expect(square.x).to eq(10)
      expect(square.y).to eq(20)
      expect(square.z).to eq(30)
      expect(square.size).to eq(40)
      expect(square.width).to eq(40)
      expect(square.height).to eq(40)
    end
  end

  describe 'attributes' do
    it 'can be set and read' do
      square = Square.new
      square.x = 10
      square.y = 20
      square.z = 30
      square.size = 40

      expect(square.x).to eq(10)
      expect(square.y).to eq(20)
      expect(square.z).to eq(30)
      expect(square.size).to eq(40)
    end
  end

  describe '#size=' do
    it 'syncs width and height to the new size' do
      square = Square.new(size: 50)
      square.size = 80
      expect(square.size).to eq(80)
      expect(square.width).to eq(80)
      expect(square.height).to eq(80)
    end
  end
end
