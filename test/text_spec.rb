require 'ruby2d'

RSpec.describe Ruby2D::Text do

  describe "#new" do
    it "raises exception if font file doesn't exist" do
      expect { Text.new('hello', font: 'bad_font.ttf') }.to raise_error(Ruby2D::Error)
    end

    it "uses the system default font if one is not provided" do
      txt = Text.new('hello')
      expect(txt.font).to eq(Font.default)
    end

    it "creates text with a white filter by default" do
      txt = Text.new('hello')
      expect(txt.color).to be_a(Ruby2D::Color)
      expect(txt.color.r).to eq(1)
      expect(txt.color.g).to eq(1)
      expect(txt.color.b).to eq(1)
      expect(txt.color.a).to eq(1)
    end

    it "creates an image with options" do
      txt = Text.new(
        'hello', font: "#{Ruby2D.test_media}/bitstream_vera/vera.ttf",
        x: 10, y: 20, z: 30,
        size: 40, rotate: 50,
        color: 'gray', opacity: 0.5
      )

      expect(txt.text).to eq('hello')
      expect(txt.x).to eq(10)
      expect(txt.y).to eq(20)
      expect(txt.z).to eq(30)
      expect(txt.size).to eq(40)
      expect(txt.rotate).to eq(50)
      expect(txt.color.r).to eq(2/3.0)
      expect(txt.color.opacity).to eq(0.5)
    end
  end

  describe "attributes" do
    it "can be set and read" do
      txt = Text.new('hello')
      txt.x = 10
      txt.y = 20
      txt.z = 30
      txt.size = 40
      txt.rotate = 50
      txt.color = 'gray'
      txt.color.opacity = 0.5

      expect(txt.x).to eq(10)
      expect(txt.y).to eq(20)
      expect(txt.z).to eq(30)
      expect(txt.size).to eq(40)
      expect(txt.rotate).to eq(50)
      expect(txt.color.r).to eq(2/3.0)
      expect(txt.color.opacity).to eq(0.5)
    end
  end

  describe '#size=' do
    it "re-renders the text with new dimensions" do
      txt = Text.new('hello', size: 10)
      original_width = txt.width
      original_height = txt.height

      txt.size = 20
      expect(txt.width).to be > original_width
      expect(txt.height).to be > original_width
    end
  end

  describe "#text=" do
    it "maps Time to string" do
      txt = Text.new('hello', font: "#{Ruby2D.test_media}/bitstream_vera/vera.ttf")
      txt.text = Time.new(1, 1, 1, 1, 1, 1, 1)
      expect(txt.text).to eq('0001-01-01 01:01:01 +0000')
    end

    it "maps Number to string" do
      txt = Text.new('hello', font: "#{Ruby2D.test_media}/bitstream_vera/vera.ttf")
      txt.text = 0
      expect(txt.text).to eq('0')
    end
  end

  describe "#width" do
    it "is known after creation" do
      txt = Text.new('Hello Ruby!', font: "#{Ruby2D.test_media}/bitstream_vera/vera.ttf")
      expect(txt.width).to be_between(110, 120)
    end

    it "is known after updating" do
      txt = Text.new('hello', font: "#{Ruby2D.test_media}/bitstream_vera/vera.ttf")
      txt.text = 'Hello!'
      expect(txt.width).to eq(59)
    end
  end

  describe "#height" do
    it "is known after creation" do
      txt = Text.new('hello', font: "#{Ruby2D.test_media}/bitstream_vera/vera.ttf")
      expect(txt.height).to eq(24)
    end

    it "is known after updating" do
      txt = Text.new('hello', font: "#{Ruby2D.test_media}/bitstream_vera/vera.ttf")
      txt.text = 'Good morning world!'
      expect(txt.height).to eq(24)
    end
  end

  describe "#contains?" do
    it "returns true if point is inside the text" do
      txt = Text.new('hello', font: "#{Ruby2D.test_media}/bitstream_vera/vera.ttf")
      txt.text = 'Hello world!'
      expect(txt.contains?(txt.width / 2, txt.height / 2)).to be true
    end

    it "returns false if point is outside the text" do
      txt = Text.new('hello', font: "#{Ruby2D.test_media}/bitstream_vera/vera.ttf")
      txt.text = 'Hello world!'
      expect(txt.contains?(  - txt.width / 2,     txt.height / 2)).to be false
      expect(txt.contains?(    txt.width / 2,   - txt.height / 2)).to be false
      expect(txt.contains?(3 * txt.width / 2,     txt.height / 2)).to be false
      expect(txt.contains?(    txt.width / 2, 3 * txt.height / 2)).to be false
    end
  end

end
