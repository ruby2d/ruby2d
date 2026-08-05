RSpec.describe Ruby2D::Image do
  subject { Image.new path }
  let(:path) { test_image 'colors.png' }
  let(:not_found_path) { test_image 'bad_image.png' }

  describe '#new' do
    include_examples 'image-loading tests'
    include_examples 'image-like tests', Image
  end

  include_examples 'image-like attributes', Image
end
