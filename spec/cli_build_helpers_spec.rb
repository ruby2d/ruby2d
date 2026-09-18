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

  describe 'asset bundling' do
    around do |ex|
      Dir.mktmpdir do |d|
        Dir.mktmpdir do |o|
          Dir.chdir(d) { @dir = File.realpath(d); @outside = File.realpath(o); ex.run }
        end
      end
    end

    # Windows makes a symlink a directory link only when Ruby can see that the
    # target is a directory at creation, and it looks relative to the working
    # directory, not the link. A relative target that only resolves from the
    # link's directory comes out as a file link that nothing can traverse, so
    # links to directories are created with the target resolved.
    def link_dir(target, link)
      File.symlink(File.expand_path(target, File.dirname(link)), link)
    end

    describe '#asset_bundle_path' do
      it 'keeps the relative path of a directory inside the working directory' do
        FileUtils.mkdir_p('assets/media')
        expect(asset_bundle_path('assets/media')).to eq('assets/media')
        expect(asset_bundle_path('./assets/media/')).to eq('assets/media')
        expect(asset_bundle_path(File.join(@dir, 'assets/media'))).to eq('assets/media')
      end

      it 'keeps the relative path when the path given goes through a symlink' do
        FileUtils.mkdir_p('assets/media')
        File.symlink(@dir, File.join(@outside, 'link'))
        expect(asset_bundle_path(File.join(@outside, 'link/assets/media'))).to eq('assets/media')
      end

      it 'keeps the name of a project-local directory that is itself a symlink elsewhere' do
        # `media -> /shared/game-media` is how the app references it, and how
        # CRuby finds it; the link target's name is nobody's reference.
        FileUtils.mkdir_p(File.join(@outside, 'game-media'))
        FileUtils.mkdir_p('assets')
        File.symlink(File.join(@outside, 'game-media'), 'assets/media')
        expect { @bundle = asset_bundle_path('assets/media') }.not_to output.to_stdout
        expect(@bundle).to eq('assets/media')
      end

      it 'bundles a directory elsewhere under its basename, and says so' do
        outside = File.join(@outside, 'shared-media')
        FileUtils.mkdir_p(outside)
        expect { @bundle = asset_bundle_path(outside) }
          .to output(/outside this directory, so it's bundled as `shared-media`/).to_stdout
        expect(@bundle).to eq('shared-media')
        relative = Pathname.new(outside).relative_path_from(Pathname.new(@dir)).to_s
        expect { @bundle = asset_bundle_path(relative) }.to output(/`shared-media`/).to_stdout
        expect(@bundle).to eq('shared-media')
      end
    end

    describe '#check_asset_dir' do
      it 'aborts on a directory that does not exist' do
        expect { check_asset_dir('media') }
          .to raise_error(SystemExit).and output(/asset directory not found: media/).to_stdout
      end

      it 'aborts on a directory that overlaps the build output' do
        # `.` and `..` contain the output, `build` is it, and `build/native` is
        # inside it: copying any of them would nest the build inside itself.
        FileUtils.mkdir_p('build/native')
        ['.', '..', 'build', 'build/native', @dir].each do |dir|
          expect { check_asset_dir(dir) }
            .to raise_error(SystemExit).and output(/overlaps the build output `build\/`/).to_stdout
        end
      end

      it 'aborts on a symlink to a directory that contains the build output' do
        File.symlink('.', 'everything')
        expect { check_asset_dir('everything') }
          .to raise_error(SystemExit).and output(/overlaps the build output/).to_stdout
      end

      it 'aborts on the filesystem root, which contains everything' do
        expect { check_asset_dir('/') }
          .to raise_error(SystemExit).and output(/overlaps the build output/).to_stdout
      end

      it 'accepts an ordinary directory, with or without a build present' do
        FileUtils.mkdir_p('media')
        expect { check_asset_dir('media') }.not_to output.to_stdout
        FileUtils.mkdir_p('build/native')
        expect { check_asset_dir('media') }.not_to output.to_stdout
      end
    end

    describe '#resolve_asset_dirs' do
      before { FileUtils.mkdir_p(%w[media media/images audio app App.app]) }

      it 'pairs each directory with its bundle path, in declaration order' do
        expect(resolve_asset_dirs(%w[media audio], native: true))
          .to eq([%w[media media], %w[audio audio]])
      end

      it 'bundles a directory declared twice once' do
        expect(resolve_asset_dirs(%w[media ./media], native: true)).to eq([%w[media media]])
      end

      it 'drops a directory inside another declared one, whichever comes first' do
        expect(resolve_asset_dirs(%w[media/images media], native: true)).to eq([%w[media media]])
        expect(resolve_asset_dirs(%w[media media/images], native: true)).to eq([%w[media media]])
      end

      it 'keeps a nested directory whose bundle path is not inside the other one' do
        # An outside parent lands under its basename, so its child's own bundle
        # path (`sprites`) would otherwise exist nowhere in the build.
        shared = File.join(@outside, 'shared')
        FileUtils.mkdir_p(File.join(shared, 'sprites'))
        expect { @pairs = resolve_asset_dirs([shared, File.join(shared, 'sprites')], native: true) }
          .to output(/bundled as `shared`.*bundled as `sprites`/m).to_stdout
        expect(@pairs).to eq([[shared, 'shared'], [File.join(shared, 'sprites'), 'sprites']])
      end

      it 'refuses a native bundle path that would collide with the executable or bundle' do
        %w[app App.app app/media].each do |dir|
          FileUtils.mkdir_p(dir)
          expect { resolve_asset_dirs([dir], native: true) }
            .to raise_error(SystemExit).and output(/reserved for the native executable/).to_stdout
        end
      end

      it 'refuses the reserved names in any letter case' do
        FileUtils.mkdir_p('APP')
        expect { resolve_asset_dirs(['APP'], native: true) }
          .to raise_error(SystemExit).and output(/reserved/).to_stdout
      end

      it 'allows those names for a web-only build, which has no executable beside them' do
        expect(resolve_asset_dirs(['app'], native: false)).to eq([%w[app app]])
      end

      it 'validates every directory before resolving any' do
        expect { resolve_asset_dirs(%w[media missing], native: true) }
          .to raise_error(SystemExit).and output(/not found: missing/).to_stdout
      end

      it 'refuses two directories that would land at one bundle path' do
        # A `media` elsewhere is bundled under its basename, where `media`
        # already is; merging them would ship different files to the two targets.
        other = File.join(@outside, 'media')
        FileUtils.mkdir_p(other)
        expect { resolve_asset_dirs(['media', other], native: true) }
          .to raise_error(SystemExit)
          .and output(/`#{Regexp.escape(other)}` would be bundled as `media`, which `media` already is/).to_stdout
      end
    end

    describe '#emcc_file_map' do
      it 'joins source and destination with @, escaping a literal @ as @@' do
        expect(emcc_file_map('media', 'media')).to eq('media@media')
        expect(emcc_file_map('sprites@2x', 'sprites@2x')).to eq('sprites@@2x@sprites@@2x')
      end
    end

    describe '#copy_tree' do
      it 'copies the contents into a new destination' do
        FileUtils.mkdir_p('media/images')
        File.write('media/images/a.png', 'a')
        copy_tree('media', 'out/media')
        expect(File.read('out/media/images/a.png')).to eq('a')
      end

      it 'merges into an existing destination instead of nesting inside it' do
        # The case a child declared before its parent hits (`media/images`
        # copied first creates `out/media`), and an asset directory named
        # `ruby2d` beside the bundled `ruby2d/fonts`.
        FileUtils.mkdir_p('media/images')
        File.write('media/marker.txt', 'm')
        File.write('media/images/a.png', 'a')
        FileUtils.mkdir_p('out/media/images')
        File.write('out/media/images/existing.png', 'e')
        copy_tree('media', 'out/media')
        expect(File.read('out/media/marker.txt')).to eq('m')
        expect(File.read('out/media/images/a.png')).to eq('a')
        expect(File.read('out/media/images/existing.png')).to eq('e')
        expect(Dir.exist?('out/media/media')).to be false
      end

      it 'follows symlinks, so the copy holds the files rather than links to them' do
        FileUtils.mkdir_p(%w[media outside/deep])
        File.write('outside/big.txt', 'b')
        File.write('outside/deep/d.txt', 'd')
        File.symlink('../outside/big.txt', 'media/big.txt')
        link_dir('../outside/deep', 'media/deep')
        copy_tree('media', 'out/media')
        expect(File.symlink?('out/media/big.txt')).to be false
        expect(File.read('out/media/big.txt')).to eq('b')
        expect(File.symlink?('out/media/deep')).to be false
        expect(File.read('out/media/deep/d.txt')).to eq('d')
      end

      it 'copies a second link to a directory, skips a link loop, and warns on a dangling one' do
        FileUtils.mkdir_p('media/real/deep')
        File.write('media/real/r.txt', 'r')
        link_dir('real', 'media/again')
        link_dir('.', 'media/loop')
        link_dir('../..', 'media/real/deep/up')
        File.symlink('gone.txt', 'media/dangling.txt')
        expect { copy_tree('media', 'out/media') }
          .to output(/skipping `media\/dangling.txt`, a link to nothing.*skipping `media\/loop`, a link back into `media`.*skipping `media\/real\/deep\/up`, a link back into `media`/m).to_stdout
        expect(File.read('out/media/real/r.txt')).to eq('r')
        expect(File.read('out/media/again/r.txt')).to eq('r')
        expect(Dir.exist?('out/media/loop')).to be false
        expect(File.exist?('out/media/dangling.txt')).to be false
      end

      it 'skips a link to a directory the build writes into, once however many copies pass it' do
        # `all` reaches the project root, which holds the destination; `out`
        # and `web` reach the build output, which the tree being copied is not
        # part of, so the second target's copy would package the first's output.
        FileUtils.mkdir_p(%w[media build/native build/web])
        File.write('media/x.txt', 'x')
        link_dir('..', 'media/all')
        link_dir('../build', 'media/out')
        link_dir('../build/web', 'media/web')
        expect { copy_tree('media', 'build/native/media') }
          .to output(/skipping `media\/all`, a link to a directory the build writes into.*`media\/out`.*`media\/web`/m).to_stdout
        expect(File.read('build/native/media/x.txt')).to eq('x')
        expect(Dir.exist?('build/native/media/all')).to be false
        expect(Dir.exist?('build/native/media/out')).to be false
        expect(Dir.exist?('build/native/media/web')).to be false
        expect { copy_tree('media', 'build/stage/assets/media') }.not_to output.to_stdout
        expect(Dir.exist?('build/stage/assets/media/web')).to be false
      end

      it 'copies a tree that lives inside the build output, as the macOS bundle does' do
        FileUtils.mkdir_p('build/native/ruby2d/fonts/mono')
        File.write('build/native/ruby2d/fonts/mono/a.ttf', 'f')
        expect { copy_tree('build/native/ruby2d', 'build/native/App.app/Contents/MacOS/ruby2d') }
          .not_to output.to_stdout
        expect(File.read('build/native/App.app/Contents/MacOS/ruby2d/fonts/mono/a.ttf')).to eq('f')
      end
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
        cc = write_executable(tool_dir, 'cc')
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
