require 'ruby2d'

RSpec.describe Ruby2D::Triangle do
  describe '#new' do
    it "creates a triangle with white color by default" do
      triangle = Triangle.new(
        320,  50,
        540, 430,
        100, 430
      )
      expect(triangle.color).to   be_a(Ruby2D::Color)
      expect(triangle.color.r).to eq(1)
      expect(triangle.color.g).to eq(1)
      expect(triangle.color.b).to eq(1)
      expect(triangle.color.a).to eq(1)
    end

    it 'creates a new triangle with one color via string' do
      triangle = Triangle.new(
        320,  50,
        540, 430,
        100, 430,
        "black"
      )

      expect(triangle.color).to be_a(Ruby2D::Color)
    end

    it "creates a new triangle with one color via array of numbers" do
      triangle = Triangle.new(
        320,  50,
        540, 430,
        100, 430,
        [0.1, 0.3, 0.5, 0.7]
      )

      expect(triangle.color).to be_a(Ruby2D::Color)
    end

    it "creates a new triangle with 3 colors via array of 3 strings" do
      triangle = Triangle.new(
        320,  50,
        540, 430,
        100, 430,
        ["red", "green", "blue"]
      )
      expect(triangle.color).to be_a(Ruby2D::Color::Set)
    end

    it "creates a new triangle with 3 colors via array of 3 arrays of arrays of numbers" do
      triangle = Triangle.new(
        320,  50,
        540, 430,
        100, 430,
        [[0.1, 0.3, 0.5, 0.7], [0.2, 0.4, 0.6, 0.8], [0.3, 0.5, 0.7, 0.9]]
      )
      expect(triangle.color).to be_a(Ruby2D::Color::Set)
    end

    it "throws an error when array of 2 strings is passed" do
      expect do
        Triangle.new(
          320,  50,
          540, 430,
          100, 430,
          ["red", "green"]
        )
      end.to raise_error("Triangles require 3 colors, one for each vertex. 2 were given.")
    end

    it "throws an error when array of 4 strings is passed" do
      expect do
        Triangle.new(
          320,  50,
          540, 430,
          100, 430,
          ["red", "green", "blue", "fuchsia"]
        )
      end.to raise_error("Triangles require 3 colors, one for each vertex. 4 were given.")
    end
  end
end
