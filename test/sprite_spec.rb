require 'ruby2d'

RSpec.describe Ruby2D::Sprite do

  describe "#new" do
    it "raises exception if file doesn't exist" do
      expect { Sprite.new('bad_sprite_sheet.png') }.to raise_error(Ruby2D::Error)
    end

    it "creates a sprite with a white filter by default" do
      spr = Sprite.new("#{Ruby2D.test_media}/coin.png")
      expect(spr.color).to be_a(Ruby2D::Color)
      expect(spr.color.r).to eq(1)
      expect(spr.color.g).to eq(1)
      expect(spr.color.b).to eq(1)
      expect(spr.color.a).to eq(1)
    end

    it "creates an image with options" do
      spr = Sprite.new(
        "#{Ruby2D.test_media}/coin.png",
        x: 10, y: 20, z: 30,
        width: 40, height: 50, rotate: 60,
        color: 'gray', opacity: 0.5
      )

      expect(spr.path).to eq("#{Ruby2D.test_media}/coin.png")
      expect(spr.x).to eq(10)
      expect(spr.y).to eq(20)
      expect(spr.z).to eq(30)
      expect(spr.width).to eq(40)
      expect(spr.height).to eq(50)
      expect(spr.rotate).to eq(60)
      expect(spr.color.r).to eq(2/3.0)
      expect(spr.color.opacity).to eq(0.5)
    end
  end

  describe "attributes" do
    it "can be set and read" do
      spr = Sprite.new("#{Ruby2D.test_media}/coin.png")
      spr.x = 10
      spr.y = 20
      spr.z = 30
      spr.width = 40
      spr.height = 50
      spr.rotate = 60
      spr.color = 'gray'
      spr.color.opacity = 0.5

      expect(spr.x).to eq(10)
      expect(spr.y).to eq(20)
      expect(spr.z).to eq(30)
      expect(spr.width).to eq(40)
      expect(spr.height).to eq(50)
      expect(spr.rotate).to eq(60)
      expect(spr.color.r).to eq(2/3.0)
      expect(spr.color.opacity).to eq(0.5)
    end
  end

end
