require 'ruby2d'

RSpec.describe Ruby2D::Image do

  describe "#new" do
    it "raises exception if image file doesn't exist" do
      expect { Image.new("bad_image.png") }.to raise_error(Ruby2D::Error)
    end
  end

  describe "#contains?" do
    it "returns true if point is inside the image" do
      image = Image.new("test/media/image.bmp")
      expect(image.contains?(50, 50)).to be true
    end

    it "returns true if point is outside the image" do
      image = Image.new("test/media/image.bmp")
      expect(image.contains?(-50, 50)).to be false
      expect(image.contains?(50, -50)).to be false
      expect(image.contains?(50, 150)).to be false
      expect(image.contains?(150, 50)).to be false
    end
  end

end
