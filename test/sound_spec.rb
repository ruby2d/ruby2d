require 'ruby2d'

RSpec.describe Ruby2D::Sound do

  describe "#new" do
    it "raises exception if audio file doesn't exist" do
      expect { Sound.new("no_sound_here.wav") }.to raise_error(Ruby2D::Error)
    end

    unless ENV['CI']  # audio cannot be opened on CI; see `music_spec.rb`
      it "creates sound in various formats" do
        Sound.new('test/media/music.wav')
        Sound.new('test/media/music.mp3')
        Sound.new('test/media/music.ogg')
        Sound.new('test/media/music.flac')
      end

      it "creates sound and sets the media path" do
        snd = Sound.new('test/media/sound.wav')
        expect(snd.path).to eq('test/media/sound.wav')
      end
    end
  end

  describe '#length' do
    unless ENV['CI']
      it "returns the length of the sound clip in seconds" do
        expect(Sound.new('test/media/sound.wav').length).to eq(1)
        expect(Sound.new('test/media/sound.mp3').length).to eq(1)
        expect(Sound.new('test/media/sound.ogg').length).to eq(1)
        expect(Sound.new('test/media/sound.flac').length).to eq(1)
      end
    end
  end

end
