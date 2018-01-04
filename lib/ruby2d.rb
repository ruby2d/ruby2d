# ruby2d.rb

require 'ruby2d/renderable'
require 'ruby2d/exceptions'
require 'ruby2d/color'
require 'ruby2d/window'
require 'ruby2d/application'
require 'ruby2d/dsl'
require 'ruby2d/quad'
require 'ruby2d/line'
require 'ruby2d/rectangle'
require 'ruby2d/square'
require 'ruby2d/triangle'
require 'ruby2d/image'
require 'ruby2d/sprite'
require 'ruby2d/text'
require 'ruby2d/sound'
require 'ruby2d/music'

if RUBY_PLATFORM =~ /mingw/
  RubyInstaller::Runtime.add_dll_directory(File.expand_path('~/../../usr/local/bin'))
end

require 'ruby2d/ruby2d'  # load native extension

include Ruby2D
extend  Ruby2D::DSL
