module Ruby2D
  # The Ruby 2D library files, in load order. Single source of truth for every
  # Ruby: `core.rb` requires them under CRuby (skipping `mruby_compat`, and
  # loading `dsl` after the native extension), and the native/web app build
  # (`cli/build.rb`) and the "Try Ruby 2D" WASM build (`try/build.rb`)
  # concatenate them for mruby — so the lists can't drift. Order matters, and
  # it includes `window/`, so it is not a plain `lib/ruby2d/*.rb` glob.
  LIB_FILES = %w[
    mruby_compat
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
