RSpec.describe Ruby2D::Vertices do
  let(:crop) { { x: 16, y: 0, width: 16, height: 16, image_width: 64, image_height: 32 } }
  let(:plain) { Ruby2D::Vertices.new(10, 20, 16, 16, 0, crop: crop) }

  # A flip must not mirror the quad itself: negating an extent reverses the
  # vertex winding, which SDL's software renderer mishandles for quarter-turn
  # quads. The corners stay put and the texture coordinates carry the flip.
  describe 'flip' do
    it 'keeps the quad corners and winding for every flip' do
      [:horizontal, :vertical, :both].each do |flip|
        flipped = Ruby2D::Vertices.new(10, 20, 16, 16, 0, crop: crop, flip: flip)
        expect(flipped.coordinates).to eq(plain.coordinates)
      end
    end

    it 'keeps rotated corners for a flipped quarter turn' do
      rotated = Ruby2D::Vertices.new(10, 20, 16, 12, 90, crop: crop)
      flipped = Ruby2D::Vertices.new(10, 20, 16, 12, 90, crop: crop, flip: :horizontal)
      expect(flipped.coordinates).to eq(rotated.coordinates)
    end

    it 'mirrors the texture coordinates horizontally' do
      uv = Ruby2D::Vertices.new(10, 20, 16, 16, 0, crop: crop, flip: :horizontal).texture_coordinates
      expect(uv).to eq([0.5, 0.0, 0.25, 0.0, 0.25, 0.5, 0.5, 0.5])
    end

    it 'mirrors the texture coordinates vertically' do
      uv = Ruby2D::Vertices.new(10, 20, 16, 16, 0, crop: crop, flip: :vertical).texture_coordinates
      expect(uv).to eq([0.25, 0.5, 0.5, 0.5, 0.5, 0.0, 0.25, 0.0])
    end

    it 'mirrors both axes for :both' do
      uv = Ruby2D::Vertices.new(10, 20, 16, 16, 0, crop: crop, flip: :both).texture_coordinates
      expect(uv).to eq([0.5, 0.5, 0.25, 0.5, 0.25, 0.0, 0.5, 0.0])
    end

    it 'mirrors the whole texture when there is no crop' do
      uv = Ruby2D::Vertices.new(0, 0, 16, 16, 0, flip: :horizontal).texture_coordinates
      expect(uv).to eq([1.0, 0.0, 0.0, 0.0, 0.0, 1.0, 1.0, 1.0])
    end

    it 'leaves the texture coordinates alone without a flip' do
      expect(plain.texture_coordinates).to eq([0.25, 0.0, 0.5, 0.0, 0.5, 0.5, 0.25, 0.5])
      expect(Ruby2D::Vertices.new(0, 0, 8, 8, 0).texture_coordinates).to eq([0.0, 0.0, 1.0, 0.0, 1.0, 1.0, 0.0, 1.0])
    end
  end
end
