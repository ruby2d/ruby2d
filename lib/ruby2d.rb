# frozen_string_literal: true

require 'ruby2d/core' unless RUBY_ENGINE == 'mruby'

# Create 2D applications, games, and visualizations with ease. Just a few lines of code is enough to get started.
# Visit https://www.ruby2d.com for more information.
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

  def self.test_media
    "#{gem_dir}/assets/test_media"
  end
end

# Ruby2D adds DSL
# Apps can avoid the mixins by using: require "ruby2d/core"

# --- start lint exception
# rubocop:disable Style/MixinUsage
include Ruby2D
extend Ruby2D::DSL
# rubocop:enable Style/MixinUsage
# --- end lint exception
