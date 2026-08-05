require 'ruby2d/gem_paths'
require 'ruby2d/core' unless RUBY_ENGINE == 'mruby'

# Create 2D applications, games, and visualizations with ease. Just a few
# lines of code is enough to get started. Visit https://www.ruby2d.com for
# more information.
module Ruby2D
  def self.test_media
    File.expand_path('../assets/test_media', __dir__)
  end

  def self.test_audio
    "#{test_media}/audio"
  end

  def self.test_images
    "#{test_media}/images"
  end

  def self.test_spritesheets
    "#{test_media}/spritesheets"
  end
end

# Ruby2D adds DSL
# Apps can avoid the mixins by using: require "ruby2d/core"

include Ruby2D
extend Ruby2D::DSL
