require 'ruby2d'

RSpec.describe Ruby2D::Image do

  describe '#new' do
    it "raises exception if image file doesn't exist" do
      expect { Image.new(0, 0, 'bad_image.png') }.to raise_error(Ruby2D::Error)
    end
  end

end
