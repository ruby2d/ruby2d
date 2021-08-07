require 'ruby2d'

RSpec.describe Ruby2D::Quad do

  describe "#new" do
    it "creates a white quad by default" do
      quad = Quad.new
      expect(quad.color).to be_a(Ruby2D::Color)
      expect(quad.color.r).to eq(1)
      expect(quad.color.g).to eq(1)
      expect(quad.color.b).to eq(1)
      expect(quad.color.a).to eq(1)
    end

    it "creates a quad with options" do
      quad = Quad.new(
        x1: 10, y1: 20,
        x2: 30, y2: 40,
        x3: 50, y3: 60,
        x4: 70, y4: 80,
        z: 90,
        color: 'gray', opacity: 0.5
      )

      expect(quad.x1).to eq(10)
      expect(quad.y1).to eq(20)
      expect(quad.x2).to eq(30)
      expect(quad.y2).to eq(40)
      expect(quad.x3).to eq(50)
      expect(quad.y3).to eq(60)
      expect(quad.x4).to eq(70)
      expect(quad.y4).to eq(80)
      expect(quad.z).to eq(90)
      expect(quad.color.r).to eq(2/3.0)
      expect(quad.color.opacity).to eq(0.5)
    end

    it "creates a new quad with one color via string" do
      quad = Quad.new(color: 'red')
      expect(quad.color).to be_a(Ruby2D::Color)
    end

    it "creates a new quad with one color via array of numbers" do
      quad = Quad.new(color: [0.1, 0.3, 0.5, 0.7])
      expect(quad.color).to be_a(Ruby2D::Color)
    end

    it "creates a new quad with 4 colors via array of 4 strings" do
      quad = Quad.new(color: ['red', 'green', 'blue', 'black'])
      expect(quad.color).to be_a(Ruby2D::Color::Set)
    end

    it "creates a new quad with 4 colors via array of 4 arrays of arrays of numbers" do
      quad = Quad.new(
        color: [
          [0.1, 0.3, 0.5, 0.7],
          [0.2, 0.4, 0.6, 0.8],
          [0.3, 0.5, 0.7, 0.9],
          [0.4, 0.6, 0.8, 1.0]
        ]
      )
      expect(quad.color).to be_a(Ruby2D::Color::Set)
    end

    it "throws an error when array of 3 strings is passed" do
      expect do
        Quad.new(color: ['red', 'green', 'blue'])
      end.to raise_error("`Ruby2D::Quad` requires 4 colors, one for each vertex. 3 were given.")
    end

    it "throws an error when array of 5 strings is passed" do
      expect do
        Quad.new(color: ['red', 'green', 'blue', 'black', 'fuchsia'])
      end.to raise_error("`Ruby2D::Quad` requires 4 colors, one for each vertex. 5 were given.")
    end
  end

  describe "attributes" do
    it "can be set and read" do
      quad = Quad.new
      quad.x1 = 10
      quad.y1 = 20
      quad.x2 = 30
      quad.y2 = 40
      quad.x3 = 50
      quad.y3 = 60
      quad.x4 = 70
      quad.y4 = 80
      quad.z = 90
      quad.color = 'gray'
      quad.color.opacity = 0.5

      expect(quad.x1).to eq(10)
      expect(quad.y1).to eq(20)
      expect(quad.x2).to eq(30)
      expect(quad.y2).to eq(40)
      expect(quad.x3).to eq(50)
      expect(quad.y3).to eq(60)
      expect(quad.x4).to eq(70)
      expect(quad.y4).to eq(80)
      expect(quad.z).to eq(90)
      expect(quad.color.r).to eq(2/3.0)
      expect(quad.color.opacity).to eq(0.5)
    end
  end

  # Quads define their own `contains?` method
  describe "#contains?" do
    quad = Quad.new(
      x1: 1, y1: 1,
      x2: 3, y2: 1,
      x3: 3, y3: 3,
      x4: 1, y4: 3
    )

    # Grid looks like this, 2x2 quad at point (1, 1):
    #
    #   0  1  2  3  4
    # 0 +--+--+--+--+
    #   |  |  |  |  |
    # 1 +--+--+--+--+
    #   |  |XX|XX|  |
    # 2 +--+--+--+--+
    #   |  |XX|XX|  |
    # 3 +--+--+--+--+
    #   |  |  |  |  |
    # 4 +--+--+--+--+

    it "returns true if point is inside the quad" do
      expect(quad.contains?(1, 1)).to be true
      expect(quad.contains?(2, 1)).to be true
      expect(quad.contains?(3, 1)).to be true
      expect(quad.contains?(1, 2)).to be true
      expect(quad.contains?(2, 2)).to be true
      expect(quad.contains?(3, 2)).to be true
      expect(quad.contains?(1, 3)).to be true
      expect(quad.contains?(2, 3)).to be true
      expect(quad.contains?(3, 3)).to be true
    end

    it "returns false if point is outside the quad" do
      # Clockwise around the quad
      expect(quad.contains?(0, 0)).to be false
      expect(quad.contains?(1, 0)).to be false
      expect(quad.contains?(2, 0)).to be false
      expect(quad.contains?(3, 0)).to be false
      expect(quad.contains?(4, 0)).to be false
      expect(quad.contains?(4, 1)).to be false
      expect(quad.contains?(4, 2)).to be false
      expect(quad.contains?(4, 3)).to be false
      expect(quad.contains?(4, 4)).to be false
      expect(quad.contains?(3, 4)).to be false
      expect(quad.contains?(2, 4)).to be false
      expect(quad.contains?(1, 4)).to be false
      expect(quad.contains?(0, 4)).to be false
      expect(quad.contains?(0, 3)).to be false
      expect(quad.contains?(0, 2)).to be false
      expect(quad.contains?(0, 1)).to be false
    end
  end

end
