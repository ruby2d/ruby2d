require 'ruby2d'

require_relative 'support/image_like_helpers'

RSpec.describe Ruby2D::Image do
  subject { Image.new path, atlas: atlas }
  let(:atlas) { nil }
  let(:path) { test_media 'colors.png' }
  let(:not_found_path) { test_media 'bad_image.png' }

  describe '#new' do
    context 'without atlas' do
      include_examples 'image-loading tests'
      include_examples 'image-like tests', Image
    end

    context 'with atlas' do
      let(:atlas) { PixmapAtlas.new }

      include_examples 'image-loading tests'
      include_examples 'image-like tests', Image
    end
  end

  include_examples 'image-like attributes', Image
end
