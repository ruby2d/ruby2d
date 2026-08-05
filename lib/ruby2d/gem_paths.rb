# Extension-free path helpers. These live apart from the rest of `ruby2d` so the
# tooling that must run *before* the native extension exists — the `ruby2d setup`
# command that builds it, and the extconf that links it — can locate the gem's
# files without loading the (possibly not-yet-built) `.so`.

module Ruby2D
  def self.gem_dir
    # mruby doesn't define `Gem`
    if RUBY_ENGINE == 'mruby'
      `ruby -e "print Gem::Specification.find_by_name('ruby2d').gem_dir"`
    else
      Gem::Specification.find_by_name('ruby2d').gem_dir
    end
  end

  def self.assets
    "#{gem_dir}/assets"
  end
end
