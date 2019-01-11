require 'ruby2d'

RSpec.describe Ruby2D::Sound do

  describe "#new" do
    it "raises exception if audio file doesn't exist" do
      expect { Sound.new("no_sound_here.wav") }.to raise_error(Ruby2D::Error)
    end

    unless ENV['CI']  # audio cannot be opened on CI; see `music_spec.rb`
      it "creates sound" do
        snd = Sound.new('test/media/sound.wav')
        expect(snd.path).to eq('test/media/sound.wav')
      end
    end
  end

end
