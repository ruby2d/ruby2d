require 'ruby2d'

RSpec.describe Ruby2D::Line do

  describe "#new" do
    it "creates a white line by default" do
      line = Line.new
      expect(line.color).to be_a(Ruby2D::Color)
      expect(line.color.r).to eq(1)
      expect(line.color.g).to eq(1)
      expect(line.color.b).to eq(1)
      expect(line.color.a).to eq(1)
    end

    it "creates a line with options" do
      line = Line.new(
        x1: 10, y1: 20, x2: 30, y2: 40, z: 50, width: 60,
        color: 'gray', opacity: 0.5
      )

      expect(line.x1).to eq(10)
      expect(line.y1).to eq(20)
      expect(line.x2).to eq(30)
      expect(line.y2).to eq(40)
      expect(line.z).to eq(50)
      expect(line.width).to eq(60)
      expect(line.length).to be_within(0.0001).of(28.2843)
      expect(line.color.r).to eq(2/3.0)
      expect(line.color.opacity).to eq(0.5)
    end

    it "creates a new line with one color via string" do
      line = Line.new(color: 'red')
      expect(line.color).to be_a(Ruby2D::Color)
    end

    it "creates a new line with one color via array of numbers" do
      line = Quad.new(color: [0.1, 0.3, 0.5, 0.7])
      expect(line.color).to be_a(Ruby2D::Color)
    end

    it "creates a new line with 4 colors via array of 4 strings" do
      line = Line.new(color: ['red', 'green', 'blue', 'black'])
      expect(line.color).to be_a(Ruby2D::Color::Set)
    end

    it "creates a new line with 4 colors via array of 4 arrays of arrays of numbers" do
      line = Line.new(
        color: [
          [0.1, 0.3, 0.5, 0.7],
          [0.2, 0.4, 0.6, 0.8],
          [0.3, 0.5, 0.7, 0.9],
          [0.4, 0.6, 0.8, 1.0]
        ]
      )
      expect(line.color).to be_a(Ruby2D::Color::Set)
    end

    it "throws an error when array of 3 strings is passed" do
      expect do
        Line.new(color: ['red', 'green', 'blue'])
      end.to raise_error("`Ruby2D::Line` requires 4 colors, one for each vertex. 3 were given.")
    end

    it "throws an error when array of 5 strings is passed" do
      expect do
        Line.new(color: ['red', 'green', 'blue', 'black', 'fuchsia'])
      end.to raise_error("`Ruby2D::Line` requires 4 colors, one for each vertex. 5 were given.")
    end
  end

  describe "attributes" do
    it "can be set and read" do
      line = Line.new
      line.x1 = 10
      line.y1 = 20
      line.x2 = 30
      line.y2 = 40
      line.z = 50
      line.width = 60
      line.color = 'gray'
      line.color.opacity = 0.5

      expect(line.x1).to eq(10)
      expect(line.y1).to eq(20)
      expect(line.x2).to eq(30)
      expect(line.y2).to eq(40)
      expect(line.z).to eq(50)
      expect(line.width).to eq(60)
      expect(line.length).to be_within(0.0001).of(28.2843)
      expect(line.color.r).to eq(2/3.0)
      expect(line.color.opacity).to eq(0.5)
    end
  end

  # TODO: This test should be more precise, like `Renderable#contains?`
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
