require 'ruby2d'

RSpec.describe Ruby2D::Music do

  describe "#new" do
    it "raises exception if audio file doesn't exist" do
      expect { Music.new('bad_music.mp3') }.to raise_error(Ruby2D::Error)
    end

    it "creates music with options" do
      mus = Music.new('test/media/music.mp3', loop: true)
      expect(mus.path).to eq('test/media/music.mp3')
      expect(mus.loop).to be true
    end
  end

  describe "attributes" do
    it "can be set and read" do
      mus = Music.new('test/media/music.mp3')
      expect(mus.loop).to be false
      mus.loop = true
      expect(mus.loop).to be true
    end
  end

  describe "#volume" do
    it "sets the volume on music instances" do
      mus = Music.new('test/media/music.mp3')
      expect(mus.volume).to eq(100)
      mus.volume = 68
      expect(mus.volume).to eq(68)
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

end
