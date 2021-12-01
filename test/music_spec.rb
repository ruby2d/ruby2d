require 'ruby2d'

RSpec.describe Ruby2D::Music do

  # Audio cannot be opened on CI
  # On macOS:
  #   Mix_GetError: CoreAudio error (AudioDeviceGetProperty (kAudioDevicePropertyDeviceIsAlive)): 560947818
  # On Windows:
  #   Mix_GetError: WASAPI can't find requested audio endpoint: Element not found.

  describe "#new" do
    it "raises exception if audio file doesn't exist" do
      expect { Music.new('no_music_here.mp3') }.to raise_error(Ruby2D::Error)
    end

    unless ENV['CI']
      it "creates music in various formats" do
        Music.new("#{Ruby2D.test_media}/music.wav")
        Music.new("#{Ruby2D.test_media}/music.mp3")
        Music.new("#{Ruby2D.test_media}/music.ogg")
        Music.new("#{Ruby2D.test_media}/music.flac")
      end

      it "creates music with options" do
        mus = Music.new("#{Ruby2D.test_media}/music.mp3", loop: true)
        expect(mus.path).to eq("#{Ruby2D.test_media}/music.mp3")
        expect(mus.loop).to be true
      end
    end
  end

  describe "attributes" do
    unless ENV['CI']
      it "can be set and read" do
        mus = Music.new("#{Ruby2D.test_media}/music.mp3")
        expect(mus.loop).to be false
        mus.loop = true
        expect(mus.loop).to be true
      end
    end
  end

  describe "#volume" do
    unless ENV['CI']
      it "sets the volume on music instances" do
        mus = Music.new("#{Ruby2D.test_media}/music.mp3")
        expect(mus.volume).to eq(100)
        mus.volume = 68
        expect(mus.volume).to eq(68)
      end
    end

    it "sets the volume using class methods" do
      Music.volume = 27
      expect(Music.volume).to eq(27)
    end

    it "sets volume to 0 or 100 if outside of range" do
      Music.volume = 234
      expect(Music.volume).to eq(100)
      Music.volume = -312
      expect(Music.volume).to eq(0)
      Music.volume = -1
      expect(Music.volume).to eq(0)
    end
  end

  describe '#length' do
    unless ENV['CI']
      it "returns the length of the music track in seconds" do
        expect(Music.new("#{Ruby2D.test_media}/music.wav").length).to eq(8)
        expect(Music.new("#{Ruby2D.test_media}/music.mp3").length).to eq(8)
        expect(Music.new("#{Ruby2D.test_media}/music.ogg").length).to eq(8)
        expect(Music.new("#{Ruby2D.test_media}/music.flac").length).to eq(8)
      end
    end
  end

end
