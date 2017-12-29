require 'ruby2d'

RSpec.describe Ruby2D::Sprite do

  describe '#new' do
    it "raises exception if file doesn't exist" do
      expect { Sprite.new(0, 0, "bad_sprite_sheet.png") }.to raise_error(Ruby2D::Error)
    end

    it 'creates a new sprite' do
      Sprite.new(0, 0, "test/media/sprite_sheet.png")
    end
  end

end
