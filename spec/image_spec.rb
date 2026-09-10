require 'fileutils'
require 'tmpdir'

RSpec.describe Ruby2D::Image do
  subject { Image.new path }
  let(:path) { test_image 'colors.png' }
  let(:not_found_path) { test_image 'bad_image.png' }

  describe '#new' do
    include_examples 'image-loading tests'
    include_examples 'image-like tests', Image
  end

  include_examples 'image-like attributes', Image

  describe 'dup and clone' do
    [:dup, :clone].each do |method|
      it "gives a #{method} its own pixels, tint, and handlers" do
        original = Image.new(path, add: false)
        copy = original.public_send(method)
        expect(copy.instance_variable_get(:@ext_image))
          .not_to equal(original.instance_variable_get(:@ext_image))

        copy.resize!(4, 4)
        expect(copy.width).to eq(4)
        expect(original.width).to eq(Image.new(path, add: false).width)

        copy.opacity = 0.25
        expect(original.opacity).to eq(1)

        copy.on(:mouse_down) {}
        expect(copy.interactive?).to be true
        expect(original.interactive?).to be false
      end
    end
  end

  describe '#path' do
    let(:relative) { Pathname.new(path).relative_path_from(Pathname.pwd).to_s }

    it 'is the absolute path of a relative one' do
      expect(Image.new(relative).path).to eq(File.expand_path(relative))
    end

    it 'rejects an empty path instead of expanding it to the working directory' do
      expect { Image.new('') }.to raise_error(Ruby2D::Error, /not found/)
      expect { Image.new(nil) }.to raise_error(Ruby2D::Error, /not found/)
    end

    it 'still expands a home-relative path' do
      expect { Image.new('~/ruby2d-no-such-image.png') }
        .to raise_error(Ruby2D::Error, /#{Regexp.escape(File.join(Dir.home, 'ruby2d-no-such-image.png'))}/)
    end

    it 'treats a tilde path naming no user as a relative path' do
      expect { Image.new('~ruby2d-no-such-user/x.png') }
        .to raise_error(Ruby2D::Error, /#{Regexp.escape(File.join(Dir.pwd, '~ruby2d-no-such-user/x.png'))}/)
    end

    it 'loads a file whose name starts with a tilde' do
      Dir.mktmpdir do |dir|
        FileUtils.cp(path, File.join(dir, '~colors.png'))
        Dir.chdir(dir) do
          expect(Image.new('~colors.png').path).to eq(File.join(Dir.pwd, '~colors.png'))
        end
      end
    end

    it 'lets resize! re-read the file after the working directory changes' do
      image = Image.new(relative)
      Dir.mktmpdir do |dir|
        Dir.chdir(dir) { expect { image.resize!(4, 4) }.not_to raise_error }
      end
      expect(image.width).to eq(4)
    end
  end
end
