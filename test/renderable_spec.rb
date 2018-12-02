require 'ruby2d'

RSpec.describe Ruby2D::Renderable do

  it "allows colors to be set on objects" do
    quad = Quad.new

    quad.color = 'red'
    expect(quad.color.r).to eq(1)

    quad.color = [0.9, 0.8, 0.7, 0.6]
    expect(quad.color.r).to eq(0.9)
    expect(quad.color.g).to eq(0.8)
    expect(quad.color.b).to eq(0.7)
    expect(quad.color.a).to eq(0.6)

    quad.color.r = 0.1
    quad.color.g = 0.2
    quad.color.b = 0.3
    quad.color.a = 0.4
    expect(quad.color.r).to eq(0.1)
    expect(quad.color.g).to eq(0.2)
    expect(quad.color.b).to eq(0.3)
    expect(quad.color.a).to eq(0.4)

    quad.r = 0.5
    quad.g = 0.6
    quad.b = 0.7
    quad.a = 0.8
    expect(quad.r).to eq(0.5)
    expect(quad.g).to eq(0.6)
    expect(quad.b).to eq(0.7)
    expect(quad.a).to eq(0.8)
  end

  it "allows British English spelling of color (colour)" do
    quad = Quad.new

    quad.colour = 'blue'
    expect(quad.color.r).to eq(0)

    quad.colour = [0.1, 0.2, 0.3, 0.4]
    expect(quad.color.r).to eq(0.1)
    expect(quad.color.g).to eq(0.2)
    expect(quad.color.b).to eq(0.3)
    expect(quad.color.a).to eq(0.4)

    quad.colour.r = 0.9
    quad.colour.g = 0.8
    quad.colour.b = 0.7
    quad.colour.a = 0.6
    expect(quad.colour.r).to eq(0.9)
    expect(quad.colour.g).to eq(0.8)
    expect(quad.colour.b).to eq(0.7)
    expect(quad.colour.a).to eq(0.6)
    expect(quad.color.r).to eq(0.9)
    expect(quad.color.g).to eq(0.8)
    expect(quad.color.b).to eq(0.7)
    expect(quad.color.a).to eq(0.6)
    expect(quad.r).to eq(0.9)
    expect(quad.g).to eq(0.8)
    expect(quad.b).to eq(0.7)
    expect(quad.a).to eq(0.6)
  end

  describe "#contains?" do
    square = Square.new(x: 1, y: 1, size: 2)

    # Grid looks like this, 2x2 square at point (1, 1):
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

    it "returns true if point is inside the rectangle" do
      expect(square.contains?(1, 1)).to be true
      expect(square.contains?(2, 1)).to be true
      expect(square.contains?(3, 1)).to be true
      expect(square.contains?(1, 2)).to be true
      expect(square.contains?(2, 2)).to be true
      expect(square.contains?(3, 2)).to be true
      expect(square.contains?(1, 3)).to be true
      expect(square.contains?(2, 3)).to be true
      expect(square.contains?(3, 3)).to be true
    end

    it "returns false if point is outside the rectangle" do
      # Clockwise around the square
      expect(square.contains?(0, 0)).to be false
      expect(square.contains?(1, 0)).to be false
      expect(square.contains?(2, 0)).to be false
      expect(square.contains?(3, 0)).to be false
      expect(square.contains?(4, 0)).to be false
      expect(square.contains?(4, 1)).to be false
      expect(square.contains?(4, 2)).to be false
      expect(square.contains?(4, 3)).to be false
      expect(square.contains?(4, 4)).to be false
      expect(square.contains?(3, 4)).to be false
      expect(square.contains?(2, 4)).to be false
      expect(square.contains?(1, 4)).to be false
      expect(square.contains?(0, 4)).to be false
      expect(square.contains?(0, 3)).to be false
      expect(square.contains?(0, 2)).to be false
      expect(square.contains?(0, 1)).to be false
    end
  end

end
