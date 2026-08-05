RSpec.describe Ruby2D::SpriteSheet do
  let(:atlas_path) { "#{Ruby2D.test_spritesheets}/spritesheet.xml" }

  describe '#new' do
    it 'loads a Sparrow XML atlas and resolves the image path relative to it' do
      sheet = described_class.new(atlas_path)
      expect(sheet.path).to eq(atlas_path)
      expect(sheet.image_path).to end_with('spritesheet.png')
      expect(File.exist?(sheet.image_path)).to be true
      expect(sheet.texture).to be_a(Ruby2D::Image)
    end

    it 'raises if the atlas file is missing' do
      expect { described_class.new('does_not_exist.xml') }
        .to raise_error(Ruby2D::Error)
    end
  end

  describe '#frame and #frame?' do
    let(:sheet) { SharedSpriteSheet.instance }

    it 'looks up frames by name' do
      expect(sheet.frame('block_blue')).to eq(x: 0, y: 0, width: 128, height: 128)
      expect(sheet['block_blue']).to eq(sheet.frame('block_blue'))
    end

    it 'returns nil for unknown frames' do
      expect(sheet.frame('not_a_frame')).to be_nil
    end

    it 'reports frame existence' do
      expect(sheet.frame?('block_blue')).to be true
      expect(sheet.frame?('not_a_frame')).to be false
    end
  end

  describe '#frame_names' do
    it 'returns frame names in declaration order' do
      sheet = described_class.new(atlas_path)
      names = sheet.frame_names
      expect(names).to include('block_blue')
      expect(names.size).to be > 1
    end
  end

  describe 'TextureAtlas alias' do
    it 'is the same class as SpriteSheet' do
      expect(Ruby2D::TextureAtlas).to be(Ruby2D::SpriteSheet)
    end
  end

  # Pure path-resolution logic — no texture, window, or SDL.
  describe '#resolve_image_path' do
    require 'tmpdir'

    # resolve_image_path uses no instance state, so allocate without #initialize
    let(:resolver) { described_class.allocate }

    it 'prefers the texture beside the atlas over a like-named file in the working directory' do
      Dir.mktmpdir do |atlas_dir|
        Dir.mktmpdir do |cwd|
          real  = File.join(atlas_dir, 'sheet.png')
          decoy = File.join(cwd, 'sheet.png')
          File.write(real, 'real')
          File.write(decoy, 'decoy')
          atlas_path = File.join(atlas_dir, 'atlas.xml')

          resolved = Dir.chdir(cwd) do
            resolver.send(:resolve_image_path, atlas_path, 'sheet.png')
          end
          expect(File.expand_path(resolved)).to eq(File.expand_path(real))
        end
      end
    end

    it 'falls back to the given path when no atlas-relative file exists' do
      Dir.mktmpdir do |dir|
        elsewhere = File.join(dir, 'elsewhere.png')
        File.write(elsewhere, 'x')
        # Atlas dir holds no 'elsewhere.png', so the absolute path is used as-is
        atlas_path = File.join(dir, 'sub', 'atlas.xml')

        resolved = resolver.send(:resolve_image_path, atlas_path, elsewhere)
        expect(resolved).to eq(elsewhere)
      end
    end
  end
end
