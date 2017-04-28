require 'ruby2d'

RSpec.describe Ruby2D::Text do
  
  describe '#text=' do
    it 'maps Time to string' do
      t = Text.new(0, 0, Time.now, 40, "test/media/bitstream_vera/vera.ttf")
      t.text = Time.new(1, 1, 1, 1, 1, 1, 1)
      expect(t.text).to eq "0001-01-01 01:01:01 +0000"
    end
    
    it 'maps Number to string' do
      t = Text.new(0, 0, 0, 40, "test/media/bitstream_vera/vera.ttf")
      t.text = 0
      expect(t.text).to eq "0"
    end

    it "works nicely without explicitly passed font file" do
      Text.new(0, 0, 0, 40)
    end
  end

  describe "#width" do
    it "is known after creation" do
      t = Text.new(0, 0, "Hello world!", 40, "test/media/bitstream_vera/vera.ttf")
      expect(t.width).to eq(239)
    end

    it "is known after updating" do
      t = Text.new(0, 0, "Good morning world!", 40, "test/media/bitstream_vera/vera.ttf")
      t.text = "Hello world!"
      expect(t.width).to eq(239)
    end
  end

  describe "#height" do
    it "is known after creation" do
      t = Text.new(0, 0, "Hello world!", 40, "test/media/bitstream_vera/vera.ttf")
      expect(t.height).to eq(48)
    end

    it "is known after updating" do
      t = Text.new(0, 0, "Good morning world!", 40, "test/media/bitstream_vera/vera.ttf")
      t.text = "Hello world!"
      expect(t.height).to eq(48)
    end
  end
end
