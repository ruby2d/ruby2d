# `Font.path` resolves a font name to a file path. Both the candidate paths and
# (now) the query are downcased, so lookup is case-insensitive — matching the
# already-downcased names returned by `Font.all`. Stub the platform font scan so
# these run the same everywhere.
RSpec.describe Ruby2D::Font do
  describe '.path' do
    before do
      allow(Ruby2D::Font).to receive(:all_paths)
        .and_return(['/Library/Fonts/Arial.ttf', '/Library/Fonts/Courier New.ttf'])
    end

    it 'matches regardless of the query case' do
      path = '/Library/Fonts/Arial.ttf'
      expect(Ruby2D::Font.path('arial')).to eq(path)
      expect(Ruby2D::Font.path('Arial')).to eq(path)
      expect(Ruby2D::Font.path('ARIAL')).to eq(path)
    end

    it 'matches on a substring' do
      expect(Ruby2D::Font.path('courier')).to eq('/Library/Fonts/Courier New.ttf')
    end

    it 'returns nil when nothing matches' do
      expect(Ruby2D::Font.path('Helvetica')).to be_nil
    end
  end
end
