# Ruby2D module and native extension loader

unless RUBY_ENGINE == 'mruby'
  require 'ruby2d/cli/colorize'
  require 'ruby2d/exceptions'
  require 'ruby2d/warnings'
  require 'ruby2d/window/class_methods'
  require 'ruby2d/window/key_events'
  require 'ruby2d/window/mouse_events'
  require 'ruby2d/window/gamepad_events'
  require 'ruby2d/window/object_events'
  require 'ruby2d/gamepad'
  require 'ruby2d/window'
  require 'ruby2d/interactive'
  require 'ruby2d/renderable'
  require 'ruby2d/color'
  require 'ruby2d/audio'
  require 'ruby2d/canvas'
  require 'ruby2d/circle'
  require 'ruby2d/ellipse'
  require 'ruby2d/font'
  require 'ruby2d/image'
  require 'ruby2d/json_parser'
  require 'ruby2d/atlas_parser'
  require 'ruby2d/sprite_sheet'
  require 'ruby2d/line'
  require 'ruby2d/polygon'
  require 'ruby2d/polyline'
  require 'ruby2d/quad'
  require 'ruby2d/rectangle'
  require 'ruby2d/sprite'
  require 'ruby2d/square'
  require 'ruby2d/text'
  require 'ruby2d/bitmap_text'
  require 'ruby2d/tileset'
  require 'ruby2d/triangle'
  require 'ruby2d/button'
  require 'ruby2d/vertices'
  begin
    require 'ruby2d/ruby2d' # load native extension
  rescue LoadError
    # The extension isn't built — most often because SDL3 wasn't available at
    # install time (see ext/ruby2d/extconf.rb, which then installs without it).
    # Print the same recovery guidance the install shows and stop cleanly, so
    # the user gets the notice — not a cryptic "cannot load such file" backtrace.
    require 'ruby2d/deps_help'
    abort Ruby2D::DepsHelp.notice
  end
  require 'ruby2d/dsl' # must loaded last, needs native extension
end
