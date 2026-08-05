require 'ruby2d/benchmark'

RSpec.describe Ruby2D::Benchmark do
  describe '#thousands' do
    # A private formatting helper used by #report; exercise it directly.
    subject(:bench) { described_class.new('test') }

    def thousands(n) = bench.send(:thousands, n)

    it 'inserts comma separators into large numbers' do
      expect(thousands(1234567)).to eq('1,234,567')
      expect(thousands(1000)).to eq('1,000')
    end

    it 'leaves short numbers unchanged' do
      expect(thousands(0)).to eq('0')
      expect(thousands(42)).to eq('42')
    end

    it 'preserves the sign of negative numbers' do
      # Regression: the sign used to be dropped (-1234567 -> "1,234,567").
      expect(thousands(-1234567)).to eq('-1,234,567')
      expect(thousands(-42)).to eq('-42')
    end
  end
end
