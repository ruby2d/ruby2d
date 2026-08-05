require 'ruby2d/cli/usage'

# `ruby2d agents` is a thin shell over Ruby2D::CLI::Usage: bare `agents` prints
# the section list, `agents all` prints `.content`, and `agents <name>` resolves
# a section via `.find`. The numeric selection path is covered in
# cli_numeric_find_spec; here we cover the section parsing and name matching the
# command relies on. Everything derives from `.all` so the spec tracks USAGE.md.
RSpec.describe Ruby2D::CLI::Usage do
  describe '.all' do
    it 'parses USAGE.md into titled, non-empty sections' do
      sections = described_class.all
      expect(sections).not_to be_empty
      sections.each do |s|
        expect(s[:title]).to be_a(String)
        expect(s[:title]).not_to be_empty
        expect(s[:content]).to start_with('## ')
      end
    end
  end

  describe '.content' do
    it 'returns the guide as markdown with the Table of Contents stripped' do
      content = described_class.content
      expect(content).not_to be_empty
      expect(content).not_to include('## Table of Contents')
    end
  end

  describe '.find by name' do
    let(:first) { described_class.all.first }

    it 'matches a title exactly, regardless of case' do
      expect(described_class.find(first[:title])).to eq(first)
      expect(described_class.find(first[:title].downcase)).to eq(first)
      expect(described_class.find(first[:title].upcase)).to eq(first)
    end

    it 'treats spaces, hyphens, and underscores as interchangeable' do
      spaced = first[:name] # already lowercased and space-normalized
      expect(described_class.find(spaced.tr(' ', '-'))).to eq(first)
      expect(described_class.find(spaced.tr(' ', '_'))).to eq(first)
    end

    it 'matches a partial (substring) name' do
      word = first[:name].split(' ').first
      match = described_class.find(word)
      expect(match).not_to be_nil
      expect(match[:name]).to include(word)
    end

    it 'returns nil when no section matches' do
      expect(described_class.find('definitely-not-a-real-section-xyz')).to be_nil
    end
  end
end
