require 'ruby2d/cli/static_server'
require 'socket'
require 'timeout'
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

    it 'copes with a name holding bytes that are not valid in its encoding' do
      bad_ext = ('app.w' + 255.chr + 'sm').force_encoding(Encoding::UTF_8)
      expect(described_class.content_type(bad_ext)).to eq('application/octet-stream')
      bad_stem = ('caf' + 233.chr + '.wasm').force_encoding(Encoding::UTF_8)
      expect(described_class.content_type(bad_stem)).to eq('application/wasm')
    end
  end

  # Fixtures live in a temp directory, whose path on macOS goes through a
  # symlink (`/var` -> `/private/var`), so served paths are compared canonical.
  around do |example|
    Dir.mktmpdir do |base|
      @base = base
      @root = File.join(base, 'web')
      Dir.mkdir(@root)
      File.binwrite(File.join(@root, 'app.wasm'), 'x')
      # A sibling file outside the served root, reachable only by escaping it.
      File.write(File.join(base, 'secret.txt'), 'secret')
      example.run
    end
  end

  def real(*parts) = File.realpath(File.join(@root, *parts))

  describe '.resolve' do
    it 'resolves a file under the root, stripping any query string' do
      expect(described_class.resolve(@root, '/app.wasm')).to eq(real('app.wasm'))
      expect(described_class.resolve(@root, '/app.wasm?v=1')).to eq(real('app.wasm'))
    end

    it 'returns nil for a missing file' do
      expect(described_class.resolve(@root, '/nope.wasm')).to be_nil
    end

    it 'serves index.html for a directory request' do
      File.write(File.join(@root, 'index.html'), '<h1>hi</h1>')
      expect(described_class.resolve(@root, '/')).to eq(real('index.html'))
      Dir.mkdir(File.join(@root, 'sub'))
      File.write(File.join(@root, 'sub', 'index.html'), '<h1>sub</h1>')
      expect(described_class.resolve(@root, '/sub')).to eq(real('sub', 'index.html'))
    end

    it 'returns nil for a directory request with no index.html' do
      expect(described_class.resolve(@root, '/')).to be_nil
    end

    it 'blocks directory traversal (plain and percent-encoded)' do
      expect(described_class.resolve(@root, '/../secret.txt')).to be_nil
      expect(described_class.resolve(@root, '/%2e%2e/secret.txt')).to be_nil
      expect(described_class.resolve(@root, '/sub/../../secret.txt')).to be_nil
    end

    it 'returns nil for a path with a NUL byte instead of raising' do
      expect(described_class.resolve(@root, '/app%00.wasm')).to be_nil
    end

    it 'returns nil for a name that is not UTF-8 under a non-ASCII root' do
      root = File.join(@base, 'café')
      Dir.mkdir(root)
      expect(described_class.resolve(root, '/app%ff.txt')).to be_nil
    end

    it 'refuses a symlinked file that points outside the root' do
      File.symlink(File.join(@base, 'secret.txt'), File.join(@root, 'linked.txt'))
      expect(described_class.resolve(@root, '/linked.txt')).to be_nil
    end

    it 'refuses files reached through a symlinked directory outside the root' do
      File.symlink(@base, File.join(@root, 'up'))
      expect(described_class.resolve(@root, '/up/secret.txt')).to be_nil
      expect(described_class.resolve(@root, '/up/')).to be_nil
    end

    it 'refuses a directory index that is a symlink outside the root' do
      Dir.mkdir(File.join(@root, 'sub'))
      File.symlink(File.join(@base, 'secret.txt'), File.join(@root, 'sub', 'index.html'))
      expect(described_class.resolve(@root, '/sub/')).to be_nil
    end

    it 'follows a symlink that stays inside the root' do
      File.symlink(File.join(@root, 'app.wasm'), File.join(@root, 'latest.wasm'))
      expect(described_class.resolve(@root, '/latest.wasm')).to eq(real('app.wasm'))
    end

    it 'returns nil for a dangling symlink' do
      File.symlink(File.join(@root, 'gone.wasm'), File.join(@root, 'link.wasm'))
      expect(described_class.resolve(@root, '/link.wasm')).to be_nil
    end

    it 'serves through a root that is itself a symlink' do
      link = File.join(@base, 'www')
      File.symlink(@root, link)
      expect(described_class.resolve(link, '/app.wasm')).to eq(real('app.wasm'))
      expect(described_class.resolve(link, '/../secret.txt')).to be_nil
    end

    it 'returns nil for a missing root' do
      expect(described_class.resolve(File.join(@base, 'nope'), '/app.wasm')).to be_nil
    end

    it 'decodes a non-ASCII file name under a non-ASCII root' do
      root = File.join(@base, 'café')
      Dir.mkdir(root)
      File.write(File.join(root, 'naïve.txt'), 'hello')
      expect(described_class.resolve(root, '/na%C3%AFve.txt')).to eq(File.realpath(File.join(root, 'naïve.txt')))
    end
  end

  describe '.handle' do
    # Send one request through a loopback socket to the connection handler and
    # return [status line, headers hash, body].
    def request(root, line)
      server = TCPServer.new('127.0.0.1', 0)
      worker = Thread.new { described_class.handle(server.accept, root) }
      client = TCPSocket.new('127.0.0.1', server.addr[1])
      client.write("#{line}\r\nHost: localhost\r\n\r\n")
      response = Timeout.timeout(5) { client.read }
      worker.join
      head, body = response.split("\r\n\r\n", 2)
      status, *header_lines = head.lines.map(&:chomp)
      headers = header_lines.to_h { |l| l.split(': ', 2) }
      [status, headers, body]
    ensure
      client&.close
      server&.close
    end

    it 'serves a GET with the file body and its type' do
      status, headers, body = request(@root, 'GET /app.wasm HTTP/1.1')
      expect(status).to eq('HTTP/1.1 200 OK')
      expect(headers['Content-Type']).to eq('application/wasm')
      expect(headers['Content-Length']).to eq('1')
      expect(body).to eq('x')
    end

    it 'returns 404 with a text body for a missing file' do
      status, headers, body = request(@root, 'GET /nope.wasm HTTP/1.1')
      expect(status).to eq('HTTP/1.1 404 Not Found')
      expect(headers['Content-Type']).to start_with('text/plain')
      expect(body).to eq("404 Not Found\n")
    end

    it 'serves a non-ASCII file name under a non-ASCII root' do
      root = File.join(@base, 'café')
      Dir.mkdir(root)
      File.write(File.join(root, 'naïve.txt'), 'hello')
      status, _, body = request(root, 'GET /na%C3%AFve.txt HTTP/1.1')
      expect(status).to eq('HTTP/1.1 200 OK')
      expect(body).to eq('hello')
    end

    it 'does not serve a symlink pointing outside the root' do
      File.symlink(File.join(@base, 'secret.txt'), File.join(@root, 'linked.txt'))
      status, _, body = request(@root, 'GET /linked.txt HTTP/1.1')
      expect(status).to eq('HTTP/1.1 404 Not Found')
      expect(body).not_to include('secret')
    end
  end
end
