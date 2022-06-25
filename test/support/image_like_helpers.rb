require 'ruby2d'
require 'pathname'

# Image and Sprite are very similar. This helper defines  tests
# so that specs for objects that are "image like" can share tests.
#
# Requires calling spec to
# - define +subject+
# - define +let(:path)+ with default of valid image file
# - define +let(:not_found_path)+ with default of non-existent image file
# - define +let(:atlas)+ with default as nil
#
# Defined following sets of shared examples
# - +image-like tests+(klass)
# - +image-like attributes+

def test_media(file_name)
  "#{Ruby2D.test_media}/#{file_name}"
end

#
# This example is used internally, though you could use it elsewhere if needed
shared_examples 'image format' do |format_ext|
  context "loading #{format_ext}" do
    let(:path) { test_media "image.#{format_ext}" }
    it 'succeeds' do
      expect(subject.path).to end_with ".#{format_ext}"
    end
  end
end

#
# ==Image-loading Tests==
# Here we have a set of tests that are common to Pixmap, Image and
# Sprite. When writing a spec for those classes (and others that have
# the same common properties), pull it in as follows:
#
# ```
# include_examples 'image-loading tests'
# ```
#
# Ensure your spec has a +subject+ that instantiates the class (e.g. +Sprite+ above)
# and defines +let(:path)+ with a default image file and +let(:not_found_path)+ with
# a path to a non-existent file
#
shared_examples 'image-loading tests' do
  include_examples 'image format', 'bmp'
  include_examples 'image format', 'jpg'
  include_examples 'image format', 'png'

  context 'loading non-existent file' do
    let(:path) { not_found_path }
    it 'fails' do
      expect { subject }.to raise_error(Ruby2D::Error)
    end
  end

  context 'using pathname' do
    let(:path) { Pathname.new(test_media('image.png')) }
    it 'converts path to string' do
      expect(subject.path.is_a?(String)).to be true
    end

    it 'succeeds' do
      expect(subject.path).to end_with test_media('image.png')
    end
  end
end

#
# ==Image-like Tests==
# Here we have a set of tests that are common to Image and
# Sprite. When writing a spec for those classes (and others that have
# the same common properties), pull it in as in following example for +Sprite+:
#
# ```
# include_examples 'image-like tests', Sprite
# ```
#
# Ensure your spec has a +subject+ that instantiates the class (e.g. +Sprite+ above)
# and defines +let(:path)+ with a default image file and +let(:not_found_path)+ with
# a path to a non-existent file
#
shared_examples 'image-like tests' do |klass|
  it "creates #{klass.name} with valid color" do
    expect(subject.color).to be_a Ruby2D::Color
  end

  it "creates #{klass.name} with white filter by default" do
    expect(subject.color.to_a).to eq [1, 1, 1, 1]
  end

  context 'with options' do
    subject do
      klass.new path, atlas: atlas,
                      x: 10, y: 20, z: 30,
                      width: 40, height: 50, rotate: 60,
                      color: 'gray', opacity: 0.5
    end
    it 'succeeds' do
      expect(subject.path).to eq(path)
      expect(subject.x).to eq(10)
      expect(subject.y).to eq(20)
      expect(subject.z).to eq(30)
      expect(subject.width).to eq(40)
      expect(subject.height).to eq(50)
      expect(subject.rotate).to eq(60)
      expect(subject.color.r).to eq(2 / 3.0)
      expect(subject.color.opacity).to eq(0.5)
    end
  end
end

#
# ==Image-like Attributes==
# Here we have a set of attribute tests that are common to Image and
# Sprite. This defines a +describe+ for testing all the common
# attribute setter/getters, so you can pull it in for e.g. as follows:
#
# ```
# include_examples 'image-like attributes', Sprite
# ```
#
# Ensure your spec has a +subject+ that instantiates the class (e.g. +Sprite+ above).
#
shared_examples 'image-like attributes' do
  describe 'attributes' do
    it 'can be set and read' do
      subject.x = 10
      subject.y = 20
      subject.z = 30
      subject.width = 40
      subject.height = 50
      subject.rotate = 60
      subject.color = 'gray'
      subject.color.opacity = 0.5

      expect(subject.x).to eq(10)
      expect(subject.y).to eq(20)
      expect(subject.z).to eq(30)
      expect(subject.width).to eq(40)
      expect(subject.height).to eq(50)
      expect(subject.rotate).to eq(60)
      expect(subject.color.r).to eq(2 / 3.0)
      expect(subject.color.opacity).to eq(0.5)
    end
  end
end
