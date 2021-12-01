# Ruby2D module and native extension loader, adds DSL

unless RUBY_ENGINE == 'mruby'
  require 'ruby2d/cli/colorize'
  require 'ruby2d/exceptions'
  require 'ruby2d/renderable'
  require 'ruby2d/color'
  require 'ruby2d/window'
  require 'ruby2d/dsl'
  require 'ruby2d/entity'
  require 'ruby2d/quad'
  require 'ruby2d/line'
  require 'ruby2d/circle'
  require 'ruby2d/rectangle'
  require 'ruby2d/square'
  require 'ruby2d/triangle'
  require 'ruby2d/pixel'
  require 'ruby2d/image'
  require 'ruby2d/sprite'
  require 'ruby2d/tileset'
  require 'ruby2d/font'
  require 'ruby2d/text'
  require 'ruby2d/sound'
  require 'ruby2d/music'
  require 'ruby2d/texture'
  require 'ruby2d/vertices'

  if defined?(RubyInstaller)
    RubyInstaller::Runtime.add_dll_directory(File.expand_path(
      Gem::Specification.find_by_name('ruby2d').gem_dir + '/assets/mingw/bin'
    ))
  end

  require 'ruby2d/ruby2d'  # load native extension
end


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


include Ruby2D
extend  Ruby2D::DSL
