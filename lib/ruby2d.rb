# Ruby2D module and native extension loader, adds DSL

unless RUBY_ENGINE == 'mruby'
  require 'ruby2d/cli/colorize'
  require 'ruby2d/exceptions'
  require 'ruby2d/renderable'
  require 'ruby2d/color'
  require 'ruby2d/window'
  require 'ruby2d/dsl'
  require 'ruby2d/quad'
  require 'ruby2d/line'
  require 'ruby2d/circle'
  require 'ruby2d/rectangle'
  require 'ruby2d/square'
  require 'ruby2d/triangle'
  require 'ruby2d/image'
  require 'ruby2d/sprite'
  require 'ruby2d/font'
  require 'ruby2d/text'
  require 'ruby2d/sound'
  require 'ruby2d/music'

  if RUBY_PLATFORM =~ /mingw/
    s2d_dll_path = Gem::Specification.find_by_name('ruby2d').gem_dir + '/assets/mingw/bin'
    RubyInstaller::Runtime.add_dll_directory(File.expand_path(s2d_dll_path))
  end

  require 'ruby2d/ruby2d'  # load native extension
end


module Ruby2D

  @assets = nil

  class << self
    def assets
      unless @assets
        if RUBY_ENGINE == 'mruby'
          @assets = Ruby2D.ext_base_path + 'assets'
        else
          @assets = './assets'
        end
      end
      @assets
    end

    def assets=(path); @assets = path end
  end
end

include Ruby2D
extend  Ruby2D::DSL
