require 'ruby2d/cli/examples'
require 'ruby2d/cli/usage'

# The CLI's help texts each name an example argument; it must be one the
# command actually finds. Usage sections come from the headings in `USAGE.md`
# and examples from `examples/`, so a rename would silently break the hint.
RSpec.describe 'CLI help examples' do
  let(:cli) { File.read(File.expand_path('../bin/ruby2d', __dir__)) }

  def hint(text, label)
    text.to_s[/#{label} \(e\.g\. ([^)]+)\)/, 1]
  end

  describe '`ruby2d usage --help`' do
    let(:example) { hint(cli[/^usage_usage = "(.*?)"\n/m, 1], 'View a section by name') }

    it 'names an example section' do
      expect(example).not_to be_nil
    end

    it 'names a section that resolves' do
      expect(Ruby2D::CLI::Usage.find(example.to_s)).not_to be_nil
    end
  end

  describe '`ruby2d examples --help`' do
    let(:example) { hint(cli[/^usage_examples = "(.*?)"\n/m, 1], 'Run an example by file name') }

    it 'names an example' do
      expect(example).not_to be_nil
    end

    it 'names an example that resolves' do
      expect(Ruby2D::CLI::Examples.find(example.to_s)).not_to be_nil
    end
  end
end
