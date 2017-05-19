require 'ruby2d'

RSpec.describe Ruby2D::Sprite do

  describe '#new' do
    it 'creates a new sprite' do
      Ruby2D::Sprite.new(0, 0, "tests/media/sprite_sheet.png")
    end
  end

end
