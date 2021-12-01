require 'ruby2d'

RSpec.describe Ruby2D::Image do

  describe "#new" do
    it "creates images in various formats" do
      Image.new("#{Ruby2D.test_media}/image.bmp")
      Image.new("#{Ruby2D.test_media}/image.jpg")
      Image.new("#{Ruby2D.test_media}/image.png")
    end

    it "raises exception if image file doesn't exist" do
      expect { Image.new('bad_image.png') }.to raise_error(Ruby2D::Error)
    end

    it "creates an image with a white filter by default" do
      img = Image.new("#{Ruby2D.test_media}/colors.png")
      expect(img.color).to be_a(Ruby2D::Color)
      expect(img.color.r).to eq(1)
      expect(img.color.g).to eq(1)
      expect(img.color.b).to eq(1)
      expect(img.color.a).to eq(1)
    end

    it "creates an image with options" do
      img = Image.new(
        "#{Ruby2D.test_media}/colors.png",
        x: 10, y: 20, z: 30,
        width: 40, height: 50, rotate: 60,
        color: 'gray', opacity: 0.5
      )

      expect(img.path).to eq("#{Ruby2D.test_media}/colors.png")
      expect(img.x).to eq(10)
      expect(img.y).to eq(20)
      expect(img.z).to eq(30)
      expect(img.width).to eq(40)
      expect(img.height).to eq(50)
      expect(img.rotate).to eq(60)
      expect(img.color.r).to eq(2/3.0)
      expect(img.color.opacity).to eq(0.5)
    end
  end

  describe "attributes" do
    it "can be set and read" do
      img = Image.new("#{Ruby2D.test_media}/colors.png")
      img.x = 10
      img.y = 20
      img.z = 30
      img.width = 40
      img.height = 50
      img.rotate = 60
      img.color = 'gray'
      img.color.opacity = 0.5

      expect(img.x).to eq(10)
      expect(img.y).to eq(20)
      expect(img.z).to eq(30)
      expect(img.width).to eq(40)
      expect(img.height).to eq(50)
      expect(img.rotate).to eq(60)
      expect(img.color.r).to eq(2/3.0)
      expect(img.color.opacity).to eq(0.5)
    end
  end

end
