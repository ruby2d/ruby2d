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

    it 'moves the far corners with the size' do
      square = Square.new(x: 10, y: 20, size: 50)
      # Through `self.width =` the old code passed here and died on mruby,
      # which refuses a private setter called through `self`.
      expect(square).not_to receive(:width=)
      expect(square).not_to receive(:height=)
      square.size = 80
      expect([square.x2, square.x3]).to eq([90, 90])
      expect([square.y3, square.y4]).to eq([100, 100])
      expect([square.x1, square.x4, square.y1, square.y2]).to eq([10, 10, 20, 20])
      expect(square.contains?(89, 99)).to be true
      expect(square.contains?(90, 99)).to be false
    end

    it 'keeps width and height private, so size is the only dimension setter' do
      square = Square.new(size: 50)
      expect { square.width = 80 }.to raise_error(NoMethodError)
      expect { square.height = 80 }.to raise_error(NoMethodError)
    end
  end
end
