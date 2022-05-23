require 'ruby2d'

require_relative 'support/image_like_helpers'

RSpec.describe Ruby2D::Sprite do
  subject { Sprite.new path, atlas: atlas }
  let(:atlas) { nil }
  let(:path) { test_media 'coin.png' }
  let(:not_found_path) { test_media 'bad_sprite_sheet.png' }

  describe '#new' do
    context 'without atlas' do
      include_examples 'image-loading tests'
      include_examples 'image-like tests', Sprite
    end

    context 'with atlas' do
      let(:atlas) { PixmapAtlas.new }

      include_examples 'image-loading tests'
      include_examples 'image-like tests', Sprite
    end
  end

  include_examples 'image-like attributes', Sprite
end
