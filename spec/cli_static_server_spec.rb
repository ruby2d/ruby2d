require 'ruby2d/cli/static_server'
require 'tmpdir'

RSpec.describe Ruby2D::CLI::StaticServer do
  describe '.content_type' do
    it 'maps web-build extensions to the right MIME types' do
      expect(described_class.content_type('app.wasm')).to eq('application/wasm')
      expect(described_class.content_type('app.html')).to start_with('text/html')
      expect(described_class.content_type('app.js')).to start_with('text/javascript')
      expect(described_class.content_type('app.data')).to eq('application/octet-stream')
    end

    it 'is case-insensitive and falls back to octet-stream' do
      expect(described_class.content_type('APP.WASM')).to eq('application/wasm')
      expect(described_class.content_type('mystery.zzz')).to eq('application/octet-stream')
    end
  end

  describe '.resolve' do
    around do |example|
      Dir.mktmpdir do |base|
        @root = File.join(base, 'web')
        Dir.mkdir(@root)
        File.binwrite(File.join(@root, 'app.wasm'), 'x')
        # A sibling file outside the served root, reachable only via traversal.
        File.write(File.join(base, 'secret.txt'), 'secret')
        example.run
      end
    end

    it 'resolves a file under the root, stripping any query string' do
      expect(described_class.resolve(@root, '/app.wasm')).to eq(File.join(@root, 'app.wasm'))
      expect(described_class.resolve(@root, '/app.wasm?v=1')).to eq(File.join(@root, 'app.wasm'))
    end

    it 'returns nil for a missing file' do
      expect(described_class.resolve(@root, '/nope.wasm')).to be_nil
    end

    it 'serves index.html for a directory request' do
      index = File.join(@root, 'index.html')
      File.write(index, '<h1>hi</h1>')
      expect(described_class.resolve(@root, '/')).to eq(index)
      Dir.mkdir(File.join(@root, 'sub'))
      sub_index = File.join(@root, 'sub', 'index.html')
      File.write(sub_index, '<h1>sub</h1>')
      expect(described_class.resolve(@root, '/sub')).to eq(sub_index)
    end

    it 'returns nil for a directory request with no index.html' do
      expect(described_class.resolve(@root, '/')).to be_nil
    end

    it 'blocks directory traversal (plain and percent-encoded)' do
      expect(described_class.resolve(@root, '/../secret.txt')).to be_nil
      expect(described_class.resolve(@root, '/%2e%2e/secret.txt')).to be_nil
    end

    it 'returns nil for a path with a NUL byte instead of raising' do
      expect(described_class.resolve(@root, '/app%00.wasm')).to be_nil
    end
  end
end
