require 'ruby2d'

RSpec.describe Ruby2D::Renderable do

  # Create and use a fresh class to ensure nothing is overridden
  class SomeShape
    prepend Renderable

    def initialize(x: 0, y: 0, w: 100, h: 100); end
  end

  it "allows colors to be set on objects" do
    shape = SomeShape.new

    shape.color = 'red'
    expect(shape.color.r).to eq(1)

    shape.color = [0.9, 0.8, 0.7, 0.6]
    expect(shape.color.r).to eq(0.9)
    expect(shape.color.g).to eq(0.8)
    expect(shape.color.b).to eq(0.7)
    expect(shape.color.a).to eq(0.6)

    shape.color.r = 0.1
    shape.color.g = 0.2
    shape.color.b = 0.3
    shape.color.a = 0.4
    expect(shape.color.r).to eq(0.1)
    expect(shape.color.g).to eq(0.2)
    expect(shape.color.b).to eq(0.3)
    expect(shape.color.a).to eq(0.4)
  end

  it "allows British English spelling of color (colour)" do
    shape = SomeShape.new

    shape.colour = 'blue'
    expect(shape.color.r).to eq(0)

    shape.colour = [0.1, 0.2, 0.3, 0.4]
    expect(shape.color.r).to eq(0.1)
    expect(shape.color.g).to eq(0.2)
    expect(shape.color.b).to eq(0.3)
    expect(shape.color.a).to eq(0.4)

    shape.colour.r = 0.9
    shape.colour.g = 0.8
    shape.colour.b = 0.7
    shape.colour.a = 0.6
    expect(shape.colour.r).to eq(0.9)
    expect(shape.colour.g).to eq(0.8)
    expect(shape.colour.b).to eq(0.7)
    expect(shape.colour.a).to eq(0.6)
    expect(shape.color.r).to eq(0.9)
    expect(shape.color.g).to eq(0.8)
    expect(shape.color.b).to eq(0.7)
    expect(shape.color.a).to eq(0.6)
  end

  describe "#contains?" do

    shape = SomeShape.new(x: 1, y: 1, width: 2, height: 2)

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

    it "returns true if point is inside the shape" do
      expect(shape.contains?(1, 1)).to be true
      expect(shape.contains?(2, 1)).to be true
      expect(shape.contains?(3, 1)).to be true
      expect(shape.contains?(1, 2)).to be true
      expect(shape.contains?(2, 2)).to be true
      expect(shape.contains?(3, 2)).to be true
      expect(shape.contains?(1, 3)).to be true
      expect(shape.contains?(2, 3)).to be true
      expect(shape.contains?(3, 3)).to be true
    end

    it "returns false if point is outside the shape" do
      # Clockwise around the shape
      expect(shape.contains?(0, 0)).to be false
      expect(shape.contains?(1, 0)).to be false
      expect(shape.contains?(2, 0)).to be false
      expect(shape.contains?(3, 0)).to be false
      expect(shape.contains?(4, 0)).to be false
      expect(shape.contains?(4, 1)).to be false
      expect(shape.contains?(4, 2)).to be false
      expect(shape.contains?(4, 3)).to be false
      expect(shape.contains?(4, 4)).to be false
      expect(shape.contains?(3, 4)).to be false
      expect(shape.contains?(2, 4)).to be false
      expect(shape.contains?(1, 4)).to be false
      expect(shape.contains?(0, 4)).to be false
      expect(shape.contains?(0, 3)).to be false
      expect(shape.contains?(0, 2)).to be false
      expect(shape.contains?(0, 1)).to be false
    end
  end

end
