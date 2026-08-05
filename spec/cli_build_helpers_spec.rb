require 'ruby2d/cli/build'
require 'tmpdir'

# The build CLI defines its string-munging helpers as top-level methods. They
# were previously untested and have had real bugs (see find_executable below),
# so these specs lock their contracts.
RSpec.describe 'ruby2d/cli/build helpers' do
  describe '#shell_escape' do
    it 'leaves an ordinary path untouched' do
      expect(shell_escape('build/app.c')).to eq('build/app.c')
    end

    it 'escapes spaces and shell metacharacters' do
      expect(shell_escape('my app.rb')).to eq('my\ app.rb')
      expect(shell_escape('a;b')).to eq('a\;b')
    end

    it 'coerces non-strings via to_s' do
      expect(shell_escape(42)).to eq('42')
    end
  end

  describe '#strip_require' do
    around { |ex| Dir.mktmpdir { |d| @dir = d; ex.run } }

    def write_app(contents)
      path = File.join(@dir, 'app.rb')
      File.write(path, contents)
      path
    end

    it "blanks out `require 'ruby2d'` and `require 'ruby2d/core'` lines" do
      src = "require 'ruby2d'\nrequire 'ruby2d/core'\nputs :hi\n"
      expect(strip_require(write_app(src))).to eq("\n\nputs :hi\n")
    end

    it 'accepts double-quoted requires' do
      src = %(require "ruby2d"\nx = 1\n)
      expect(strip_require(write_app(src))).to eq("\nx = 1\n")
    end

    it 'keeps unrelated requires and code' do
      src = "require 'json'\nrequire 'ruby2d'\ny = 2\n"
      expect(strip_require(write_app(src))).to eq("require 'json'\n\ny = 2\n")
    end

    it 'blanks rather than deletes, so line numbers (and mrbc error lines) survive' do
      src = "require 'ruby2d'\nx = 1\nbad syntax(\n"
      expect(strip_require(write_app(src)).lines.size).to eq(src.lines.size)
    end
  end

  describe '#asset_directives' do
    around { |ex| Dir.mktmpdir { |d| @dir = d; ex.run } }

    def write_app(contents)
      path = File.join(@dir, 'app.rb')
      File.write(path, contents)
      path
    end

    it 'returns an empty list when there are no directives' do
      expect(asset_directives(write_app("require 'ruby2d'\nputs :hi\n"))).to eq([])
    end

    it 'extracts the directory from a directive' do
      src = "require 'ruby2d'\n# ruby2d:assets media\n"
      expect(asset_directives(write_app(src))).to eq(['media'])
    end

    it 'collects several directives in source order' do
      src = "# ruby2d:assets media\ncode\n# ruby2d:assets audio\n"
      expect(asset_directives(write_app(src))).to eq(%w[media audio])
    end

    it 'tolerates leading indentation and extra spacing' do
      src = "   #   ruby2d:assets   assets/resources/spritesheets  \n"
      expect(asset_directives(write_app(src))).to eq(['assets/resources/spritesheets'])
    end

    it 'ignores comments that merely mention the directive word' do
      src = "# see the ruby2d:assets directive for bundling\n"
      expect(asset_directives(write_app(src))).to eq([])
    end
  end

  describe '#find_executable' do
    it 'finds a bare name on PATH' do
      # `sh` exists and is executable on every POSIX system the suite runs on.
      result = find_executable('sh')
      expect(result).to be_a(String)
      expect(File.executable?(result)).to be true
    end

    it 'returns nil for a name not on PATH' do
      expect(find_executable('definitely-not-a-real-binary-xyz')).to be_nil
    end

    it 'uses an explicit path as-is instead of searching PATH' do
      # Regression: `File.join(dir, '/abs/clang')` used to collapse to a bogus
      # path, so `CC=/abs/clang ruby2d build` aborted a valid build.
      sh = find_executable('sh') # an absolute path to a real executable
      expect(find_executable(sh)).to eq(sh)
    end

    it 'returns nil for an explicit path that does not exist' do
      expect(find_executable('/nonexistent/path/to/xyz')).to be_nil
    end
  end

  describe '#add_ld_flags' do
    it 'appends an escaped archive path for :archive' do
      flags = String.new
      add_ld_flags(flags, 'SDL3', :archive, '/libs')
      expect(flags).to eq('/libs/libSDL3.a ')
    end

    it 'appends a -framework flag for :framework' do
      flags = String.new
      add_ld_flags(flags, 'Cocoa', :framework)
      expect(flags).to eq('-Wl,-framework,Cocoa ')
    end

    it 'is a no-op for an unknown type' do
      flags = String.new('existing ')
      add_ld_flags(flags, 'X', :unknown)
      expect(flags).to eq('existing ')
    end
  end
end
