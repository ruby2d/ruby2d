require 'ruby2d'

RSpec.describe Ruby2D::Quad do
  describe '#new' do
    it "creates a quad with white color by default" do
      quad = Quad.new(
        300, 200,
        350, 200,
        300, 250,
        250, 250
      )

      expect(quad.color).to   be_a(Ruby2D::Color)
      expect(quad.color.r).to eq(1)
      expect(quad.color.g).to eq(1)
      expect(quad.color.b).to eq(1)
      expect(quad.color.a).to eq(1)
    end

    it 'creates a new quad with one color via string' do
      quad = Quad.new(
        300, 200,
        350, 200,
        300, 250,
        250, 250,
        "red"
      )

      expect(quad.color).to be_a(Ruby2D::Color)
    end

    it "creates a new triangle with one color via array of numbers" do
      quad = Quad.new(
        300, 200,
        350, 200,
        300, 250,
        250, 250,
        [0.1, 0.3, 0.5, 0.7]
      )

      expect(quad.color).to be_a(Ruby2D::Color)
    end

    it "creates a new quad with 4 colors via array of 4 strings" do
      quad = Quad.new(
        300, 200,
        350, 200,
        300, 250,
        250, 250,
        ["red", "green", "blue", "black"]
      )

      expect(quad.color).to be_a(Ruby2D::Color::Set)
    end

    it "creates a new quad with 4 colors via array of 4 arrays of arrays of numbers" do
      quad = Quad.new(
        300, 200,
        350, 200,
        300, 250,
        250, 250,
        [[0.1, 0.3, 0.5, 0.7], [0.2, 0.4, 0.6, 0.8], [0.3, 0.5, 0.7, 0.9], [0.4, 0.6, 0.8, 1.0]]
      )

      expect(quad.color).to be_a(Ruby2D::Color::Set)
    end

    it "throws an error when array of 3 strings is passed" do
      expect do
        Quad.new(
          300, 200,
          350, 200,
          300, 250,
          250, 250,
          ["red", "green", "blue"]
        )
      end.to raise_error("Quads require 4 colors, one for each vertex. 3 were given.")
    end

    it "throws an error when array of 5 strings is passed" do
      expect do
        Quad.new(
          300, 200,
          350, 200,
          300, 250,
          250, 250,
          ["red", "green", "blue", "black", "fuchsia"]
        )
      end.to raise_error("Quads require 4 colors, one for each vertex. 5 were given.")
    end
  end
end
