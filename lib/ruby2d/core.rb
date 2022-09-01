# frozen_string_literal: true

# Ruby2D module and native extension loader

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
  require 'ruby2d/pixel'
  require 'ruby2d/pixmap'
  require 'ruby2d/pixmap_atlas'
  require 'ruby2d/image'
  require 'ruby2d/sprite'
  require 'ruby2d/tileset'
  require 'ruby2d/font'
  require 'ruby2d/text'
  require 'ruby2d/canvas'
  require 'ruby2d/sound'
  require 'ruby2d/music'
  require 'ruby2d/texture'
  require 'ruby2d/vertices'
  require 'ruby2d/ruby2d' # load native extension
end
