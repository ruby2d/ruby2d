# frozen_string_literal: true

#
# Requiring just the core avoids the auto-mixin of DSL into
# global namespace
require 'ruby2d/core'

#
# Test Ruby2D without global mixin
# Run this test as follows:
# ```sh
# DISABLE_RUBY2D_AUTO_MIXIN=true rake test without_auto_mixin
# ```
module MyRuby2D
  include Ruby2D

  Window.set title: 'Hello Triangle'

  Triangle.new(
    x1: 320, y1:  50,
    x2: 540, y2: 430,
    x3: 100, y3: 430,
    color: %w[red green blue]
  )

  Window.show
end
