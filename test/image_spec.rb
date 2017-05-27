require 'ruby2d'

RSpec.describe Ruby2D::Image do
  describe '#new' do
    it "raises exception if image file doesn't exist" do
      expect { Image.new(path: 'bad_image.png') }.to raise_error(Ruby2D::Error)
    end
  end

  # Image has 100 width and 100 height
  describe '#contains?' do
    it "returns true if point is inside image" do
      image = Image.new(path: "test/media/image.bmp")
      expect(image.contains?(50, 50)).to be true
    end

    it "returns true if point is not inside image" do
      image = Image.new(path: "test/media/image.bmp")
      expect(image.contains?(-50, 50)).to be false
      expect(image.contains?(50, -50)).to be false
      expect(image.contains?(50, 150)).to be false
      expect(image.contains?(150, 50)).to be false
    end
  end
end
