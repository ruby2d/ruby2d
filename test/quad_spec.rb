require 'ruby2d'

RSpec.describe Ruby2D::Quad do

  describe "#new" do
    it "creates a quad with white color by default" do
      quad = Quad.new
      expect(quad.color).to be_a(Ruby2D::Color)
      expect(quad.color.r).to eq(1)
      expect(quad.color.g).to eq(1)
      expect(quad.color.b).to eq(1)
      expect(quad.color.a).to eq(1)
    end

    it "creates a new quad with one color via string" do
      quad = Quad.new(color: 'red')
      expect(quad.color).to be_a(Ruby2D::Color)
    end

    it "creates a new triangle with one color via array of numbers" do
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
      end.to raise_error("Quads require 4 colors, one for each vertex. 3 were given.")
    end

    it "throws an error when array of 5 strings is passed" do
      expect do
        Quad.new(color: ['red', 'green', 'blue', 'black', 'fuchsia'])
      end.to raise_error("Quads require 4 colors, one for each vertex. 5 were given.")
    end
  end

  describe "#contains?" do
    quad = Quad.new(
      x1: -25, y1:   0,
      x2:   0, y2: -25,
      x3:  25, y3:   0,
      x4:   0, y4:  25
    )

    it "returns true if point is inside the quad" do
      expect(quad.contains?(0 ,  0)).to be true
      expect(quad.contains?(25,  0)).to be true
    end

    it "returns false if point is outside the quad" do
      expect(quad.contains?(-26,  0)).to be false
      expect(quad.contains?(  0, 26)).to be false
    end
  end

end
