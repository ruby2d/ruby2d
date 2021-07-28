require 'ruby2d'

RSpec.describe Ruby2D::Square do

  describe "#new" do
    it "creates a white square by default" do
      square = Square.new
      expect(square.color).to be_a(Ruby2D::Color)
      expect(square.color.r).to eq(1)
      expect(square.color.g).to eq(1)
      expect(square.color.b).to eq(1)
      expect(square.color.a).to eq(1)
    end

    it "creates a square with options" do
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
      expect(square.color.r).to eq(2/3.0)
      expect(square.color.opacity).to eq(0.5)
    end

    it "creates a new square with one color via string" do
      square = Square.new(color: 'red')
      expect(square.color).to be_a(Ruby2D::Color)
    end

    it "creates a new square with one color via array of numbers" do
      square = Square.new(color: [0.1, 0.3, 0.5, 0.7])
      expect(square.color).to be_a(Ruby2D::Color)
    end

    it "creates a new square with 4 colors via array of 4 strings" do
      square = Square.new(color: ['red', 'green', 'blue', 'black'])
      expect(square.color).to be_a(Ruby2D::Color::Set)
    end

    it "creates a new square with 4 colors via array of 4 arrays of arrays of numbers" do
      square = Square.new(
        color: [
          [0.1, 0.3, 0.5, 0.7],
          [0.2, 0.4, 0.6, 0.8],
          [0.3, 0.5, 0.7, 0.9],
          [0.4, 0.6, 0.8, 1.0]
        ]
      )
      expect(square.color).to be_a(Ruby2D::Color::Set)
    end

    it "throws an error when array of 3 strings is passed" do
      expect do
        Square.new(color: ['red', 'green', 'blue'])
      end.to raise_error("`Ruby2D::Square` requires 4 colors, one for each vertex. 3 were given.")
    end

    it "throws an error when array of 5 strings is passed" do
      expect do
        Square.new(color: ['red', 'green', 'blue', 'black', 'fuchsia'])
      end.to raise_error("`Ruby2D::Square` requires 4 colors, one for each vertex. 5 were given.")
    end
  end

  describe "attributes" do
    it "can be set and read" do
      square = Square.new
      square.x = 10
      square.y = 20
      square.z = 30
      square.size = 40
      square.color = 'gray'
      square.color.opacity = 0.5

      expect(square.x).to eq(10)
      expect(square.y).to eq(20)
      expect(square.z).to eq(30)
      expect(square.size).to eq(40)
      expect(square.color.r).to eq(2/3.0)
      expect(square.color.opacity).to eq(0.5)
    end
  end

end
