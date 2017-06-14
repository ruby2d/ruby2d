require 'ruby2d'

RSpec.describe Ruby2D::Sprite do

  describe '#new' do
    it 'creates a new sprite without set proportions' do
      Ruby2D::Sprite.new(0, 0, "tests/media/sprite_sheet.png")
    end

    it 'creates a new sprite with set proportions' do
    	Ruby2D::Sprite.new(0, 0, "tests/media/sprite_sheet.png", 0, 100, 100)
    end
  end

end
