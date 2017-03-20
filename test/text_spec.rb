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
  end
end
