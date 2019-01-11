require 'ruby2d'

RSpec.describe Ruby2D::Color do

  describe "#is_valid?" do
    it "determines if a color string is valid" do
      expect(Ruby2D::Color.is_valid? 'red').to eq true
      expect(Ruby2D::Color.is_valid? 'balloons').to eq false
    end

    it "determines if a color string is a valid hex value" do
      expect(Ruby2D::Color.is_valid? '#c0c0c0').to eq true
      expect(Ruby2D::Color.is_valid? '#00000').to eq false
      expect(Ruby2D::Color.is_valid? '123456').to eq false
    end

    it "determines if an array is a valid color" do
      expect(Ruby2D::Color.is_valid? [1, 0, 0.0, 1.0]).to eq true
      expect(Ruby2D::Color.is_valid? [1.0, 0, 0]).to eq false
    end
  end

  describe "#new" do
    it "raises error on bad color" do
      expect { Ruby2D::Color.new 42 }.to raise_error Ruby2D::Error
    end

    it "accepts an existing color object" do
      expect { Ruby2D::Color.new(Ruby2D::Color.new('red')) }.to_not raise_error
    end

    it "assigns rgba from an existing color" do
      c1 = Ruby2D::Color.new([20, 60, 80, 100])
      c2 = Ruby2D::Color.new(c1)

      expect([c2.r, c2.g, c2.b, c2.a]).to eq([20, 60, 80, 100])
    end
  end

  describe "#opacity" do
    it "sets and returns the opacity" do
      s1 = Square.new
      s1.opacity = 0.5
      s2 = Square.new(color: ['red', 'green', 'blue', 'yellow'])
      s2.opacity = 0.7
      expect(s1.opacity).to eq(0.5)
      expect(s2.opacity).to eq(0.7)
    end
  end

  it "allows British English spelling of color" do
    expect(Ruby2D::Colour).to eq(Ruby2D::Color)
  end

end
