require 'ruby2d/cli/examples'
require 'ruby2d/cli/usage'

# `ruby2d examples <n>` / `ruby2d usage <n>` select by 1-based number. Guards
# against the off-by-one where "0" wrapped to `list[-1]` (the last item).
RSpec.describe 'CLI numeric selection' do
  shared_examples 'numeric find' do |mod|
    let(:list) { mod.all }

    it 'selects by 1-based number' do
      expect(mod.find('1')).to eq(list.first)
      expect(mod.find(list.length.to_s)).to eq(list.last)
    end

    it 'returns nil for 0 (no wrap to the last item)' do
      expect(mod.find('0')).to be_nil
    end

    it 'returns nil for an out-of-range number' do
      expect(mod.find((list.length + 1).to_s)).to be_nil
    end

    it 'returns nil for an empty query (no match to the first item)' do
      expect(mod.find('')).to be_nil
      expect(mod.find('   ')).to be_nil
    end
  end

  describe Ruby2D::CLI::Examples do
    include_examples 'numeric find', Ruby2D::CLI::Examples
  end

  describe Ruby2D::CLI::Usage do
    include_examples 'numeric find', Ruby2D::CLI::Usage
  end
end
