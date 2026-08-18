module Ruby2D
  module CLI
    # The Ruby 2D library files, in load order, that get concatenated and
    # compiled to mruby bytecode. Single source of truth shared by the native/web
    # app build (`cli/build.rb`) and the "Try Ruby 2D" WASM build (`try/build.rb`)
    # so the two lists can't drift. Includes files from subdirectories like
    # `cli/` and `window/`, so it is not a plain `lib/ruby2d/*.rb` glob.
    LIB_FILES = %w[
      mruby_compat
      cli/colorize
      exceptions
      warnings
      window/class_methods
      window/key_events
      window/mouse_events
      window/gamepad_events
      window/object_events
      vocabulary
      keyboard
      mouse
      gamepad
      window
      interactive
      renderable
      color
      audio
      canvas
      circle
      ellipse
      font
      image
      json_parser
      atlas_parser
      sprite_sheet
      line
      polygon
      polyline
      quad
      rectangle
      sprite
      square
      text
      bitmap_text
      tileset
      triangle
      button
      vertices
      dsl
    ].freeze
  end
end
