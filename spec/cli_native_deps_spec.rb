require 'ruby2d/cli/build'
require 'fileutils'
require 'tmpdir'

# `ruby2d setup` builds SDL3 + mruby into a per-user cache; `ruby2d build`
# resolves them there. These specs lock the resolution contract — especially the
# version stamp, which stops a stale cache from being linked against the headers
# of a newer gem.
RSpec.describe 'ruby2d/cli/build native-deps resolution' do
  # The target id of the host running the suite (e.g. "macos-arm64").
  let(:target) { AssetsTarget.target_id }

  # Build a `<root>/platform/<target>` tree with the given lib/bin files and an
  # optional version stamp, plus the shared `platform/include` dir.
  def make_platform(root, libs: [], bins: [], stamp: nil)
    pdir = File.join(root, 'platform', target)
    FileUtils.mkdir_p File.join(pdir, 'lib')
    FileUtils.mkdir_p File.join(pdir, 'bin')
    FileUtils.mkdir_p File.join(root, 'platform', 'include')
    libs.each { |f| FileUtils.touch File.join(pdir, 'lib', f) }
    bins.each { |f| FileUtils.touch File.join(pdir, 'bin', f) }
    File.write(File.join(pdir, '.ruby2d-version'), stamp) if stamp
    root
  end

  around do |ex|
    Dir.mktmpdir do |bundled|
      Dir.mktmpdir do |cache|
        @bundled = bundled
        @cache = cache
        ex.run
      end
    end
  end

  before do
    # Point the two resolution roots at throwaway trees.
    allow(Ruby2D).to receive(:assets).and_return(@bundled)
    allow(AssetsTarget).to receive(:cache_root).and_return(@cache)
  end

  describe '#deps_platform_dir' do
    it 'prefers the bundled libraries when present' do
      make_platform(@bundled, libs: ['libSDL3.a'])
      make_platform(@cache, libs: ['libSDL3.a'], stamp: Ruby2D::VERSION)
      expect(deps_platform_dir).to eq(File.join(@bundled, 'platform', target))
    end

    it 'uses a stamped cache build when nothing is bundled' do
      make_platform(@cache, libs: ['libSDL3.a'], stamp: Ruby2D::VERSION)
      expect(deps_platform_dir).to eq(File.join(@cache, 'platform', target))
    end

    it 'ignores a cache build stamped for a different version' do
      make_platform(@cache, libs: ['libSDL3.a'], stamp: 'some-old-version')
      expect(deps_platform_dir).to be_nil
    end

    it 'ignores a cache build with no stamp' do
      make_platform(@cache, libs: ['libSDL3.a'])
      expect(deps_platform_dir).to be_nil
    end

    it 'is nil when neither has the libs (system-lib fallback)' do
      expect(deps_platform_dir).to be_nil
    end
  end

  describe '#deps_include_dir' do
    it 'is the include sibling of the resolved platform dir' do
      make_platform(@cache, libs: ['libSDL3.a'], stamp: Ruby2D::VERSION)
      expect(deps_include_dir).to eq(File.join(@cache, 'platform', 'include'))
    end

    it 'falls back to the bundled headers when no static libs resolve' do
      expect(deps_include_dir).to eq("#{@bundled}/platform/include")
    end
  end

  describe '#find_mrbc' do
    let(:mrbc) { AssetsTarget.host_os == 'windows' ? 'mrbc.exe' : 'mrbc' }

    it 'prefers bundled mrbc' do
      make_platform(@bundled, bins: [mrbc])
      make_platform(@cache, bins: [mrbc], stamp: Ruby2D::VERSION)
      expect(find_mrbc).to eq(File.join(@bundled, 'platform', target, 'bin', mrbc))
    end

    it 'uses a stamped cache mrbc when not bundled' do
      make_platform(@cache, bins: [mrbc], stamp: Ruby2D::VERSION)
      expect(find_mrbc).to eq(File.join(@cache, 'platform', target, 'bin', mrbc))
    end

    it 'ignores an unstamped cache mrbc and falls back to PATH' do
      make_platform(@cache, bins: [mrbc]) # no stamp
      allow_any_instance_of(Object).to receive(:find_executable).with('mrbc').and_return('/usr/bin/mrbc')
      expect(find_mrbc).to eq('/usr/bin/mrbc')
    end
  end

  describe '#cache_stamp_ok?' do
    it 'is true only when the stamp matches this ruby2d version' do
      make_platform(@cache, stamp: Ruby2D::VERSION)
      expect(cache_stamp_ok?(File.join(@cache, 'platform', target))).to be true
    end

    it 'is false for a missing stamp' do
      make_platform(@cache)
      expect(cache_stamp_ok?(File.join(@cache, 'platform', target))).to be false
    end
  end
end

# The cache location and build-root redirection that `ruby2d setup` relies on.
RSpec.describe AssetsTarget do
  around do |ex|
    saved = ENV['RUBY2D_ASSETS_ROOT']
    ex.run
  ensure
    saved.nil? ? ENV.delete('RUBY2D_ASSETS_ROOT') : (ENV['RUBY2D_ASSETS_ROOT'] = saved)
  end

  describe '.default_root' do
    it 'is the gem assets dir without an override' do
      ENV.delete('RUBY2D_ASSETS_ROOT')
      expect(File.basename(AssetsTarget.default_root)).to eq('assets')
    end

    it 'honors RUBY2D_ASSETS_ROOT' do
      ENV['RUBY2D_ASSETS_ROOT'] = '/tmp/ruby2d-elsewhere'
      expect(AssetsTarget.default_root).to eq('/tmp/ruby2d-elsewhere')
    end
  end

  describe '.cache_root' do
    it 'honors RUBY2D_ASSETS_ROOT' do
      ENV['RUBY2D_ASSETS_ROOT'] = '/tmp/ruby2d-elsewhere'
      expect(AssetsTarget.cache_root).to eq('/tmp/ruby2d-elsewhere')
    end

    it 'is a ruby2d-named cache dir otherwise' do
      ENV.delete('RUBY2D_ASSETS_ROOT')
      expect(File.basename(AssetsTarget.cache_root)).to eq('ruby2d')
    end
  end
end
