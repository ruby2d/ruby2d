require 'ruby2d'

RSpec.describe Ruby2D::Sound do

  describe "#new" do
    it "raises exception if audio file doesn't exist" do
      expect { Sound.new('no_sound_here.wav') }.to raise_error(Ruby2D::Error)
    end

    unless ENV['CI']  # audio cannot be opened on CI; see `music_spec.rb`
      it "creates sound in various formats" do
        Sound.new("#{Ruby2D.test_media}/music.wav")
        Sound.new("#{Ruby2D.test_media}/music.mp3")
        Sound.new("#{Ruby2D.test_media}/music.ogg")
        Sound.new("#{Ruby2D.test_media}/music.flac")
      end

      it "creates sound and sets the media path" do
        snd = Sound.new("#{Ruby2D.test_media}/sound.wav")
        expect(snd.path).to eq("#{Ruby2D.test_media}/sound.wav")
      end
    end
  end
  describe "#volume" do
    unless ENV['CI']
      it "sets the volume on sound instances" do
        snd = Sound.new("#{Ruby2D.test_media}/music.wav")
        expect(snd.volume).to eq(100)
        snd.volume = 68
        expect(snd.volume).to eq(68)
      end

      it "sets volume to 0 or 100 if outside of range" do
        snd = Sound.new("#{Ruby2D.test_media}/music.wav")
        snd.volume = 234
        expect(snd.volume).to eq(100)
        snd.volume = -312
        expect(snd.volume).to eq(0)
        snd.volume = -1
        expect(snd.volume).to eq(0)
      end

      it "sets the mix volume using class methods" do
        Sound.mix_volume = 27
        expect(Sound.mix_volume).to eq(27)
      end

      it "sets mix volume to 0 or 100 if outside of range" do
        Sound.mix_volume = 234
        expect(Sound.mix_volume).to eq(100)
        Sound.mix_volume = -312
        expect(Sound.mix_volume).to eq(0)
        Sound.mix_volume = -1
        expect(Sound.mix_volume).to eq(0)
      end
    end
  end

  describe "#length" do
    unless ENV['CI']
      it "returns the length of the sound clip in seconds" do
        expect(Sound.new("#{Ruby2D.test_media}/sound.wav").length).to eq(1)
        expect(Sound.new("#{Ruby2D.test_media}/sound.mp3").length).to eq(1)
        expect(Sound.new("#{Ruby2D.test_media}/sound.ogg").length).to eq(1)
        expect(Sound.new("#{Ruby2D.test_media}/sound.flac").length).to eq(1)
      end
    end
  end

end
