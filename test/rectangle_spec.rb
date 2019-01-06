require 'ruby2d'

RSpec.describe Ruby2D::Rectangle do

  describe "#new" do
    it "creates a white rectangle by default" do
      rectangle = Rectangle.new
      expect(rectangle.color).to be_a(Ruby2D::Color)
      expect(rectangle.color.r).to eq(1)
      expect(rectangle.color.g).to eq(1)
      expect(rectangle.color.b).to eq(1)
      expect(rectangle.color.a).to eq(1)
    end

    it "creates a rectangle with options" do
      rectangle = Rectangle.new(
        x: 10, y: 20, z: 30,
        width: 40, height: 50,
        color: 'gray', opacity: 0.5
      )

      expect(rectangle.x).to eq(10)
      expect(rectangle.y).to eq(20)
      expect(rectangle.z).to eq(30)
      expect(rectangle.width).to eq(40)
      expect(rectangle.height).to eq(50)
      expect(rectangle.color.r).to eq(2/3.0)
      expect(rectangle.opacity).to eq(0.5)
    end

    it "creates a new rectangle with one color via string" do
      rectangle = Rectangle.new(color: 'red')
      expect(rectangle.color).to be_a(Ruby2D::Color)
    end

    it "creates a new rectangle with one color via array of numbers" do
      rectangle = Rectangle.new(color: [0.1, 0.3, 0.5, 0.7])
      expect(rectangle.color).to be_a(Ruby2D::Color)
    end

    it "creates a new rectangle with 4 colors via array of 4 strings" do
      rectangle = Rectangle.new(color: ['red', 'green', 'blue', 'black'])
      expect(rectangle.color).to be_a(Ruby2D::Color::Set)
    end

    it "creates a new rectangle with 4 colors via array of 4 arrays of arrays of numbers" do
      rectangle = Rectangle.new(
        color: [
          [0.1, 0.3, 0.5, 0.7],
          [0.2, 0.4, 0.6, 0.8],
          [0.3, 0.5, 0.7, 0.9],
          [0.4, 0.6, 0.8, 1.0]
        ]
      )
      expect(rectangle.color).to be_a(Ruby2D::Color::Set)
    end

    it "throws an error when array of 3 strings is passed" do
      expect do
        Rectangle.new(color: ['red', 'green', 'blue'])
      end.to raise_error("`Ruby2D::Rectangle` requires 4 colors, one for each vertex. 3 were given.")
    end

    it "throws an error when array of 5 strings is passed" do
      expect do
        Rectangle.new(color: ['red', 'green', 'blue', 'black', 'fuchsia'])
      end.to raise_error("`Ruby2D::Rectangle` requires 4 colors, one for each vertex. 5 were given.")
    end
  end

  describe "attributes" do
    it "can be set and read" do
      rectangle = Rectangle.new
      rectangle.x = 10
      rectangle.y = 20
      rectangle.z = 30
      rectangle.width = 40
      rectangle.height = 50
      rectangle.color = 'gray'
      rectangle.opacity = 0.5

      expect(rectangle.x).to eq(10)
      expect(rectangle.y).to eq(20)
      expect(rectangle.z).to eq(30)
      expect(rectangle.width).to eq(40)
      expect(rectangle.height).to eq(50)
      expect(rectangle.color.r).to eq(2/3.0)
      expect(rectangle.opacity).to eq(0.5)
    end
  end

end
