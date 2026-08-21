# The load-order manifest (`lib_files.rb`) is what CRuby requires and what
# the mruby builds concatenate, so a stale entry breaks every Ruby at once.

RSpec.describe Ruby2D::LIB_FILES do
  let(:lib_dir) { File.expand_path('../lib/ruby2d', __dir__) }

  it 'names only files that exist' do
    missing = described_class.reject { |f| File.file?(File.join(lib_dir, "#{f}.rb")) }
    expect(missing).to be_empty
  end

  it 'lists every runtime file under lib/ruby2d once' do
    all = Dir[File.join(lib_dir, '**', '*.rb')].map { |p| p.delete_prefix("#{lib_dir}/").delete_suffix('.rb') }
    cli_only = all.grep(%r{\A(cli/|core\z|lib_files\z|deps_help\z|benchmark\z|gem_paths\z|version\z|ruby2d\z)})
    expect(described_class.sort).to eq((all - cli_only).sort)
    expect(described_class.uniq).to eq(described_class)
  end

  it 'has already been loaded in order by core.rb' do
    loaded = $LOADED_FEATURES.map { |p| p[%r{lib/ruby2d/(.+)\.rb\z}, 1] }.compact
    expect(loaded & described_class).to eq(described_class - ['mruby_compat'])
  end
end
