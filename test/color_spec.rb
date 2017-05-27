require 'ruby2d'

RSpec.describe Ruby2D::Color do

  describe '#is_valid?' do
    it 'determines if a color string is valid' do
      expect(Ruby2D::Color.is_valid? 'red').to eq true
      expect(Ruby2D::Color.is_valid? 'balloons').to eq false
    end

    it 'determines if a color string is a valid hex value' do
      expect(Ruby2D::Color.is_valid? '#c0c0c0').to eq true
      expect(Ruby2D::Color.is_valid? '#00000').to eq false
      expect(Ruby2D::Color.is_valid? '123456').to eq false
    end

    it 'determines if an array is a valid color' do
      expect(Ruby2D::Color.is_valid? [1, 0, 0.0, 1.0]).to eq true
      expect(Ruby2D::Color.is_valid? [1.0, 0, 0]).to eq false
    end

    it 'prevents color values that are out of range' do
      expect(Ruby2D::Color.is_valid? [1.2, 0, 0, 0]).to eq false
      expect(Ruby2D::Color.is_valid? [0, 0, -0.1, 0]).to eq false
      expect(Ruby2D::Color.is_valid? [0, 0, 0, 2]).to eq false
    end
  end

  describe '#new' do
    it 'raises error on bad color' do
      expect { Ruby2D::Color.new 42 }.to raise_error Ruby2D::Error
    end
  end

  describe '#opacity' do
    it 'sets and returns the opacity' do
      s1 = Square.new
      s1.opacity = 0.5
      s2 = Square.new(color: ['red', 'green', 'blue', 'yellow'])
      s2.opacity = 0.7
      expect(s1.opacity).to eq 0.5
      expect(s2.opacity).to eq 0.7
    end
  end

end
