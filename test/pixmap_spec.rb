require 'ruby2d'

require_relative 'support/image_like_helpers'

RSpec.describe Ruby2D::Pixmap do
  subject { Pixmap.new path }
  let(:path) { test_media 'colors.png' }
  let(:not_found_path) { test_media 'bad_image.png' }

  describe '#new' do
    include_examples 'image-loading tests'
  end
end
