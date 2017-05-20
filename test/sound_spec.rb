require 'ruby2d'

RSpec.describe Ruby2D::Sound do

  describe '#new' do
    it "raises exception if audio file doesn't exist" do
      expect { Sound.new('bad_sound.wav') }.to raise_error(Ruby2D::Error)
    end
  end

end
