require 'ruby2d'

RSpec.describe Ruby2D::Text do

  describe '#text=' do
    it 'maps Time to string' do
      t = Text.new(font: "test/media/bitstream_vera/vera.ttf")
      t.text = Time.new(1, 1, 1, 1, 1, 1, 1)
      expect(t.text).to eq "0001-01-01 01:01:01 +0000"
    end

    it 'maps Number to string' do
      t = Text.new(font: "test/media/bitstream_vera/vera.ttf")
      t.text = 0
      expect(t.text).to eq "0"
    end
  end

  describe "#width" do
    it "is known after creation" do
      t = Text.new(font: "test/media/bitstream_vera/vera.ttf")
      expect(t.width).to eq(123)
    end

    it "is known after updating" do
      t = Text.new(font: "test/media/bitstream_vera/vera.ttf")
      t.text = "Hello!"
      expect(t.width).to eq(59)
    end
  end

  describe "#height" do
    it "is known after creation" do
      t = Text.new(font: "test/media/bitstream_vera/vera.ttf")
      expect(t.height).to eq(24)
    end

    it "is known after updating" do
      t = Text.new(font: "test/media/bitstream_vera/vera.ttf")
      t.text = "Good morning world!"
      expect(t.height).to eq(24)
    end
  end

  describe '#contains?' do
    it "returns true if point is inside text" do
      t = Text.new(font: "test/media/bitstream_vera/vera.ttf")
      t.text = "Hello world!"
      expect(t.contains?(t.width / 2, t.height / 2)).to be true
    end

    it "returns true if point is not inside text" do
      t = Text.new(font: "test/media/bitstream_vera/vera.ttf")
      t.text = "Hello world!"
      expect(t.contains?(  - t.width / 2,     t.height / 2)).to be false
      expect(t.contains?(    t.width / 2,   - t.height / 2)).to be false
      expect(t.contains?(3 * t.width / 2,     t.height / 2)).to be false
      expect(t.contains?(    t.width / 2, 3 * t.height / 2)).to be false
    end
  end
end
