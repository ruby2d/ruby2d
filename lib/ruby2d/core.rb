# Ruby2D module and native extension loader

unless RUBY_ENGINE == 'mruby'
  # One load order for every Ruby: CRuby requires these files; the native/web
  # and Try builds concatenate the same list for mruby (`lib_files.rb`).
  require 'ruby2d/lib_files'
  Ruby2D::LIB_FILES.each do |f|
    next if f == 'mruby_compat' || f == 'dsl'
    require "ruby2d/#{f}"
  end
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
