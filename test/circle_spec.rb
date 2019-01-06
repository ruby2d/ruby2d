require 'ruby2d'

RSpec.describe Ruby2D::Circle do

  describe "#new" do
    it "creates a white circle by default" do
      circle = Circle.new
      expect(circle.color).to be_a(Ruby2D::Color)
      expect(circle.color.r).to eq(1)
      expect(circle.color.g).to eq(1)
      expect(circle.color.b).to eq(1)
      expect(circle.color.a).to eq(1)
    end

    it "creates a circle with options" do
      circle = Circle.new(
        x: 10, y: 20, z: 30,
        radius: 40, sectors: 50,
        color: 'gray', opacity: 0.5
      )

      expect(circle.x).to eq(10)
      expect(circle.y).to eq(20)
      expect(circle.z).to eq(30)
      expect(circle.radius).to eq(40)
      expect(circle.sectors).to eq(50)
      expect(circle.color.r).to eq(2/3.0)
      expect(circle.opacity).to eq(0.5)
    end
  end

  describe "attributes" do
    it "can be set and read" do
      circle = Circle.new
      circle.x = 10
      circle.y = 20
      circle.z = 30
      circle.radius = 40
      circle.sectors = 50
      circle.color = 'gray'
      circle.opacity = 0.5

      expect(circle.x).to eq(10)
      expect(circle.y).to eq(20)
      expect(circle.z).to eq(30)
      expect(circle.radius).to eq(40)
      expect(circle.sectors).to eq(50)
      expect(circle.color.r).to eq(2/3.0)
      expect(circle.opacity).to eq(0.5)
    end
  end

end
