require 'ruby2d'


RSpec.describe Ruby2D::Color do
  
  describe '#is_valid?' do
    
    it 'determines if a color string is valid' do
      pending 'need hash of valid strings'
      expect(Ruby2D::Color.is_valid? 'red').to be true
      expect(Ruby2D::Color.is_valid? 'balloons').to be false
    end
    
    it 'determines if an array is a valid color' do
      expect(Ruby2D::Color.is_valid? [1.0, 0, 0, 1.0]).to be true
      expect(Ruby2D::Color.is_valid? [1.0, 0, 0]).to be false
    end
    
    it 'prevents allow color values out of range' do
      expect(Ruby2D::Color.is_valid? [1.0, 0, 0.0, 255]).to be true
      expect(Ruby2D::Color.is_valid? [1.2, 0, 0, 0]).to be false
      expect(Ruby2D::Color.is_valid? [-0.1, 0, 0, 0]).to be false
      expect(Ruby2D::Color.is_valid? [255, 255, 256, 255]).to be false
      expect(Ruby2D::Color.is_valid? [-1, 0, 127, 255]).to be false
    end
    
  end
  
  
  describe '#new' do
    
    it 'raises error on bad color' do
      expect { Ruby2D::Color.new 42 }.to raise_error Ruby2D::Error
    end
    
  end
  
end
