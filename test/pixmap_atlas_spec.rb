require 'ruby2d'

RSpec.describe Ruby2D::PixmapAtlas do
  subject { PixmapAtlas.new }
  let(:image_colors) { test_media 'colors.png' }
  let(:image_coin) { test_media 'coin.png' }
  let(:image_tileset) { test_media 'texture_atlas.png' }

  shared_examples 'load one image many times' do |count|
    context "loading same image #{count} times" do
      before do
        count.times do
          subject.load_and_keep_image image_colors
        end
      end

      it 'actually loads one' do
        expect(subject.count).to eq 1
      end

      it 'doesn\'t load it more than once' do
        expect(subject.count).not_to be > 1
      end
    end
  end

  shared_examples 'load two images many times' do |count|
    context "loading two images #{count} times" do
      before do
        count.times do
          subject.load_and_keep_image image_colors
          subject.load_and_keep_image image_coin
        end
      end

      it 'actually loads two' do
        expect(subject.count).to eq 2
      end

      it 'actually loads first image' do
        expect(subject[image_colors].path).to eq image_colors
      end

      it 'actually loads second image_coin' do
        expect(subject[image_coin].path).to eq image_coin
      end

      it 'doesn\'t load more than two' do
        expect(subject.count).not_to be > 2
      end
    end
  end

  describe '#load_and_keep_image' do
    include_examples 'load one image many times', 2
    include_examples 'load one image many times', 32
    include_examples 'load one image many times', 128

    include_examples 'load two images many times', 2
    include_examples 'load two images many times', 32
    include_examples 'load two images many times', 128
  end

  shared_examples 'create image/sprite many times' do |klass, count:|
    context "creating #{count} with same image file" do
      let(:collection) { [] }
      before do
        count.times do
          collection << klass.new(image_path, atlas: subject)
        end
      end

      it 'succeeds' do
        expect(collection.count).to eq count
      end

      it 'loads image once' do
        expect(subject.count).to eq 1
      end
    end
  end

  describe 'with Image' do
    let(:image_path) { image_colors }
    include_examples 'create image/sprite many times', Image, count: 133
  end

  describe 'with Sprite' do
    let(:image_path) { image_coin }
    include_examples 'create image/sprite many times', Sprite, count: 67
  end

  describe 'with Tileset' do
    let(:image_path) { image_tileset }
    include_examples 'create image/sprite many times', Tileset, count: 31
  end
end
