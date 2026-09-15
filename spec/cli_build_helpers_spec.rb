require 'ruby2d/cli/build'
require 'tmpdir'
require 'pathname'

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

  # `app_source_name` and the asset helpers resolve against the working
  # directory, so each example runs inside a fresh temporary one, with
  # `outside` a second temporary directory beside it.
  describe '#app_source_name' do
    around do |ex|
      Dir.mktmpdir do |d|
        Dir.mktmpdir do |o|
          Dir.chdir(d) { @dir = File.realpath(d); @outside = File.realpath(o); ex.run }
        end
      end
    end

    it 'names a source inside the working directory by its relative path' do
      FileUtils.mkdir_p('src')
      File.write('main.rb', '')
      File.write('src/main.rb', '')
      expect(app_source_name('main.rb')).to eq('main.rb')
      expect(app_source_name('src/main.rb')).to eq('src/main.rb')
      expect(app_source_name('./src/main.rb')).to eq('src/main.rb')
      expect(app_source_name(File.join(@dir, 'src/main.rb'))).to eq('src/main.rb')
    end

    it 'names a source elsewhere by its basename' do
      File.write(File.join(@outside, 'main.rb'), '')
      expect(app_source_name(File.join(@outside, 'main.rb'))).to eq('main.rb')
    end

    it 'sees through a symlink in the path given, as the working directory has none' do
      # `Dir.pwd` reports the resolved path; the path given may not be. On
      # macOS `/tmp` is such a link, so an absolute path typed through it
      # looked outside the working directory and lost its `src/` prefix.
      FileUtils.mkdir_p('src')
      File.write('src/main.rb', '')
      File.symlink(@dir, File.join(@outside, 'link'))
      expect(app_source_name(File.join(@outside, 'link/src/main.rb'))).to eq('src/main.rb')
    end

    it 'keeps the name of a project-local path that is itself a symlink elsewhere' do
      FileUtils.mkdir_p('src')
      File.write(File.join(@outside, 'main.rb'), '')
      File.symlink(File.join(@outside, 'main.rb'), 'src/main.rb')
      expect(app_source_name('src/main.rb')).to eq('src/main.rb')
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

    it 'ignores the directive text inside a string or heredoc' do
      # A printed help text, or a code sample the app shows, is the app's data,
      # not a declaration — a build used to fail on the directory it named.
      src = "puts <<~'HELP'\n  # ruby2d:assets media\nHELP\nmsg = \"# ruby2d:assets audio\"\n"
      expect(asset_directives(write_app(src))).to eq([])
    end

    it 'ignores the directive text inside an =begin/=end block' do
      src = "=begin\n# ruby2d:assets media\n=end\n"
      expect(asset_directives(write_app(src))).to eq([])
    end

    it 'reads a directive that trails code on its line' do
      src = "require 'ruby2d' # ruby2d:assets media\n"
      expect(asset_directives(write_app(src))).to eq(['media'])
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

    it 'accepts an explicit path containing spaces' do
      Dir.mktmpdir do |dir|
        tool_dir = File.join(dir, 'tool chain')
        Dir.mkdir(tool_dir)
        cc = File.join(tool_dir, 'cc')
        File.symlink(find_executable('sh'), cc)
        expect(find_executable(cc)).to eq(cc)
      end
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
