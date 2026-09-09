RSpec.describe Ruby2D::Tileset do
  let(:atlas_path) { "#{Ruby2D.test_spritesheets}/texture_atlas.png" }

  describe '#new' do
    it 'loads a tileset from an image path' do
      expect { Tileset.new(atlas_path, tile_width: 32, tile_height: 32) }
        .not_to raise_error
    end

    it 'raises if the image file does not exist' do
      expect { Tileset.new("#{Ruby2D.test_spritesheets}/no_such_atlas.png") }
        .to raise_error(Ruby2D::Error)
    end

    it 'defaults tint to white' do
      ts = Tileset.new(atlas_path)
      expect(ts.tint).to be_a(Ruby2D::Color)
      expect(ts.tint.to_a).to eq([1.0, 1.0, 1.0, 1.0])
    end

    it 'accepts a tint via the tint= setter' do
      ts = Tileset.new(atlas_path, tile_width: 32, tile_height: 32)
      ts.tint = [0.5, 0.25, 0.75, 0.5]
      expect(ts.tint.r).to eq(0.5)
      expect(ts.tint.g).to eq(0.25)
      expect(ts.tint.b).to eq(0.75)
      expect(ts.tint.a).to eq(0.5)
    end

    it 'does not respond to color (uses tint)' do
      ts = Tileset.new(atlas_path)
      expect { ts.color }.to raise_error(NoMethodError)
      expect { ts.color = 'red' }.to raise_error(NoMethodError)
    end

    it 'raises if scale is not positive' do
      expect { Tileset.new(atlas_path, scale: 0) }.to raise_error(ArgumentError)
    end

    # Unlike every other Renderable, a Tileset has no whole-object rotation — a
    # grid of tiles has no single pivot. Tiles rotate individually, per tile
    # type, through `define(..., rotate:)`.
    it 'has no whole-object rotation (tiles rotate per type via define)' do
      ts = Tileset.new(atlas_path, add: false)
      expect { ts.rotate }.to raise_error(NoMethodError)
      expect { ts.rotate = 90 }.to raise_error(NoMethodError)
    end

    it 'rotates a tile type through define(rotate:)' do
      ts = Tileset.new(atlas_path, tile_width: 32, tile_height: 32, add: false)
      expect { ts.define(:wall, 0, 0, rotate: 90) }.not_to raise_error
    end

    it 'reads and sets opacity through the tint' do
      ts = Tileset.new(atlas_path, add: false)
      expect(ts.opacity).to eq(1.0)
      ts.opacity = 0.5
      expect(ts.opacity).to eq(0.5)
      expect(ts.tint.opacity).to eq(0.5)
      ts.tint = '#ff0000'
      ts.opacity = 0.25
      expect(ts.tint.to_a).to eq([1.0, 0.0, 0.0, 0.25])
    end

    it 'applies a construction-time opacity to the tint' do
      ts = Tileset.new(atlas_path, opacity: 0.5, add: false)
      expect(ts.opacity).to eq(0.5)
      expect(ts.tint.to_a).to eq([1.0, 1.0, 1.0, 0.5])
    end

    it 'gives each default-tinted tileset an independent tint' do
      a = Tileset.new(atlas_path)
      b = Tileset.new(atlas_path)
      a.tint.opacity = 0.25
      expect(a.tint.opacity).to eq(0.25)
      expect(b.tint.opacity).to eq(1.0)
    end
  end

  describe 'placement API' do
    let(:tileset) do
      ts = Tileset.new(atlas_path, tile_width: 32, tile_height: 32, add: false)
      ts.define('a', 0, 0)
      ts.define('b', 1, 0)
      ts
    end

    it 'places a tile via []= and looks it up via []' do
      tileset[10, 20] = 'a'
      expect(tileset[10, 20]).to eq('a')
    end

    it 'returns nil for unplaced coordinates' do
      expect(tileset[0, 0]).to be_nil
    end

    it 'replaces an existing placement at the same coordinate' do
      tileset[10, 20] = 'a'
      tileset[10, 20] = 'b'
      expect(tileset[10, 20]).to eq('b')
    end

    it 'places many tiles via #place' do
      tileset.place('a', [[0, 0], [32, 0], [64, 0]])
      expect(tileset[0, 0]).to eq('a')
      expect(tileset[32, 0]).to eq('a')
      expect(tileset[64, 0]).to eq('a')
    end

    it 'removes a placement via #delete' do
      tileset[10, 20] = 'a'
      tileset.delete(10, 20)
      expect(tileset[10, 20]).to be_nil
    end

    it 'removes all placements via #clear' do
      tileset.place('a', [[0, 0], [32, 0]])
      tileset[0, 32] = 'b'
      tileset.clear
      expect(tileset[0, 0]).to be_nil
      expect(tileset[32, 0]).to be_nil
      expect(tileset[0, 32]).to be_nil
    end

    it 'raises a descriptive error when placing an undefined tile name' do
      expect { tileset[0, 0] = 'undefined' }.to raise_error(Ruby2D::Error, /not defined/)
    end
  end

  # The inherited box test covers the source image at the origin, which has
  # nothing to do with where tiles are drawn; a tileset is hit on its tiles.
  describe '#contains?' do
    let(:tileset) do
      ts = Tileset.new(atlas_path, tile_width: 16, tile_height: 8, scale: 2, add: false)
      ts.define(:a, 0, 0)
      ts.define(:turned, 0, 0, rotate: 90)
      ts.define(:tilted, 0, 0, rotate: 45)
      ts
    end

    it 'is false with no placements, even inside the source image' do
      expect(tileset.contains?(8, 8)).to be(false)
    end

    it 'hits a placed tile at its scaled size and misses the source image area' do
      tileset[80, 40] = :a
      expect(tileset.contains?(88, 48)).to be(true)
      expect(tileset.contains?(111, 55)).to be(true)
      expect(tileset.contains?(8, 8)).to be(false)
      expect(tileset.contains?(112, 48)).to be(false)
    end

    it 'is half-open: left and top edges inside, right and bottom outside' do
      tileset[80, 40] = :a
      expect(tileset.contains?(80, 40)).to be(true)
      expect(tileset.contains?(112, 40)).to be(false)
      expect(tileset.contains?(80, 56)).to be(false)
      expect(tileset.contains?(111.9, 55.9)).to be(true)
    end

    it 'follows the rotation of the tile type' do
      # 32×16 placed at (80, 40) turns about (96, 48) into the 16×32 box
      # from (88, 32) to (104, 64)
      tileset[80, 40] = :turned
      expect(tileset.contains?(90, 60)).to be(true)
      expect(tileset.contains?(100, 34)).to be(true)
      expect(tileset.contains?(84, 44)).to be(false)
      expect(tileset.contains?(90, 70)).to be(false)
    end

    it 'keeps the inside edge of a turned tile on the layer edge' do
      # The tile's top-left corner lands at (104, 32) after the turn, on the
      # layer's top and right edges, and is still inside; the other corners
      # are outside as they were.
      tileset[80, 40] = :turned
      expect(tileset.contains?(104, 32)).to be(true)
      expect(tileset.contains?(88, 32)).to be(false)
      expect(tileset.contains?(88, 64)).to be(false)
    end

    # Runs on every mouse move; a per-call allocation would show as 100 here
    # (the counter itself adds one or two).
    it 'allocates nothing per call hitting a rotated tile' do
      tileset[80, 40] = :turned
      tileset.contains?(90, 60)
      before = GC.stat(:total_allocated_objects)
      100.times { tileset.contains?(90, 60) }
      expect(GC.stat(:total_allocated_objects) - before).to be < 10
    end

    it 'excludes the bounding-box corners of a tilted tile' do
      tileset[80, 40] = :tilted
      expect(tileset.contains?(96, 48)).to be(true)
      expect(tileset.contains?(80, 32)).to be(false)
    end

    it 'checks every placement' do
      tileset.place(:a, [[0, 0], [200, 100]])
      expect(tileset.contains?(8, 4)).to be(true)
      expect(tileset.contains?(208, 104)).to be(true)
      expect(tileset.contains?(100, 50)).to be(false)
    end

    it 'tracks deletion and clearing' do
      tileset[80, 40] = :a
      tileset[0, 0] = :a
      tileset.delete(80, 40)
      expect(tileset.contains?(88, 48)).to be(false)
      expect(tileset.contains?(8, 4)).to be(true)
      tileset.clear
      expect(tileset.contains?(8, 4)).to be(false)
    end
  end

  describe 'texture coordinates' do
    it 'pins width/height to the source texture dimensions' do
      ts = Tileset.new(atlas_path, add: false)
      tex = ts.instance_variable_get(:@texture)
      expect(ts.width).to eq(tex.width)
      expect(ts.height).to eq(tex.height)
    end

    it 'normalizes tile UVs against the source texture dimensions' do
      ts = Tileset.new(atlas_path, tile_width: 32, tile_height: 32, add: false)
      ts.define('a', 1, 0)
      ts[0, 0] = 'a'

      tex = ts.instance_variable_get(:@texture)
      placement = ts.instance_variable_get(:@tiles)[[0, 0]]
      uv = placement.fetch(:vertices).texture_coordinates

      # Tile at grid (1, 0), 32px tiles, no padding/spacing: the UV denominator
      # must be the texture's true pixel size, not an overridable width/height.
      expect(uv[0]).to be_within(1e-6).of(32.0 / tex.width)  # left
      expect(uv[1]).to be_within(1e-6).of(0.0)               # top
      expect(uv[2]).to be_within(1e-6).of(64.0 / tex.width)  # right
      expect(uv[5]).to be_within(1e-6).of(32.0 / tex.height) # bottom
    end
  end
end
