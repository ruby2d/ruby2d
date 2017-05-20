require 'ruby2d'

RSpec.describe Ruby2D::Music do

  describe '#new' do
    it "raises exception if audio file doesn't exist" do
      expect { Music.new('bad_music.mp3') }.to raise_error(Ruby2D::Error)
    end
  end

end
