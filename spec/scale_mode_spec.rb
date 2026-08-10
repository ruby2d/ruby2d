RSpec.describe 'scale_mode' do
  let(:tileset_path) { "#{Ruby2D.test_spritesheets}/texture_atlas.png" }
  let(:sheet_path) { "#{Ruby2D.test_spritesheets}/spritesheet.xml" }

  describe Ruby2D::TextureScaling do
    it 'recognizes linear, nearest, and pixel_art' do
      expect(Ruby2D::TextureScaling::SCALE_MODES).to eq(%i[linear nearest pixel_art])
    end

    it 'treats nil as inherit' do
      expect(Ruby2D::TextureScaling.validate(nil)).to be_nil
    end

    it 'rejects an unrecognized mode' do
      expect { Ruby2D::TextureScaling.validate(:pixel) }
        .to raise_error(Ruby2D::Error, /Invalid scale_mode :pixel/)
    end

    it 'rejects a string spelling of a valid mode' do
      expect { Ruby2D::TextureScaling.validate('nearest') }
        .to raise_error(Ruby2D::Error)
    end
  end

  describe Ruby2D::Window do
    it 'defaults to linear' do
      expect(Window.new.scale_mode).to eq(:linear)
    end

    it 'is set via `set scale_mode:`' do
      window = Window.new
      window.set scale_mode: :pixel_art
      expect(window.scale_mode).to eq(:pixel_art)
    end

    it 'raises on an unrecognized mode' do
      expect { Window.new.set(scale_mode: :crisp) }
        .to raise_error(Ruby2D::Error, /Invalid scale_mode :crisp/)
    end
  end

  # Every class backed by a GPU texture takes the same kwarg. nil means the
  # object follows the window, which is resolved per draw in C.
  {
    'Image' => -> (mode) { Image.new(test_image('image.png'), scale_mode: mode) },
    'Sprite' => -> (mode) { Sprite.new(test_image('image.png'), scale_mode: mode) },
    'Canvas' => -> (mode) { Canvas.new(width: 16, height: 16, scale_mode: mode) },
    'Text' => -> (mode) { Text.new('hi', scale_mode: mode) },
    'BitmapText' => -> (mode) { BitmapText.new('hi', scale_mode: mode) }
  }.each do |name, build|
    context name do
      it 'defaults to nil (follows the window)' do
        expect(build.call(nil).scale_mode).to be_nil
      end

      it 'accepts a mode and reports it' do
        expect(build.call(:nearest).scale_mode).to eq(:nearest)
      end

      it 'accepts a mode after construction' do
        obj = build.call(nil)
        obj.scale_mode = :pixel_art
        expect(obj.scale_mode).to eq(:pixel_art)
      end

      it 'raises on an unrecognized mode' do
        expect { build.call(:bilinear) }.to raise_error(Ruby2D::Error)
      end
    end
  end

  describe Ruby2D::Tileset do
    it 'defaults to nil' do
      expect(Tileset.new(tileset_path).scale_mode).to be_nil
    end

    # The draw goes through the backing Image, so that's where the value has
    # to live — mirroring it on the Tileset would let the two drift.
    it 'stores the mode on the backing image' do
      ts = Tileset.new(tileset_path, scale_mode: :nearest)
      expect(ts.instance_variable_get(:@texture).scale_mode).to eq(:nearest)
    end

    it 'writes through to the backing image' do
      ts = Tileset.new(tileset_path)
      ts.scale_mode = :pixel_art
      expect(ts.instance_variable_get(:@texture).scale_mode).to eq(:pixel_art)
    end

    it 'raises on an unrecognized mode' do
      expect { Tileset.new(tileset_path, scale_mode: :sharp) }.to raise_error(Ruby2D::Error)
    end
  end

  describe Ruby2D::SpriteSheet do
    it 'defaults to nil' do
      expect(SpriteSheet.new(sheet_path).scale_mode).to be_nil
    end

    it 'passes its mode to sprites built from it' do
      sheet = SpriteSheet.new(sheet_path, scale_mode: :nearest)
      expect(sheet.scale_mode).to eq(:nearest)
      expect(Sprite.new(sheet).scale_mode).to eq(:nearest)
    end

    # The texture is shared but the mode is re-applied per draw, so one sprite
    # can differ from the sheet without disturbing its siblings.
    it 'lets a sprite override it' do
      sheet = SpriteSheet.new(sheet_path, scale_mode: :nearest)
      expect(Sprite.new(sheet, scale_mode: :linear).scale_mode).to eq(:linear)
      expect(Sprite.new(sheet).scale_mode).to eq(:nearest)
    end
  end
end
