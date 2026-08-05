RSpec.describe Ruby2D::Audio do

  describe "#new" do
    it "raises exception if audio file doesn't exist" do
      expect { described_class.new('no_audio_here.mp3') }.to raise_error(Ruby2D::Error)
    end

    context 'with bundled fixtures' do
      it "creates audio in various formats" do
        described_class.new("#{Ruby2D.test_audio}/music.wav")
        described_class.new("#{Ruby2D.test_audio}/music.mp3")
        described_class.new("#{Ruby2D.test_audio}/music.ogg")
        described_class.new("#{Ruby2D.test_audio}/music.flac")
      end

      it "creates audio and sets the media path" do
        aud = described_class.new("#{Ruby2D.test_audio}/sound.wav")
        expect(aud.path).to eq("#{Ruby2D.test_audio}/sound.wav")
      end

      it "creates audio with options" do
        aud = described_class.new("#{Ruby2D.test_audio}/music.mp3", loop: true)
        expect(aud.path).to eq("#{Ruby2D.test_audio}/music.mp3")
        expect(aud.looping?).to be true
      end

      it "raises (rather than segfaulting on first play) when the file exists but cannot be decoded" do
        require 'tempfile'
        bad = Tempfile.new(['not_really', '.wav'])
        begin
          bad.write('this is definitely not audio data')
          bad.flush
          expect { described_class.new(bad.path) }.to raise_error(Ruby2D::Error, /Failed to load audio/)
        ensure
          bad.close!
        end
      end
    end
  end

  describe "attributes" do
    it "can be set and read" do
      aud = described_class.new("#{Ruby2D.test_audio}/music.mp3")
      expect(aud.looping?).to be false
      aud.loop = true
      expect(aud.looping?).to be true
    end

    it "coerces loop= to a strict boolean (matching Sprite#loop=)" do
      aud = described_class.new("#{Ruby2D.test_audio}/music.mp3")
      aud.loop = 'yes'
      expect(aud.looping?).to be true
      aud.loop = nil
      expect(aud.looping?).to be false
    end
  end

  describe "#volume" do
    # The mixer volume is process-wide; save and restore it so these tests don't
    # leave it at 0 for later examples (order-dependent failures otherwise).
    around do |example|
      saved = described_class.volume
      example.run
      described_class.volume = saved
    end

    it "sets the volume on audio instances" do
      aud = described_class.new("#{Ruby2D.test_audio}/music.wav")
      expect(aud.volume).to eq(1.0)
      aud.volume = 0.5
      expect(aud.volume).to eq(0.5)
    end

    it "clamps volume to 0.0 or 1.0 if outside of range (instance)" do
      aud = described_class.new("#{Ruby2D.test_audio}/music.wav")
      aud.volume = 2.34
      expect(aud.volume).to eq(1.0)
      aud.volume = -3.12
      expect(aud.volume).to eq(0.0)
      aud.volume = -1
      expect(aud.volume).to eq(0.0)
    end

    it "sets the mixer volume using class methods" do
      described_class.volume = 0.25
      expect(described_class.volume).to eq(0.25)
    end

    it "clamps mixer volume to 0.0 or 1.0 if outside of range" do
      described_class.volume = 2.34
      expect(described_class.volume).to eq(1.0)
      described_class.volume = -3.12
      expect(described_class.volume).to eq(0.0)
      described_class.volume = -1
      expect(described_class.volume).to eq(0.0)
    end
  end

  describe "#length" do
    it "returns the length of short sound clips in seconds" do
      expect(described_class.new("#{Ruby2D.test_audio}/sound.wav").length).to eq(1)
      expect(described_class.new("#{Ruby2D.test_audio}/sound.mp3").length).to eq(1)
      expect(described_class.new("#{Ruby2D.test_audio}/sound.ogg").length).to eq(1)
      # FLAC duration not supported by SDL3_mixer
    end

    it "returns the length of music tracks in seconds" do
      expect(described_class.new("#{Ruby2D.test_audio}/music.wav").length).to eq(8)
      expect(described_class.new("#{Ruby2D.test_audio}/music.mp3").length).to eq(8)
      expect(described_class.new("#{Ruby2D.test_audio}/music.ogg").length).to eq(8)
      # FLAC duration not supported by SDL3_mixer
    end
  end

end
