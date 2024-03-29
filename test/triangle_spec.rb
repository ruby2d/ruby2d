require 'ruby2d'

RSpec.describe Ruby2D::Triangle do

  describe "#new" do
    it "creates a white triangle by default" do
      triangle = Triangle.new
      expect(triangle.color).to be_a(Ruby2D::Color)
      expect(triangle.color.r).to eq(1)
      expect(triangle.color.g).to eq(1)
      expect(triangle.color.b).to eq(1)
      expect(triangle.color.a).to eq(1)
    end

    it "creates a triangle with options" do
      triangle = Triangle.new(
        x1: 10, y1: 20, x2: 30, y2: 40, x3: 50, y3: 60, z: 70,
        color: 'gray', opacity: 0.5
      )

      expect(triangle.x1).to eq(10)
      expect(triangle.y1).to eq(20)
      expect(triangle.x2).to eq(30)
      expect(triangle.y2).to eq(40)
      expect(triangle.x3).to eq(50)
      expect(triangle.y3).to eq(60)
      expect(triangle.z).to eq(70)
      expect(triangle.color.r).to eq(2/3.0)
      expect(triangle.color.opacity).to eq(0.5)
    end

    it "creates a new triangle with one color via string" do
      triangle = Triangle.new(color: 'black')
      expect(triangle.color).to be_a(Ruby2D::Color)
    end

    it "creates a new triangle with one color via array of numbers" do
      triangle = Triangle.new(color: [0.1, 0.3, 0.5, 0.7])
      expect(triangle.color).to be_a(Ruby2D::Color)
    end

    it "creates a new triangle with 3 colors via array of 3 strings" do
      triangle = Triangle.new(color: ['red', 'green', 'blue'])
      expect(triangle.color).to be_a(Ruby2D::Color::Set)
    end

    it "creates a new triangle with 3 colors via array of 3 arrays of arrays of numbers" do
      triangle = Triangle.new(
        color: [
          [0.1, 0.3, 0.5, 0.7],
          [0.2, 0.4, 0.6, 0.8],
          [0.3, 0.5, 0.7, 0.9]
        ]
      )
      expect(triangle.color).to be_a(Ruby2D::Color::Set)
    end

    it "throws an error when array of 2 strings is passed" do
      expect do
        Triangle.new(color: ['red', 'green'])
      end.to raise_error("`Ruby2D::Triangle` requires 3 colors, one for each vertex. 2 were given.")
    end

    it "throws an error when array of 4 strings is passed" do
      expect do
        Triangle.new(color: ['red', 'green', 'blue', 'fuchsia'])
      end.to raise_error("`Ruby2D::Triangle` requires 3 colors, one for each vertex. 4 were given.")
    end
  end

  describe "attributes" do
    it "can be set and read" do
      triangle = Triangle.new
      triangle.x1 = 10
      triangle.y1 = 20
      triangle.x2 = 30
      triangle.y2 = 40
      triangle.x3 = 50
      triangle.y3 = 60
      triangle.z = 70
      triangle.color = 'gray'
      triangle.color.opacity = 0.5

      expect(triangle.x1).to eq(10)
      expect(triangle.y1).to eq(20)
      expect(triangle.x2).to eq(30)
      expect(triangle.y2).to eq(40)
      expect(triangle.x3).to eq(50)
      expect(triangle.y3).to eq(60)
      expect(triangle.z).to eq(70)
      expect(triangle.color.r).to eq(2/3.0)
      expect(triangle.color.opacity).to eq(0.5)
    end
  end

  # TODO: This test should be more precise, like `Renderable#contains?`
  describe "#contains?" do
    triangle = Triangle.new(
      x1:   0, y1:   0,
      x2:   0, y2: 100,
      x3: 100, y3:   0
    )

    it "returns true if point is inside the triangle" do
      expect(triangle.contains?( 0,  0)).to be true
      expect(triangle.contains?(25, 25)).to be true
    end

    it "returns false if point is outside the triangle" do
      expect(triangle.contains?( 25, -25)).to be false
      expect(triangle.contains?(-25,  25)).to be false
      expect(triangle.contains?(100,   1)).to be false
    end
  end

end
